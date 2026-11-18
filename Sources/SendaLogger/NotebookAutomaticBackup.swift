import CryptoKit
import Foundation
import Observation
import SendaPersistence

@Observable @MainActor
public final class NotebookAutomaticBackup {
    private struct Settings: Codable {
        var destination: NotebookBackupDestination
        var lastSavedAt: Date?
        var fingerprint: Data?
    }

    private var settings: Settings?
    private let settingsURL: URL?
    private let now: () -> Date
    @ObservationIgnored private var lastAutomaticAttempt: Date?

    public private(set) var isSaving = false
    public private(set) var errorMessage: String?
    public var isChoosingFolder = false
    public var folderName: String? { settings?.destination.name }
    public var lastSavedAt: Date? { settings?.lastSavedAt }

    public init(settingsURL: URL?, now: @escaping () -> Date = Date.init) {
        self.settingsURL = settingsURL
        self.now = now
        guard let settingsURL else { return }
        do {
            settings = try JSONDecoder().decode(Settings?.self, from: Data(contentsOf: settingsURL))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // Automatic backups start off until a folder is chosen.
        } catch {
            errorMessage = "Backup settings couldn’t be opened. Choose a folder again."
        }
    }

    @discardableResult
    public func chooseFolder(_ folder: URL) -> Bool {
        guard !isSaving else {
            errorMessage = "A backup is in progress. Choose the folder again after it finishes."
            return false
        }
        do {
            let settings = Settings(destination: try NotebookBackupDestination(folder: folder))
            try saveSettings(settings)
            self.settings = settings
            errorMessage = nil
            lastAutomaticAttempt = nil
            return true
        } catch {
            errorMessage = "Couldn’t set the backup folder. " + error.localizedDescription
            return false
        }
    }

    public func turnOff() {
        guard !isSaving else { return }
        do {
            try saveSettings(nil)
            settings = nil
            errorMessage = nil
            lastAutomaticAttempt = nil
        } catch {
            errorMessage = "Couldn’t turn off automatic backups. " + error.localizedDescription
        }
    }

    public func backUpWhenDue(archive: () throws -> NotebookArchive) async {
        await backUpWhenDue(wait: { try await Task.sleep(for: .seconds($0)) }, archive: archive)
    }

    func backUpWhenDue(wait: (TimeInterval) async throws -> Void, archive: () throws -> NotebookArchive) async {
        while let delay = await checkForBackup(archive: archive) {
            do { try await wait(delay) } catch { return }
        }
    }

    public func backUpIfDue(archive: () throws -> NotebookArchive) async {
        _ = await checkForBackup(archive: archive)
    }

    /// Returns the delay until a deferred check should run again while the notebook stays active.
    private func checkForBackup(archive: () throws -> NotebookArchive) async -> TimeInterval? {
        guard settings != nil, !isChoosingFolder, !Task.isCancelled else { return nil }
        // A slow Files provider can still be finishing the previous, cancelled edit's write.
        guard !isSaving else { return 4 }
        let date = now()
        let delay = max(Self.remaining(since: lastSavedAt, now: date, interval: 24 * 60 * 60),
                        Self.remaining(since: lastAutomaticAttempt, now: date, interval: 15 * 60))
        if delay > 0 { return delay }
        lastAutomaticAttempt = nil
        _ = await backUp(automatic: true, archive: archive)
        return lastAutomaticAttempt == nil ? nil : 15 * 60
    }

    @discardableResult
    public func backUpNow(archive: () throws -> NotebookArchive) async -> Bool {
        await backUp(automatic: false, archive: archive)
    }

    private func backUp(automatic: Bool, archive: () throws -> NotebookArchive) async -> Bool {
        guard var settings, !isSaving, !Task.isCancelled else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            let archive = try archive()
            let lastFingerprint = automatic ? settings.fingerprint : nil
            let prepared = try await Task.detached(priority: .utility) {
                let stable = NotebookArchive(snapshot: archive.snapshot, profile: archive.profile,
                                             createdAt: Date(timeIntervalSince1970: 0))
                let fingerprint = Data(SHA256.hash(data: try NotebookBackupCodec.encode(stable)))
                guard fingerprint != lastFingerprint else { return nil as PreparedBackup? }
                return PreparedBackup(data: try NotebookBackupCodec.encode(archive), fingerprint: fingerprint)
            }.value
            guard let prepared else { return false }
            try Task.checkCancellation()
            let date = now()
            let day = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            let filename = "Senda-\(day)-\(UUID().uuidString.prefix(8)).json"
            settings.destination = try await settings.destination.write(prepared.data, filename: filename)
            settings.lastSavedAt = date
            settings.fingerprint = prepared.fingerprint
            self.settings = settings
            do {
                try saveSettings(settings)
                errorMessage = nil
            } catch {
                errorMessage = "Backup saved, but Senda couldn’t update its backup settings."
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            if automatic { lastAutomaticAttempt = now() }
            errorMessage = "Couldn’t save a backup. " + error.localizedDescription
            return false
        }
    }

    private struct PreparedBackup: Sendable {
        let data: Data
        let fingerprint: Data
    }

    private func saveSettings(_ settings: Settings?) throws {
        guard let settingsURL else { return }
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(settings).write(to: settingsURL, options: .atomic)
    }

    private static func remaining(since previous: Date?, now: Date, interval: TimeInterval) -> TimeInterval {
        guard let previous else { return 0 }
        let elapsed = now.timeIntervalSince(previous)
        return elapsed < 0 ? 0 : max(0, interval - elapsed)
    }
}
