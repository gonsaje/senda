import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct TrainingNotebookTests {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private var day: TrainingDay { try! TrainingDay("2026-11-07") }
    private func model(_ store: (any JournalRepository)? = nil) throws -> TrainingNotebookModel {
        try TrainingNotebookModel(repository: store ?? MemoryJournalRepository(), calendar: calendar, now: { self.day.date(in: self.calendar) })
    }
    private func enter(_ model: TrainingNotebookModel, weight: String, reps: String) throws {
        let row = try #require(model.rows.last)
        #expect(model.selectInput(row.id, field: .weight))
        model.typeInput(weight, focus: try #require(model.focus))
        #expect(model.selectInput(row.id, field: .reps))
        model.typeInput(reps, focus: try #require(model.focus))
    }
    @Test func weekCategoriesAreUniqueStableAndOnlyIncludePerformedExercises() throws {
        let m = try model()
        #expect(m.openDay(day))
        #expect(m.summary(for: day).muscleGroups.isEmpty)
        #expect(m.addExercise("overhead-press"))
        try enter(m, weight: "95", reps: "8"); #expect(m.finishEditing())
        #expect(m.addExercise("bench"))
        try enter(m, weight: "135", reps: "10"); #expect(m.finishEditing())
        #expect(m.addExercise("dumbbell-bench"))
        try enter(m, weight: "50", reps: "12"); #expect(m.finishEditing())
        #expect(m.addExercise("squat"))
        try enter(m, weight: "185", reps: ""); #expect(m.finishEditing())
        let summary = m.summary(for: day)
        #expect(summary.muscleGroups == [.chest, .shoulders])
        #expect(summary.setCount == 3)
        #expect(summary.exercises == ["Overhead press", "Bench", "Dumbbell bench"])
        #expect(m.summary(for: try day.adding(days: -1)).muscleGroups.isEmpty)
        #expect(m.showWeek()); #expect(m.openDay(day)); #expect(m.selectExercise("bench"))
        #expect(m.rows.count == 1 && m.rows[0].weight == "135" && m.rows[0].reps == "10")
    }

    @Test func weekCategoriesUseCustomClassificationAndFollowDeleteUndo() throws {
        let m = try model()
        #expect(m.openDay(day))
        #expect(m.createExercise(named: "Travel raise", group: .shoulders, equipment: .dumbbell))
        try enter(m, weight: "20", reps: "12"); #expect(m.finishEditing())
        let custom = try #require(m.exercise?.id)
        #expect(m.removeExercise(custom))
        #expect(m.summary(for: day).muscleGroups == [.shoulders])
        #expect(m.addExercise("bench"))
        try enter(m, weight: "135", reps: "10"); #expect(m.finishEditing())
        #expect(m.summary(for: day).muscleGroups == [.chest, .shoulders])
        #expect(m.deleteSet(try #require(m.rows.first).id))
        #expect(m.summary(for: day).muscleGroups == [.shoulders])
        #expect(m.undoChange())
        #expect(m.summary(for: day).muscleGroups == [.chest, .shoulders])
        #expect(m.summary(for: day).setCount == 2)
    }

    @Test func completeRowsCountOnlyWhenEditingFinishesAndRemainDaySpecific() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        #expect(m.rows.count == 1 && m.rows[0].weight.isEmpty && m.rows[0].reps.isEmpty)
        try enter(m, weight: "135", reps: "10")
        #expect(m.summary(for: day).setCount == 0)
        #expect(m.finishEditing())
        #expect(m.summary(for: day).setCount == 1)
        let yesterday = try day.adding(days: -1)
        #expect(m.openDay(yesterday))
        #expect(m.rows.isEmpty)
        #expect(m.summary(for: day).setCount == 1)
        #expect(m.summary(for: yesterday).setCount == 0)
    }
    @Test func partialInputRecoversWithoutCreatingPerformedSets() throws {
        let store = MemoryJournalRepository()
        let m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "31.", reps: "8")
        let reopened = try model(store)
        #expect(reopened.rows[0].weight == "31.")
        #expect(reopened.summary(for: day).setCount == 0)
        #expect(reopened.finishEditing())
        #expect(reopened.rows[0].weight == "31.")
        #expect(reopened.journal.batches.isEmpty)
    }
    @Test func bodyweightNeedsRepsOnlyAndRepeatAndDeleteUndoAreTargeted() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("push-up"))
        #expect(m.selectInput(m.rows[0].id, field: .reps))
        m.typeInput("12", focus: try #require(m.focus))
        #expect(m.finishEditing())
        let first = try #require(m.rows[0].performedSetID)
        let action = UUID()
        #expect(m.repeatLastSet(actionID: action))
        #expect(m.repeatLastSet(actionID: action))
        #expect(m.rows.count == 2 && m.summary(for: day).setCount == 2)
        #expect(m.undoChange())
        #expect(m.rows.count == 1 && m.rows[0].performedSetID == first)
        #expect(m.deleteSet(m.rows[0].id))
        #expect(m.summary(for: day).setCount == 0)
        #expect(m.undoChange())
        #expect(m.rows[0].performedSetID == first)
        #expect(m.summary(for: day).setCount == 1)
    }
    @Test func incompleteCorrectionUnrecordsButKeepsInputAndRecompletionIsFresh() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "1", reps: "10"); #expect(m.finishEditing())
        let row = m.rows[0], original = try #require(row.performedSetID)
        #expect(m.selectInput(row.id, field: .weight))
        m.typeInput("", focus: try #require(m.focus))
        #expect(m.finishEditing())
        #expect(m.rows[0].id == row.id && m.rows[0].performedSetID == nil)
        #expect(m.summary(for: day).setCount == 0)
        try enter(m, weight: "2", reps: "10"); #expect(m.finishEditing())
        #expect(m.rows[0].performedSetID != original)
        #expect(m.summary(for: day).setCount == 1)
    }
    @Test func unitSwitchAndEchoPreservePoundsAndOldFocusCallbacksAreIgnored() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "1", reps: "10"); #expect(m.finishEditing())
        #expect(m.changeUnit(.kilograms))
        #expect(m.selectInput(m.rows[0].id, field: .weight))
        let old = try #require(m.focus)
        m.typeInput("0.45", focus: old)
        #expect(m.selectInput(m.rows[0].id, field: .reps))
        m.typeInput("999", focus: old)
        #expect(m.finishEditing())
        #expect(m.journal.batches[0].values[0] == SetValues(weight: 100, reps: 10))
    }
    @Test func referencesUsePreviousDayAndCommittedPersonalBest() throws {
        let m = try model()
        let yesterday = try day.adding(days: -1)
        #expect(m.openDay(yesterday)); #expect(m.addExercise("bench"))
        try enter(m, weight: "135", reps: "10"); #expect(m.finishEditing())
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "200", reps: "5")
        #expect(m.lastReference?.values.weight == 13_500)
        #expect(m.personalBest?.values.weight == 13_500)
        #expect(m.finishEditing())
        #expect(m.personalBest?.values.weight == 20_000)
        #expect(m.lastReference?.values.weight == 13_500)
    }
    @Test func failedCommitDoesNotPublishHistoryAndCanRetry() throws {
        let store = TrainingFailureStore()
        let m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "135", reps: "10")
        store.reject = true
        #expect(!m.finishEditing())
        #expect(m.journal.batches.isEmpty && m.rows[0].weight == "135")
        store.reject = false
        #expect(m.finishEditing())
        #expect(m.summary(for: day).setCount == 1)
    }
    @Test func unitSwitchAfterDeletionKeepsUndoAndExactCanonicalValues() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "1", reps: "10"); #expect(m.finishEditing())
        #expect(m.repeatLastSet())
        #expect(m.deleteSet(m.rows[1].id))
        #expect(m.changeUnit(.kilograms))
        #expect(m.unit == .kilograms)
        #expect(m.undoChange())
        #expect(m.rows.count == 2)
        #expect(m.rows[1].unit == .kilograms)
        #expect(m.rows[1].parsed(for: Exercise.catalog[0])?.weight == 100)
    }
    @Test func unknownLegacyExercisesRemainReachableAndCanDeleteTheirLastSet() throws {
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: "legacy-lift", sets: [SetValues(weight: 100, reps: 8)]), at: day.date(in: calendar))
        let legacy = EntryWorkspace(sessions: ["bench": .draft(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]))])
        let store = try MemoryJournalRepository(snapshot: JournalSnapshot(journal: journal, workspace: legacy))
        let m = try model(store)
        #expect(m.openDay(day))
        #expect(m.tabs.contains { $0.id == "legacy-lift" })
        #expect(m.selectExercise("legacy-lift"))
        #expect(m.deleteSet(try #require(m.rows.first).id))
        #expect(m.summary(for: day).setCount == 0)
        #expect(m.exercises.contains { $0.id == "legacy-lift" })
        let reopened = try model(store)
        #expect(reopened.addExercise("legacy-lift"))
        #expect(reopened.summary(for: day).setCount == 0)
    }

    @Test func undoRestoresDeletedPartialInputInItsOriginalUnit() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "31.", reps: "8"); #expect(m.finishEditing())
        #expect(m.deleteSet(m.rows[0].id))
        #expect(m.changeUnit(.kilograms))
        #expect(m.undoChange())
        #expect(m.rows[0].weight == "31." && m.rows[0].unit == .pounds)
        #expect(m.summary(for: day).setCount == 0)
    }

}
@MainActor private final class TrainingFailureStore: JournalRepository {
    var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ candidate: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try candidate.validated()
    }
}
