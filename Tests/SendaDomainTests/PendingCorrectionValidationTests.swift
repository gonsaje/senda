import Foundation
import Testing
@testable import SendaDomain

struct PendingCorrectionValidationTests {
    private func fixture() throws -> JournalSnapshot {
        let day = try TrainingDay("2026-11-07")
        var journal = Journal()
        let set = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]), at: Date()).sets[0]
        let row = TrainingRow(set: set, unit: .pounds)
        return JournalSnapshot(journal: journal, training: TrainingWorkspace(visibleWeek: try day.week()[0], selectedDay: day,
            days: [day.rawValue: DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": [row]])]))
    }
    private func marked(_ row: TrainingRow) throws -> TrainingRow {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
        json["pendingCorrection"] = true
        return try JSONDecoder().decode(TrainingRow.self, from: JSONSerialization.data(withJSONObject: json))
    }
    @Test func explicitPendingCorrectionMayDifferFromHistoryWithoutActiveFocus() throws {
        var snapshot = try fixture()
        var row = snapshot.training!.days["2026-11-07"]!.rows["bench"]![0]
        row.weight = "31."; row.weightIsDirty = true
        snapshot.training!.days["2026-11-07"]!.rows["bench"]![0] = try marked(row)
        #expect(throws: Never.self) { try snapshot.validated() }
    }
    @Test func pendingCorrectionStillRequiresALivePerformedReference() throws {
        var snapshot = try fixture()
        var row = snapshot.training!.days["2026-11-07"]!.rows["bench"]![0]
        row.performedSetID = nil
        snapshot.journal = Journal()
        snapshot.training!.days["2026-11-07"]!.rows["bench"]![0] = try marked(row)
        #expect(throws: (any Error).self) { try snapshot.validated() }
    }
    @Test func pendingCorrectionCannotPointToAnUnknownSet() throws {
        var snapshot = try fixture()
        var row = snapshot.training!.days["2026-11-07"]!.rows["bench"]![0]
        row.performedSetID = UUID()
        snapshot.training!.days["2026-11-07"]!.rows["bench"]![0] = try marked(row)
        #expect(throws: (any Error).self) { try snapshot.validated() }
    }
    @Test func oldRowsWithoutMarkerRemainReadableWithExactCanonicalWeight() throws {
        let row = TrainingRow(weight: "0.45", reps: "10", unit: .kilograms, canonicalWeight: 100)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
        json.removeValue(forKey: "pendingCorrection")
        let decoded = try JSONDecoder().decode(TrainingRow.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded == row && decoded.parsedWeight == 100)
    }
}
