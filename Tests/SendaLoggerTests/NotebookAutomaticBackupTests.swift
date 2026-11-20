import Foundation
import SendaDomain
import SendaPersistence
import Testing
@testable import SendaLogger

@MainActor struct NotebookAutomaticBackupTests {
    @Test func automaticBackupRejectsAFolderOutsideICloud() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let backup = NotebookAutomaticBackup(settingsURL: nil)
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        #expect(!backup.chooseFolder(folder))
        #expect(!(await backup.backUpNow { try model.backupArchive() }))
        #expect(try files(in: folder).isEmpty)
    }

    @Test func existingNonICloudBookmarkCannotWriteAfterUpgrade() async throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Legacy backup folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let settingsURL = root.appendingPathComponent("backup-settings.json")
        let oldSettings = NotebookAutomaticBackup(settingsURL: settingsURL, validateFolder: { _ in })
        try #require(oldSettings.chooseFolder(folder))

        let backup = NotebookAutomaticBackup(settingsURL: settingsURL)
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        #expect(!(await backup.backUpNow { try model.backupArchive() }))
        #expect(backup.lastSavedAt == nil)
        #expect(backup.errorMessage != nil)
        #expect(try files(in: folder).isEmpty)
    }

    @Test func savesDatedCopiesAndSkipsUnchangedAutomaticBackups() async throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Backups")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let settingsURL = root.appendingPathComponent("App Support/backup-settings.json")
        var clock = Date(timeIntervalSince1970: 1_780_000_000)
        let setup = NotebookAutomaticBackup(settingsURL: settingsURL, now: { clock }, validateFolder: { _ in })
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), now: { clock })

        try model.bodyMeasurements.add([.weight: 70], on: clock)
        #expect(setup.errorMessage == nil)
        await setup.backUpIfDue { try model.backupArchive() }
        #expect(try files(in: folder).isEmpty)
        #expect(setup.chooseFolder(folder))
        await setup.backUpNow { try model.backupArchive() }
        let first = try #require(files(in: folder).first)
        let backup = NotebookAutomaticBackup(settingsURL: settingsURL, now: { clock }, validateFolder: { _ in })
        #expect(backup.folderName == "Backups")
        #expect(backup.lastSavedAt == clock)
        #expect(try NotebookBackupCodec.decode(Data(contentsOf: first)).profile.name.isEmpty)

        #expect(try NotebookBackupCodec.decode(Data(contentsOf: first)).manualMeasurements == nil)
        try model.bodyMeasurements.add([.weight: 71], on: clock)
        clock.addTimeInterval(24 * 60 * 60)
        await backup.backUpIfDue { try model.backupArchive() }
        #expect(try files(in: folder) == [first])

        #expect(model.profile.saveName("Avery"))
        await backup.backUpIfDue { try model.backupArchive() }
        let second = try #require(files(in: folder).first(where: { $0 != first }))
        #expect(backup.lastSavedAt == clock)
        #expect(try NotebookBackupCodec.decode(Data(contentsOf: second)).profile.name == "Avery")
        #expect(try NotebookBackupCodec.decode(Data(contentsOf: first)).profile.name.isEmpty)

        #expect(model.profile.saveName("Avery S"))
        await backup.backUpIfDue { try model.backupArchive() }
        #expect(try files(in: folder).count == 2)
        await backup.backUpNow { try model.backupArchive() }
        #expect(try files(in: folder).count == 3)

        backup.turnOff()
        await backup.backUpNow { try model.backupArchive() }
        #expect(backup.folderName == nil)
        #expect(try files(in: folder).count == 3)
        #expect(NotebookAutomaticBackup(settingsURL: settingsURL).folderName == nil)
    }

    @Test func unreadableNotebookDoesNotAdvanceLastSavedDateAndCanBeRetried() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        let backup = NotebookAutomaticBackup(settingsURL: nil, validateFolder: { _ in })
        #expect(backup.chooseFolder(folder))

        struct UnreadableNotebook: Error {}
        await backup.backUpNow { throw UnreadableNotebook() }
        #expect(backup.lastSavedAt == nil)
        #expect(backup.errorMessage != nil)
        #expect(try files(in: folder).isEmpty)

        await backup.backUpNow { try model.backupArchive() }
        #expect(backup.lastSavedAt != nil)
        #expect(backup.errorMessage == nil)
        #expect(try files(in: folder).count == 1)
    }

    @Test func activeCheckWaitsForCutoffAndRetriesFailureWithoutAnotherEdit() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        var clock = Date(timeIntervalSince1970: 1_780_000_000)
        let backup = NotebookAutomaticBackup(settingsURL: nil, now: { clock }, validateFolder: { _ in })
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), now: { clock })
        #expect(backup.chooseFolder(folder))
        #expect(await backup.backUpNow { try model.backupArchive() })
        clock.addTimeInterval(24 * 60 * 60 - 10)
        #expect(model.profile.saveName("Changed"))

        var waits: [TimeInterval] = []
        var attempts = 0
        await backup.backUpWhenDue(wait: { seconds in
            waits.append(seconds)
            guard waits.count <= 2 else { throw CancellationError() }
            clock.addTimeInterval(seconds)
        }, archive: {
            attempts += 1
            if attempts == 1 { throw CocoaError(.fileReadUnknown) }
            return try model.backupArchive()
        })
        #expect(waits == [10.0, 15.0 * 60.0])
        #expect(attempts == 2)
        #expect(backup.lastSavedAt == clock)
        #expect(try files(in: folder).count == 2)
    }

    @Test func renamedFolderIsRememberedAfterAnotherBackupAndRelaunch() async throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Backups", isDirectory: true)
        let renamed = root.appendingPathComponent("Training", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let settingsURL = root.appendingPathComponent("backup-settings.json")
        let backup = NotebookAutomaticBackup(settingsURL: settingsURL, validateFolder: { _ in })
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        #expect(backup.chooseFolder(folder))
        #expect(await backup.backUpNow { try model.backupArchive() })
        try FileManager.default.moveItem(at: folder, to: renamed)
        #expect(await backup.backUpNow { try model.backupArchive() })
        #expect(backup.folderName == "Training")

        let reopened = NotebookAutomaticBackup(settingsURL: settingsURL, validateFolder: { _ in })
        #expect(reopened.folderName == "Training")
        #expect(await reopened.backUpNow { try model.backupArchive() })
        #expect(try files(in: renamed).count == 3)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        return folder
    }

    private func files(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    }
}
