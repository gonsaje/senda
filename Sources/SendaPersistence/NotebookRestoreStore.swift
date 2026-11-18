import Foundation
import SendaDomain

/// Restores a complete notebook while protecting the pair of journal/profile files.
@MainActor public protocol NotebookRestoreStore {
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
    private let writer: (Data, URL) throws -> Void
    private let remover: (URL) throws -> Void
    let pendingURL: URL
    let backupURL: URL
    let originalsURL: URL

    public convenience init(journalURL: URL, profileURL: URL) {
        self.init(journalURL: journalURL, profileURL: profileURL,
            writer: { try $0.write(to: $1, options: .atomic) })
    }
    init(journalURL: URL, profileURL: URL, writer: @escaping (Data, URL) throws -> Void,
         remover: @escaping (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.journalURL = journalURL; self.profileURL = profileURL
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
        try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
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
            let originals = try OriginalPair(journal: capture(stagedURL(for: .journal)),
                                            profile: capture(stagedURL(for: .profile)))
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
            try FileProfileRepository(url: profileURL, writer: writer).save(archive.profile)
            try FileJournalRepository(url: journalURL, writer: writer).saveSnapshot(archive.snapshot)
            if let previous {
                try writer(previous, backupURL)
                try removeIfPresent(originalsURL)
            } else if let rawRecovery {
                try writer(rawRecovery, originalsURL)
                try removeIfPresent(backupURL)
            }
            // Until removal succeeds, a relaunch rolls back to the original pair.
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
                guard checkpoint.version == 1,
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
                for part in RestorePart.allCases {
                    do { try restoreFile(at: liveURL(for: part), contents: originals[part]) }
                    catch { failed = true }
                }
                guard !failed else { throw NotebookRestoreError.recoveryRequired }
            } else {
                // Markers from older builds stored only the original live files inline.
                let live = try decoder.decode(OriginalPair.self, from: data).validated()
                var failed = false
                for (url, file) in [(journalURL, live.journal), (profileURL, live.profile)] {
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
        case .backup: backupURL
        case .rawBackup: originalsURL
        }
    }

    private func discardStaging() {
        try? FileManager.default.removeItem(at: stagingURL)
    }

    private func restoreFile(at url: URL, contents: Data?) throws {
        if try readIfPresent(url) == contents { return }
        if let contents {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try writer(contents, url)
        } else {
            try removeIfPresent(url)
        }
    }

    public func previousBackupData() throws -> Data? {
        guard let data = try readIfPresent(backupURL) else { return nil }
        _ = try NotebookBackupCodec.decode(data)
        return data
    }
    public func previousBackupArchive() async throws -> NotebookArchive? {
        try await Task.detached(priority: .userInitiated) { [backupURL] in
            guard let data = try self.readIfPresent(backupURL) else { return nil }
            return try NotebookBackupCodec.decode(data)
        }.value
    }
    public func previousOriginalFilesData() throws -> Data? {
        guard let data = try readIfPresent(originalsURL) else { return nil }
        _ = try JSONDecoder().decode(OriginalPair.self, from: data).validated()
        return data
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
    case journal, profile, backup, rawBackup
}

private struct RestoreCheckpoint: Codable {
    let format: String
    let version: Int
    let present: Set<RestorePart>

    init(present: Set<RestorePart>) {
        format = "senda-restore-checkpoint"
        version = 1
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
private struct OriginalPair: Codable {
    let format: String
    let version: Int
    let journal: OriginalFile
    let profile: OriginalFile
    init(journal: OriginalFile, profile: OriginalFile) {
        format = "senda-restore-recovery"; version = 1
        self.journal = journal; self.profile = profile
    }
    func validated() throws -> Self {
        guard format == "senda-restore-recovery", version == 1 else { throw NotebookRestoreError.recoveryRequired }
        try journal.validated(); try profile.validated()
        return self
    }
}

@MainActor public final class MemoryNotebookRestoreStore: NotebookRestoreStore {
    private let repository: any JournalRepository
    private let profileRepository: any ProfileRepository
    private var previous: Data?
    private var pending: (JournalSnapshot, ProfileDetails)?
    public init(repository: any JournalRepository, profileRepository: any ProfileRepository) {
        self.repository = repository; self.profileRepository = profileRepository
    }
    public func restore(_ archive: NotebookArchive, current: NotebookArchive?) throws {
        let archive = try archive.validated()
        let previousData = try current.map(NotebookBackupCodec.encode)
        try recoverInterruptedRestore()
        let original = try (repository.loadSnapshot(), profileRepository.load())
        pending = original
        do {
            try profileRepository.save(archive.profile)
            try repository.saveSnapshot(archive.snapshot)
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
        guard !failed else { throw NotebookRestoreError.recoveryRequired }
        pending = nil
    }
    public func previousBackupData() throws -> Data? { previous }
    public func originalJournalData() throws -> Data? { nil }
}
