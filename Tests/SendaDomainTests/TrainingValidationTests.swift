import Foundation
import Testing
@testable import SendaDomain

struct TrainingValidationTests {
    private func fixture() throws -> JournalSnapshot {
        let day = try TrainingDay("2026-11-07")
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 100, reps: 10)]), at: Date())
        let row = TrainingRow(set: batch.sets[0], unit: .pounds)
        let workspace = TrainingWorkspace(visibleWeek: try day.week()[0], selectedDay: day, days: [day.rawValue: DayWorkout(
            exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": [row]])])
        return JournalSnapshot(journal: journal, training: workspace)
    }
    @Test func cachedWeightCannotSilentlyDisagreeWithDisplayedText() throws {
        var snapshot = try fixture()
        snapshot.training!.days["2026-11-07"]!.rows["bench"]![0].weight = "2"
        #expect(throws: (any Error).self) { try snapshot.validated() }
    }
    @Test func uncommittedValuesRequireAnActiveEditingRow() throws {
        var snapshot = try fixture()
        snapshot.training!.days["2026-11-07"]!.rows["bench"]![0].weight = "2"
        snapshot.training!.days["2026-11-07"]!.rows["bench"]![0].weightIsDirty = true
        #expect(throws: (any Error).self) { try snapshot.validated() }
    }
    @Test func danglingUndoCannotBeLoadedAndCrashTheNotebook() throws {
        var snapshot = try fixture()
        snapshot.training!.undo = .repeated(day: try TrainingDay("2026-11-06"), exerciseID: "bench", rowID: UUID())
        #expect(throws: (any Error).self) { try snapshot.validated() }
    }
}
