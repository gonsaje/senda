import Foundation
import Testing
import SendaDomain
@testable import SendaPersistence

@MainActor struct TrainingPlanStorageTests {
    private let day = try! TrainingDay("2026-11-09")
    private func fixture() throws -> JournalSnapshot {
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [
            SetValues(weight: 4500, reps: 10), SetValues(weight: 13500, reps: 12), SetValues(weight: 12500, reps: 9)
        ]), at: day.date())
        var warmup = TrainingRow(set: batch.sets[0], unit: .pounds)
        warmup.kind = .warmup; warmup.repsInReserve = 4
        var working = TrainingRow(set: batch.sets[1], unit: .pounds)
        working.kind = .working; working.repsInReserve = 5
        let unknown = TrainingRow(set: batch.sets[2], unit: .pounds)
        let draft = TrainingRow(weight: "31.", unit: .pounds, weightIsDirty: true, kind: .working)
        let workout = DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench",
            rows: ["bench": [warmup, working, unknown, draft]],
            exercisePlans: ["bench": ExercisePlan(workingSets: 2, minimumReps: 8, maximumReps: 12)])
        return try JournalSnapshot(journal: journal, training: TrainingWorkspace(visibleWeek: day, selectedDay: day,
            days: [day.rawValue: workout])).validated()
    }
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("senda-plan-storage-\(UUID()).json") }
    private func object(_ bytes: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    }
    private func bytes(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
    private func withoutNewFields(_ value: [String: Any]) throws -> [String: Any] {
        var training = value
        var days = try #require(training["days"] as? [String: [String: Any]])
        for key in days.keys {
            var workout = days[key]!
            workout.removeValue(forKey: "exercisePlans")
            var rows = try #require(workout["rows"] as? [String: [[String: Any]]])
            for exercise in rows.keys {
                rows[exercise] = rows[exercise]!.map { row in
                    var row = row; row.removeValue(forKey: "kind"); row.removeValue(forKey: "repsInReserve"); return row
                }
            }
            workout["rows"] = rows; days[key] = workout
        }
        training["days"] = days; return training
    }
    @Test func formatSevenPreservesPlanAnnotationsAndUnfinishedInput() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let saved = try fixture(), store = FileJournalRepository(url: url)
        try store.saveSnapshot(saved)
        #expect(try object(Data(contentsOf: url))["version"] as? Int == 7)
        #expect(try store.loadSnapshot() == saved)
        let loaded = try store.loadSnapshot()
        #expect(loaded.training?.days[day.rawValue]?.rows["bench"]?.last?.weight == "31.")
        #expect(loaded.journal == saved.journal)
    }
    @Test func fullBackupVersionFourRetainsPlansAndAllAnnotationStates() throws {
        let original = NotebookArchive(snapshot: try fixture(), profile: ProfileDetails())
        let data = try NotebookBackupCodec.encode(original)
        #expect(try object(data)["version"] as? Int == 4)
        #expect(try NotebookBackupCodec.decode(data) == original)
        #expect(try JSONDecoder().decode(NotebookArchive.self, from: data) == original)
    }
    @Test func csvAppendsReadableMetadataWithoutInventingUnknownValuesOrExportingDrafts() throws {
        let snapshot = try fixture()
        let data = try NotebookBackupCodec.csv(snapshot: snapshot)
        let text = try #require(String(data: data, encoding: .utf8))
        let rows = text.components(separatedBy: "\r\n").filter { !$0.isEmpty }.map { $0.components(separatedBy: ",") }
        #expect(rows.count == 4)
        #expect(Array(rows[0][10...14]) == ["Set Type", "Reps Left", "Planned Working Sets", "Minimum Reps", "Maximum Reps"])
        #expect(Array(rows[1][10...14]) == ["warmup", "4", "2", "8", "12"])
        #expect(Array(rows[2][10...14]) == ["working", "5+", "2", "8", "12"])
        #expect(Array(rows[3][10...14]) == ["", "", "2", "8", "12"])
        #expect(!text.contains("31."))
        #expect(rows[2][5...7] == ["135", "61.23496995", "12"])
    }
    @Test func legacyFormatFourLoadsUnchangedAndMissingAnnotationsStayUnknown() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let store = FileJournalRepository(url: url)
        try store.saveSnapshot(fixture())
        var json = try object(Data(contentsOf: url)); json["version"] = 4
        json["training"] = try withoutNewFields(#require(json["training"] as? [String: Any]))
        let oldBytes = try bytes(json); try oldBytes.write(to: url)
        let loaded = try store.loadSnapshot()
        #expect(try Data(contentsOf: url) == oldBytes)
        #expect(loaded.training?.days[day.rawValue]?.exercisePlans == nil)
        #expect(loaded.training?.days[day.rawValue]?.rows["bench"]?.allSatisfy { $0.kind == nil && $0.repsInReserve == nil } == true)
    }
    @Test func legacyBackupVersionOneRetainsHistoryWithoutInventingPlanOrEffort() throws {
        let original = NotebookArchive(snapshot: try fixture(), profile: ProfileDetails())
        var json = try object(NotebookBackupCodec.encode(original)); json["version"] = 1
        var snapshot = try #require(json["snapshot"] as? [String: Any])
        snapshot["training"] = try withoutNewFields(#require(snapshot["training"] as? [String: Any])); json["snapshot"] = snapshot
        let loaded = try NotebookBackupCodec.decode(bytes(json))
        #expect(loaded.snapshot.journal == original.snapshot.journal)
        #expect(loaded.snapshot.training?.days[day.rawValue]?.exercisePlans == nil)
        #expect(loaded.snapshot.training?.days[day.rawValue]?.rows["bench"]?.allSatisfy { $0.kind == nil && $0.repsInReserve == nil } == true)
    }
    @Test(arguments: [TrainingSetKind.regular, .working, .warmup, .dropSet])
    func deletedSetBackupRetainsEffortKindAndPlanThroughRestore(_ kind: TrainingSetKind) throws {
        var snapshot = try fixture()
        var row = snapshot.training!.days[day.rawValue]!.rows["bench"]!.remove(at: 1)
        row.kind = kind
        let removal = try snapshot.journal.removeSet(try #require(row.performedSetID))
        snapshot.training!.undo = .deleted(day: day, exerciseID: "bench", index: 1, row: row, removal: removal)
        let archive = NotebookArchive(snapshot: snapshot, profile: ProfileDetails())
        let loaded = try NotebookBackupCodec.decode(NotebookBackupCodec.encode(archive))
        #expect(loaded == archive)
        guard case .deleted(_, _, _, let restored, _)? = loaded.snapshot.training?.undo else { Issue.record("Missing deleted row"); return }
        #expect(restored.kind == kind && restored.repsInReserve == 5)
        #expect(loaded.snapshot.training?.days[day.rawValue]?.exercisePlans?["bench"] == ExercisePlan(workingSets: 2, minimumReps: 8, maximumReps: 12))
    }
    @Test func failedPlanWriteLeavesExistingBytesAndMetadataUntouched() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let store = FileJournalRepository(url: url), original = try fixture()
        try store.saveSnapshot(original); let oldBytes = try Data(contentsOf: url)
        var candidate = original
        candidate.training!.days[day.rawValue]!.exercisePlans!["bench"] = ExercisePlan(workingSets: 4, minimumReps: 6, maximumReps: 10)
        let failing = FileJournalRepository(url: url) { _, _ in throw CocoaError(.fileWriteUnknown) }
        #expect(throws: (any Error).self) { try failing.saveSnapshot(candidate) }
        #expect(try Data(contentsOf: url) == oldBytes)
        #expect(try store.loadSnapshot() == original)
    }
}
