import Testing
import Foundation
import SendaDomain
@testable import SendaPersistence

@MainActor
struct SnapshotTests {
    private func location() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("senda-snapshot-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("journal.json")
    }
    private func workspace() -> EntryWorkspace {
        EntryWorkspace(sessions: ["bench": .draft(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_750, reps: 8)]))],
                       numberInputText: "137.", numberInputDirty: true)
    }

    @Test func snapshotRoundTripKeepsUnfinishedInputOutsideHistory() throws {
        let url = try location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let snapshot = JournalSnapshot(workspace: workspace())
        try FileJournalRepository(url: url).saveSnapshot(snapshot)
        let restored = try FileJournalRepository(url: url).loadSnapshot()
        #expect(restored == snapshot)
        #expect(restored.journal.batches.isEmpty)
    }

    @Test func versionOneLoadsWithoutRewritingAndUpgradesOnNextWrite() throws {
        let url = try location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var journal = Journal()
        let request = DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)])
        _ = try journal.record(request, at: Date(timeIntervalSince1970: 1000))
        struct Legacy: Encodable { let version = 1; let journal: Journal }
        let bytes = try JSONEncoder().encode(Legacy(journal: journal))
        try bytes.write(to: url)
        let store = FileJournalRepository(url: url)
        let loaded = try store.loadSnapshot()
        #expect(loaded.journal == journal)
        #expect(loaded.workspace == nil)
        #expect(try Data(contentsOf: url) == bytes)
        try store.saveSnapshot(JournalSnapshot(journal: journal, workspace: workspace()))
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect(object["version"] as? Int == 3)
        var reloaded = try store.loadSnapshot().journal
        _ = try reloaded.record(request, at: Date())
        #expect(reloaded.batches.count == 1, "Migration retains action receipts")
    }

    @Test func failedCombinedWritePreservesHistoryAndWorkspaceBytes() throws {
        let url = try location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let snapshot = JournalSnapshot(workspace: workspace())
        let store = FileJournalRepository(url: url)
        try store.saveSnapshot(snapshot)
        let bytes = try Data(contentsOf: url)
        var candidate = snapshot
        if case .draft(let entry) = candidate.workspace?.sessions["bench"] {
            let batch = try candidate.journal.record(entry, at: Date())
            candidate.workspace?.sessions["bench"] = .recorded(batch.id)
            candidate.workspace?.numberInputDirty = false
            candidate.workspace?.numberInputText = "137.5"
        }
        let failing = FileJournalRepository(url: url, writer: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        #expect(throws: (any Error).self) { try failing.saveSnapshot(candidate) }
        #expect(try Data(contentsOf: url) == bytes)
        #expect(try store.loadSnapshot() == snapshot)
    }

    @Test func workspaceRejectsDanglingReferencesAndMismatchedExercises() throws {
        var invalid = workspace()
        invalid.sessions["bench"] = .recorded(UUID())
        #expect(throws: (any Error).self) { try JournalSnapshot(workspace: invalid).validated() }
        invalid = workspace()
        invalid.selectedExerciseID = "deadlift"
        #expect(throws: (any Error).self) { try JournalSnapshot(workspace: invalid).validated() }
    }
}
