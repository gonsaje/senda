import Foundation
import Testing
@testable import SendaDomain

struct TrainingPlanTests {
    @Test func invalidPlansCannotEnterAValidatedSnapshot() throws {
        let day = try TrainingDay("2026-11-09")
        for plan in [ExercisePlan(workingSets: 0, minimumReps: 8, maximumReps: 12),
                     ExercisePlan(workingSets: 31, minimumReps: 8, maximumReps: 12),
                     ExercisePlan(workingSets: 3, minimumReps: 0, maximumReps: 12),
                     ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 1000),
                     ExercisePlan(workingSets: 3, minimumReps: 12, maximumReps: 8)] {
            #expect(throws: TrainingError.invalidWorkspace) { try plan.validated() }
            let workout = DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": []], exercisePlans: ["bench": plan])
            let snapshot = JournalSnapshot(training: TrainingWorkspace(visibleWeek: day, days: [day.rawValue: workout]))
            #expect(throws: TrainingError.invalidWorkspace) { try snapshot.validated() }
        }
    }

    @Test func invalidEffortAndOrphanPlansAreRejected() throws {
        let day = try TrainingDay("2026-11-09")
        let plan = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)
        for effort in [-1, 6] {
            let row = TrainingRow(unit: .pounds, kind: .working, repsInReserve: effort)
            let workout = DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": [row]])
            let snapshot = JournalSnapshot(training: TrainingWorkspace(visibleWeek: day, days: [day.rawValue: workout]))
            #expect(throws: TrainingError.invalidWorkspace) { try snapshot.validated() }
        }
        let workout = DayWorkout(exercisePlans: ["bench": plan])
        #expect(throws: TrainingError.invalidWorkspace) {
            try JournalSnapshot(training: TrainingWorkspace(visibleWeek: day, days: [day.rawValue: workout])).validated()
        }
    }

    @Test func deletedUndoCannotCarryInvalidEffort() throws {
        let day = try TrainingDay("2026-11-09")
        let row = TrainingRow(unit: .pounds, kind: .working, repsInReserve: 6)
        let workout = DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": []])
        let training = TrainingWorkspace(visibleWeek: day, days: [day.rawValue: workout],
            undo: .deleted(day: day, exerciseID: "bench", index: 0, row: row, removal: nil))
        #expect(throws: TrainingError.invalidWorkspace) { try JournalSnapshot(training: training).validated() }
    }

    @Test func oldRowsAndMigrationRetainUnknownMetadata() throws {
        let data = Data(#"{"id":"00000000-0000-0000-0000-000000000001","actionID":"00000000-0000-0000-0000-000000000002","weight":"","reps":"","unit":"lb","weightIsDirty":false}"#.utf8)
        let row = try JSONDecoder().decode(TrainingRow.self, from: data)
        #expect(row.kind == nil)
        #expect(row.repsInReserve == nil)
        let day = try TrainingDay("2026-11-09")
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 10_000, reps: 8)]), at: Date())
        let migrated = try TrainingWorkspace.migrate(JournalSnapshot(journal: journal), today: day, calendar: .current)
        #expect(migrated.days.values.flatMap { $0.rows.values.joined() }.allSatisfy { $0.kind == nil && $0.repsInReserve == nil })
        #expect(migrated.days.values.allSatisfy { $0.exercisePlans == nil })
    }

    @Test func validBoundsAndHiddenExercisePlanRoundTripExactly() throws {
        let day = try TrainingDay("2026-11-09")
        let row = TrainingRow(unit: .pounds, kind: .warmup, repsInReserve: 5)
        let plans = ["bench": ExercisePlan(workingSets: 30, minimumReps: 1, maximumReps: 999)]
        let workout = DayWorkout(rows: ["bench": [row]], exercisePlans: plans)
        let snapshot = JournalSnapshot(training: TrainingWorkspace(visibleWeek: day, days: [day.rawValue: workout]))
        _ = try snapshot.validated()
        #expect(try JSONDecoder().decode(JournalSnapshot.self, from: JSONEncoder().encode(snapshot)) == snapshot)
    }
}
