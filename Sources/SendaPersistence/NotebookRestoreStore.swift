import Foundation
import SendaDomain

/// Restores a complete notebook while protecting the journal, profile, and manual measurement files.
@MainActor public protocol NotebookRestoreStore {
    var measurementsRepository: any BodyMeasurementsRepository { get }
    func recoverInterruptedRestore() throws
    func restore(_ archive: NotebookArchive, current: NotebookArchive?) throws
    func previousBackupData() throws -> Data?
    func previousBackupArchive() async throws -> NotebookArchive?
    func previousOriginalFilesData() throws -> Data?
    func originalJournalData() throws -> Data?
}

public extension NotebookRestoreStore {
    func previousOriginalFilesData() throws -> Data? { nil }
    func previousBackupArchive() async throws -> NotebookArchive? {
        guard let data = try previousBackupData() else { return nil }
        return try await Task.detached(priority: .userInitiated) { try NotebookBackupCodec.decode(data) }.value
    }
}

public enum NotebookRestoreError: LocalizedError {
    case recoveryRequired
    public var errorDescription: String? {
        "A previous restore needs recovery before this notebook can be changed. Your files and recovery copy have been kept. Try opening the notebook again."
    }
}

@MainActor public final class FileNotebookRestoreStore: NotebookRestoreStore {
    private let journalURL: URL
    private let profileURL: URL
    let measurementsURL: URL
    public let measurementsRepository: any BodyMeasurementsRepository
    private let writer: (Data, URL) throws -> Void
    private let remover: (URL) throws -> Void
    let pendingURL: URL
    let backupURL: URL
    let originalsURL: URL

    public convenience init(journalURL: URL, profileURL: URL) {
        self.init(journalURL: journalURL, profileURL: profileURL,
            writer: { data, url in
                if url == journalURL || url == profileURL {
                    try data.write(to: url, options: .atomic)
                } else {
                    try FileBodyMeasurementsRepository.protectedWrite(data, url)
                }
            })
    }
    init(journalURL: URL, profileURL: URL, writer: @escaping (Data, URL) throws -> Void,
         remover: @escaping (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.journalURL = journalURL; self.profileURL = profileURL
        measurementsURL = journalURL.deletingLastPathComponent()
            .appendingPathComponent("BodyMeasurements", isDirectory: true)
            .appendingPathComponent("measurements.json")
        measurementsRepository = FileBodyMeasurementsRepository(url: measurementsURL)
        self.writer = writer; self.remover = remover
        pendingURL = journalURL.appendingPathExtension("restore-pending.json")
        backupURL = journalURL.appendingPathExtension("before-restore.senda.json")
        originalsURL = journalURL.appendingPathExtension("before-restore-originals.json")
    }

    public func restore(_ archive: NotebookArchive, current: NotebookArchive?) throws {
        let archive = try archive.validated()
        let previous = try current.map(NotebookBackupCodec.encode)
        // A pending transaction owns the destination files until rollback succeeds.
        try recoverInterruptedRestore()
        if FileManager.default.fileExists(atPath: stagingURL.path) {
            try FileManager.default.removeItem(at: stagingURL)
        }
        try FileBodyMeasurementsRepository.preparePrivateDirectory(stagingURL)
        var present = Set<RestorePart>()
        for part in RestorePart.allCases {
            do {
                try FileManager.default.copyItem(at: liveURL(for: part), to: stagedURL(for: part))
                present.insert(part)
            } catch {
                if !isMissing(error) { throw error }
            }
        }
        var rawRecovery: Data?
        if previous == nil {
            let originals = try OriginalFiles(journal: capture(stagedURL(for: .journal)),
                                              profile: capture(stagedURL(for: .profile)),
                                              measurements: capture(stagedURL(for: .measurements)))
            rawRecovery = try JSONEncoder().encode(originals)
        }
        // Even the first restore keeps the current notebook (including any in-memory draft)
        // available as a protected copy after rollback.
        if !present.contains(.backup), !present.contains(.rawBackup) {
            if let previous {
                try writer(previous, stagedURL(for: .backup))
                present.insert(.backup)
            } else if let rawRecovery {
                try writer(rawRecovery, stagedURL(for: .rawBackup))
                present.insert(.rawBackup)
            }
        }
        // Publish the marker only after every rollback file has been staged.
        try writer(try JSONEncoder().encode(RestoreCheckpoint(present: present)), pendingURL)
        do {
            let repository = FileProfileRepository(url: profileURL, writer: writer)
            var profile = archive.profile
            profile.trainerApplication = (try? repository.load())?.trainerApplication
            try repository.save(profile)
            try FileJournalRepository(url: journalURL, writer: writer).saveSnapshot(archive.snapshot)
            if let readings = archive.manualMeasurements {
                try FileBodyMeasurementsRepository(url: measurementsURL).save(readings, writer: writer)
            }
            if let previous {
                try writeRecoveryCopy(previous, to: backupURL)
                try removeIfPresent(originalsURL)
            } else if let rawRecovery {
                try writeRecoveryCopy(rawRecovery, to: originalsURL)
                try removeIfPresent(backupURL)
            }
            // Until removal succeeds, a relaunch rolls back to the original files.
            try remover(pendingURL)
            discardStaging()
        } catch {
            let originalError = error
            do { try recoverInterruptedRestore() }
            catch { throw NotebookRestoreError.recoveryRequired }
            throw originalError
        }
    }

    public func recoverInterruptedRestore() throws {
        guard let data = try readIfPresent(pendingURL) else {
            // A quit before the marker was published, or after commit, can leave staging files.
            discardStaging()
            return
        }
        do {
            let decoder = JSONDecoder()
            if try decoder.decode(RestoreHeader.self, from: data).format == "senda-restore-checkpoint" {
                let checkpoint = try decoder.decode(RestoreCheckpoint.self, from: data)
                let stagedNames = try FileManager.default.contentsOfDirectory(atPath: stagingURL.path)
                guard (1...2).contains(checkpoint.version),
                      checkpoint.version == 2 || !checkpoint.present.contains(.measurements),
                      !checkpoint.present.isDisjoint(with: [.backup, .rawBackup]),
                      Set(stagedNames) == Set(checkpoint.present.map(\.rawValue)) else {
                    throw NotebookRestoreError.recoveryRequired
                }
                // Verify every rollback source before replacing or removing any live file.
                var originals: [RestorePart: Data] = [:]
                for part in checkpoint.present {
                    originals[part] = try Data(contentsOf: stagedURL(for: part), options: .mappedIfSafe)
                }
                var failed = false
                for part in RestorePart.allCases where checkpoint.version == 2 || part != .measurements {
                    do { try restoreFile(at: liveURL(for: part), contents: originals[part]) }
                    catch { failed = true }
                }
                guard !failed else { throw NotebookRestoreError.recoveryRequired }
            } else {
                // Markers from older builds stored only the original live files inline.
                let live = try decoder.decode(OriginalFiles.self, from: data).validated()
                var failed = false
                var files = [(journalURL, live.journal), (profileURL, live.profile)]
                if let measurements = live.measurements { files.append((measurementsURL, measurements)) }
                for (url, file) in files {
                    do { try restoreFile(at: url, contents: file.contents) }
                    catch { failed = true }
                }
                guard !failed else { throw NotebookRestoreError.recoveryRequired }
            }
            try remover(pendingURL)
            discardStaging()
        } catch { throw NotebookRestoreError.recoveryRequired }
    }

    private var stagingURL: URL { journalURL.appendingPathExtension("restore-staging") }

    private func stagedURL(for part: RestorePart) -> URL {
        stagingURL.appendingPathComponent(part.rawValue)
    }

    private func liveURL(for part: RestorePart) -> URL {
        switch part {
        case .journal: journalURL
        case .profile: profileURL
        case .measurements: measurementsURL
        case .backup: backupURL
        case .rawBackup: originalsURL
        }
    }

    private func discardStaging() {
        try? FileManager.default.removeItem(at: stagingURL)
    }

    private func writeRecoveryCopy(_ data: Data, to url: URL) throws {
        try writer(data, url)
        #if os(iOS)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        var localCopy = url
        try localCopy.setResourceValues(resources)
        #endif
    }

    private func restoreFile(at url: URL, contents: Data?) throws {
        if try readIfPresent(url) == contents { return }
        if let contents {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if url == measurementsURL {
                try FileBodyMeasurementsRepository.preparePrivateDirectory(url.deletingLastPathComponent())
            }
            if url == backupURL || url == originalsURL {
                try writeRecoveryCopy(contents, to: url)
            } else {
                try writer(contents, url)
            }
        } else {
            try removeIfPresent(url)
        }
    }

    public func previousBackupData() throws -> Data? {
        guard let data = try readIfPresent(backupURL) else { return nil }
        return try NotebookBackupCodec.encode(NotebookBackupCodec.decode(data))
    }
    public func previousBackupArchive() async throws -> NotebookArchive? {
        try await Task.detached(priority: .userInitiated) { [backupURL] in
            guard let data = try self.readIfPresent(backupURL) else { return nil }
            return try NotebookBackupCodec.decode(data)
        }.value
    }
    public func previousOriginalFilesData() throws -> Data? {
        guard let data = try readIfPresent(originalsURL) else { return nil }
        var export = try JSONDecoder().decode(OriginalFiles.self, from: data).validated()
        // The private rollback file stays intact, including an unreadable device profile.
        // Only recognized notebook profile fields may leave the device.
        let portable = export.profile.contents.flatMap(FileProfileRepository.portableRecoveryData)
        export.profile = OriginalFile(existed: portable != nil, contents: portable)
        return try JSONEncoder().encode(export)
    }
    public func originalJournalData() throws -> Data? { try readIfPresent(journalURL) }

    private func capture(_ url: URL) throws -> OriginalFile {
        let data = try readIfPresent(url)
        return OriginalFile(existed: data != nil, contents: data)
    }
    private nonisolated func readIfPresent(_ url: URL) throws -> Data? {
        do { return try Data(contentsOf: url, options: .mappedIfSafe) }
        catch { if isMissing(error) { return nil }; throw error }
    }
    private func removeIfPresent(_ url: URL) throws {
        do { try remover(url) }
        catch { if !isMissing(error) { throw error } }
    }
    private nonisolated func isMissing(_ error: any Error) -> Bool {
        guard let error = error as? CocoaError else { return false }
        return error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile
    }
}

private struct RestoreHeader: Decodable {
    let format: String
}

private enum RestorePart: String, Codable, CaseIterable {
    case journal, profile, measurements, backup, rawBackup
}

private struct RestoreCheckpoint: Codable {
    let format: String
    let version: Int
    let present: Set<RestorePart>

    init(present: Set<RestorePart>) {
        format = "senda-restore-checkpoint"
        version = 2
        self.present = present
    }
}

private struct OriginalFile: Codable {
    let existed: Bool
    let contents: Data?
    func validated() throws {
        guard existed == (contents != nil) else { throw NotebookRestoreError.recoveryRequired }
    }
}
private struct OriginalFiles: Codable {
    let format: String
    let version: Int
    let journal: OriginalFile
    var profile: OriginalFile
    let measurements: OriginalFile?
    init(journal: OriginalFile, profile: OriginalFile, measurements: OriginalFile) {
        format = "senda-restore-recovery"; version = 2
        self.measurements = measurements
        self.journal = journal; self.profile = profile
    }
    func validated() throws -> Self {
        guard format == "senda-restore-recovery",
              (version == 1 && measurements == nil) || (version == 2 && measurements != nil) else {
            throw NotebookRestoreError.recoveryRequired
        }
        try measurements?.validated()
        try journal.validated(); try profile.validated()
        return self
    }
}

@MainActor public final class MemoryNotebookRestoreStore: NotebookRestoreStore {
    private let repository: any JournalRepository
    private let profileRepository: any ProfileRepository
    public let measurementsRepository: any BodyMeasurementsRepository
    private var previous: Data?
    private var pending: (JournalSnapshot, ProfileDetails, [BodyMeasurement]?)?
    public init(repository: any JournalRepository, profileRepository: any ProfileRepository,
                measurementsRepository: any BodyMeasurementsRepository = MemoryBodyMeasurementsRepository()) {
        self.measurementsRepository = measurementsRepository
        self.repository = repository; self.profileRepository = profileRepository
    }
    public func restore(_ archive: NotebookArchive, current: NotebookArchive?) throws {
        let archive = try archive.validated()
        let previousData = try current.map(NotebookBackupCodec.encode)
        try recoverInterruptedRestore()
        let measurements = try archive.manualMeasurements.map { _ in try measurementsRepository.load() }
        let original = try (repository.loadSnapshot(), profileRepository.load(), measurements)
        pending = original
        do {
            var profile = archive.profile
            profile.trainerApplication = original.1.trainerApplication
            try profileRepository.save(profile)
            try repository.saveSnapshot(archive.snapshot)
            if let readings = archive.manualMeasurements { try measurementsRepository.save(readings) }
            previous = previousData
            pending = nil
        } catch {
            let originalError = error
            do { try recoverInterruptedRestore() }
            catch { throw NotebookRestoreError.recoveryRequired }
            throw originalError
        }
    }
    public func recoverInterruptedRestore() throws {
        guard let original = pending else { return }
        var failed = false
        do { try repository.saveSnapshot(original.0) } catch { failed = true }
        do { try profileRepository.save(original.1) } catch { failed = true }
        if let readings = original.2 {
            do { try measurementsRepository.save(readings) } catch { failed = true }
        }
        guard !failed else { throw NotebookRestoreError.recoveryRequired }
        pending = nil
    }
    public func previousBackupData() throws -> Data? { previous }
    public func originalJournalData() throws -> Data? { nil }
}
