import Foundation
import SendaDomain
import Testing
@testable import SendaPersistence

@MainActor struct NotebookBackupReviewTests {
    @Test func reviewsValidatedArchiveAndHandlesMissingOrUnreadableCopies() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileNotebookRestoreStore(journalURL: root.appendingPathComponent("journal.json"),
                                               profileURL: root.appendingPathComponent("profile.json"))
        #expect(try await store.previousBackupArchive() == nil)

        let workout = WorkoutTemplate(name: "My routine", exerciseIDs: ["bench"])
        let training = TrainingWorkspace(visibleWeek: try TrainingDay("2026-11-16"), workoutTemplates: [workout])
        let previous = NotebookArchive(snapshot: JournalSnapshot(training: training), profile: ProfileDetails(name: "Previous"))
        try NotebookBackupCodec.encode(previous).write(to: store.backupURL)
        #expect(try await store.previousBackupArchive() == previous)

        try Data("Invalid backup".utf8).write(to: store.backupURL)
        await #expect(throws: NotebookBackupError.invalidBackup) { try await store.previousBackupArchive() }
    }
}
