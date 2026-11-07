import Foundation
import Testing
@testable import SendaDomain

struct TrainingMigrationTests {
    private var day: TrainingDay { try! TrainingDay("2026-11-07") }
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    @Test func oldPerformedSetsKeepTheirDatesAndUnfinishedRowsStayUnperformed() throws {
        var journal = Journal()
        let before = try day.adding(days: -2)
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]), at: before.date(in: calendar))
        let recovery = EntryWorkspace(selectedExerciseID: "deadlift", sessions: [
            "bench": .recorded(batch.id),
            "deadlift": .draft(DraftBatch(exerciseID: "deadlift", sets: [SetValues(weight: 22_500, reps: 5)])),
            "row": .draft(DraftBatch(exerciseID: "row", sets: [SetValues(weight: 5_000, reps: 8)]))
        ], numberInputText: "61.", numberInputDirty: true, selectedSetIndex: 0, weightUnit: .kilograms)
        let source = JournalSnapshot(journal: journal, workspace: recovery)
        let result = try TrainingWorkspace.migrate(source, today: day, calendar: calendar)
        #expect(result.days[before.rawValue]?.rows["bench"]?.first?.performedSetID == batch.sets[0].id)
        #expect(result.days[day.rawValue]?.rows["deadlift"]?.first?.weight == "61.")
        #expect(result.days[day.rawValue]?.rows["deadlift"]?.first?.performedSetID == nil)
        #expect(result.days[day.rawValue]?.rows["row"]?.first?.reps == "8")
        #expect(result.days[day.rawValue]?.exerciseIDs.contains("row") == false)
        #expect(result.focus?.field == .weight)
        _ = try result.validated(against: journal, exercises: Exercise.catalog)
        #expect(source.journal == journal)
    }
    @Test func pendingGroupCorrectionsRequireReviewInsteadOfSilentlyCommitting() throws {
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]), at: day.date(in: calendar))
        let workspace = EntryWorkspace(sessions: ["bench": .editing(RecordedEdit(batchID: batch.id, revision: 1, sets: [SetValues(weight: 14_000, reps: 8)]))])
        let snapshot = JournalSnapshot(journal: journal, workspace: workspace)
        #expect(TrainingWorkspace.requiresLegacyReview(snapshot))
        #expect(throws: (any Error).self) { try TrainingWorkspace.migrate(snapshot, today: day, calendar: calendar) }
        #expect(snapshot.journal.batches[0].values[0].weight == 13_500)
    }
    @Test func unknownLegacyExerciseHistoryRemainsRepresented() throws {
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "legacy-lift", sets: [SetValues(weight: 100, reps: 8)]), at: day.date(in: calendar))
        let migrated = try TrainingWorkspace.migrate(JournalSnapshot(journal: journal), today: day, calendar: calendar)
        #expect(migrated.days[day.rawValue]?.exerciseIDs == ["legacy-lift"])
        #expect(migrated.days[day.rawValue]?.rows["legacy-lift"]?.first?.performedSetID == batch.sets[0].id)
        _ = try migrated.validated(against: journal, exercises: Exercise.catalog)
    }
}
