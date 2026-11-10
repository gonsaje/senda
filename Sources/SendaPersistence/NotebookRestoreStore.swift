import Foundation
import SendaDomain

/// Restores a complete notebook while protecting the pair of journal/profile files.
@MainActor public protocol NotebookRestoreStore {
    func recoverInterruptedRestore() throws
    func restore(_ archive: NotebookArchive, current: NotebookArchive?) throws
    func previousBackupData() throws -> Data?
    func previousOriginalFilesData() throws -> Data?
    func originalJournalData() throws -> Data?
}

public extension NotebookRestoreStore {
    func previousOriginalFilesData() throws -> Data? { nil }
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
        let originals = try OriginalPair(journal: capture(journalURL), profile: capture(profileURL))
        let recoveryData = try JSONEncoder().encode(originals)
        try FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let previous {
            try writer(previous, backupURL)
            try removeIfPresent(originalsURL)
        } else {
            try writer(recoveryData, originalsURL)
            try removeIfPresent(backupURL)
        }
        // This durable marker is written before either live file is touched.
        try writer(recoveryData, pendingURL)
        do {
            try FileProfileRepository(url: profileURL, writer: writer).save(archive.profile)
            try FileJournalRepository(url: journalURL, writer: writer).saveSnapshot(archive.snapshot)
            // Until removal succeeds, a relaunch rolls back to the original pair.
            try remover(pendingURL)
        } catch {
            let originalError = error
            do { try recoverInterruptedRestore() }
            catch { throw NotebookRestoreError.recoveryRequired }
            throw originalError
        }
    }

    public func recoverInterruptedRestore() throws {
        guard let data = try readIfPresent(pendingURL) else { return }
        let originals: OriginalPair
        do { originals = try JSONDecoder().decode(OriginalPair.self, from: data).validated() }
        catch { throw NotebookRestoreError.recoveryRequired }
        var failed = false
        // Attempt both restorations even if one device write is still unavailable.
        for (file, url) in [(originals.journal, journalURL), (originals.profile, profileURL)] {
            do {
                if let contents = file.contents {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try writer(contents, url)
                } else { try removeIfPresent(url) }
            } catch { failed = true }
        }
        guard !failed else { throw NotebookRestoreError.recoveryRequired }
        do { try remover(pendingURL) }
        catch { throw NotebookRestoreError.recoveryRequired }
    }

    public func previousBackupData() throws -> Data? {
        guard let data = try readIfPresent(backupURL) else { return nil }
        _ = try NotebookBackupCodec.decode(data)
        return data
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
    private func readIfPresent(_ url: URL) throws -> Data? {
        do { return try Data(contentsOf: url) }
        catch { if isMissing(error) { return nil }; throw error }
    }
    private func removeIfPresent(_ url: URL) throws {
        do { try remover(url) }
        catch { if !isMissing(error) { throw error } }
    }
    private func isMissing(_ error: any Error) -> Bool {
        guard let error = error as? CocoaError else { return false }
        return error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile
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
        previous = previousData
        pending = original
        do {
            try profileRepository.save(archive.profile)
            try repository.saveSnapshot(archive.snapshot)
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
