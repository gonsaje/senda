import Foundation
import Testing
import SendaDomain
@testable import SendaPersistence

@MainActor struct TrainingStorageTests {
    private var day: TrainingDay { try! TrainingDay("2026-11-07") }
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("senda-week-\(UUID()).json") }
    private func workspace() -> TrainingWorkspace {
        TrainingWorkspace(visibleWeek: try! day.week()[0], selectedDay: day, days: [day.rawValue: DayWorkout(
            exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": [TrainingRow(weight: "31.", reps: "", unit: .pounds, weightIsDirty: true)]]
        )])
    }
    @Test func formatFourPersistsIncompleteRowsAndJournalOnlySavesRetainThem() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileJournalRepository(url: url)
        let snapshot = JournalSnapshot(training: workspace())
        try repository.saveSnapshot(snapshot)
        #expect(try repository.loadSnapshot() == snapshot)
        try repository.save(Journal())
        #expect(try repository.loadSnapshot().training == snapshot.training)
        let data = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect(data["version"] as? Int == 4)
        #expect(data["trainingEnabled"] as? Bool == true)
    }
    @Test func missingEnabledWorkspaceIsRejectedWithoutRewriting() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileJournalRepository(url: url)
        try repository.saveSnapshot(JournalSnapshot(training: workspace()))
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json.removeValue(forKey: "training")
        let bytes = try JSONSerialization.data(withJSONObject: json)
        try bytes.write(to: url)
        #expect(throws: (any Error).self) { try repository.loadSnapshot() }
        #expect(try Data(contentsOf: url) == bytes)
    }
    @Test func failedWeeklyWriteLeavesTheCompleteOldSnapshotUntouched() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileJournalRepository(url: url)
        try repository.saveSnapshot(JournalSnapshot())
        let bytes = try Data(contentsOf: url)
        let failing = FileJournalRepository(url: url) { _, _ in throw CocoaError(.fileWriteUnknown) }
        #expect(throws: (any Error).self) { try failing.saveSnapshot(JournalSnapshot(training: workspace())) }
        #expect(try Data(contentsOf: url) == bytes)
    }
}
