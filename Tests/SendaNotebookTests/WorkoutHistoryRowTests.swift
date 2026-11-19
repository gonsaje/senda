import Foundation
import SendaDomain
import Testing
@testable import SendaNotebook

struct WorkoutHistoryRowTests {
    @Test func recordedDropKeepsStageNumberWhenStartIsBlank() throws {
        let group = UUID(), setID = UUID()
        let draftRows = [
            TrainingRow(unit: .pounds, kind: .dropSet, dropGroupID: group),
            TrainingRow(weight: "95.", reps: "", unit: .pounds, performedSetID: setID,
                        pendingCorrection: true, kind: .dropSet, dropGroupID: group)
        ]
        let saved = ExerciseProgressSet(id: setID, batchID: UUID(), values: SetValues(weight: 9_500, reps: 8),
                                       position: 2, recordedAt: .now, dropGroupID: group)
        let session = ExerciseProgressSession(day: try TrainingDay("2026-11-10"), exerciseID: "bench",
                                             sets: [saved], bestSet: saved)
        let rows = WorkoutHistoryRow.records(session, rows: draftRows)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.label == "Set 1 · Drop 1")
        #expect(row.values == SetValues(weight: 9_500, reps: 8))
    }
}
