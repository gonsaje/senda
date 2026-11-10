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
    @Test func weightSelectionDefaultsToDialWhileRepsRequestKeyboard() throws {
        let store = MemoryJournalRepository()
        let m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        let row = try #require(m.rows.first)
        #expect(m.selectInput(row.id, field: .weight))
        #expect(try #require(m.focus).keyboard == false)
        let reopened = try model(store)
        #expect(try #require(reopened.focus).keyboard == false)
        #expect(reopened.journal.batches.isEmpty)
        #expect(m.selectInput(row.id, field: .reps))
        #expect(try #require(m.focus).keyboard == true)
    }

    @Test func newWeightedSetsStartWithDialAndBodyweightSetsOpenRepsKeyboard() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        #expect(m.newSet())
        #expect(m.focus?.field == .weight)
        #expect(try #require(m.focus).keyboard == false)
        #expect(m.addExercise("push-up")); #expect(m.newSet())
        #expect(m.focus?.field == .reps)
        #expect(try #require(m.focus).keyboard == true)
        #expect(m.summary(for: day).setCount == 0)
    }

    @Test func dayNavigationSavesSourceEditsAndRestoresEachDaysWorkout() throws {
        let store = MemoryJournalRepository()
        let m = try model(store)
        let sunday = try TrainingDay("2026-11-08")
        #expect(m.openDay(sunday)); #expect(m.addExercise("bench"))
        try enter(m, weight: "135", reps: "10")
        let benchRow = try #require(m.rows.first).id
        #expect(m.changeDay(1))
        #expect(m.selectedDay?.rawValue == "2026-11-09")
        #expect(m.workspace.visibleWeek.rawValue == "2026-11-09")
        #expect(m.tabs.isEmpty && m.rows.isEmpty && m.focus == nil)
        #expect(m.summary(for: sunday).setCount == 1)
        #expect(m.addExercise("overhead-press"))
        try enter(m, weight: "95", reps: "8")
        #expect(m.changeDay(-1))
        #expect(m.selectedDay == sunday)
        #expect(m.workspace.visibleWeek.rawValue == "2026-11-02")
        #expect(m.exercise?.id == "bench")
        #expect(m.rows.count == 1 && m.rows[0].id == benchRow)
        #expect(m.rows[0].weight == "135" && m.rows[0].reps == "10")
        #expect(m.changeDay(1))
        let reopened = try model(store)
        #expect(reopened.selectedDay?.rawValue == "2026-11-09")
        #expect(reopened.exercise?.id == "overhead-press")
        #expect(reopened.rows[0].weight == "95" && reopened.rows[0].reps == "8")
        #expect(reopened.summary(for: sunday).setCount == 1)
        #expect(reopened.summary(for: try TrainingDay("2026-11-09")).setCount == 1)
        #expect(reopened.showWeek())
        #expect(reopened.workspace.visibleWeek.rawValue == "2026-11-09")
    }

    @Test func dayNavigationKeepsPartialInputOutOfProgressAcrossReopening() throws {
        let store = MemoryJournalRepository()
        let m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "31.", reps: "8")
        let row = try #require(m.rows.first).id
        #expect(m.changeDay(1))
        #expect(m.selectedDay?.rawValue == "2026-11-08")
        let reopened = try model(store)
        #expect(reopened.rows.isEmpty)
        #expect(reopened.changeDay(-1))
        #expect(reopened.rows[0].id == row)
        #expect(reopened.rows[0].weight == "31." && reopened.rows[0].reps == "8")
        #expect(reopened.rows[0].performedSetID == nil)
        #expect(reopened.summary(for: day).setCount == 0)
        #expect(reopened.journal.batches.isEmpty)
    }

    @Test func failedDayNavigationKeepsEditingContextAndRetriesWithoutDuplicateSets() throws {
        let store = TrainingFailureStore()
        let m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "135", reps: "10")
        let before = m.snapshot, saved = try store.loadSnapshot()
        store.reject = true
        #expect(!m.changeDay(1))
        #expect(m.snapshot == before)
        #expect(try store.loadSnapshot() == saved)
        #expect(m.focus != nil && m.errorMessage != nil)
        store.reject = false
        #expect(m.changeDay(1))
        #expect(m.selectedDay?.rawValue == "2026-11-08")
        #expect(m.changeDay(-1))
        #expect(m.summary(for: day).setCount == 1)
        #expect(m.rows.count == 1 && m.rows[0].performedSetID != nil)
        #expect(m.focus == nil && m.errorMessage == nil)
    }

    @Test func exerciseListCountsArePerformedExerciseAndDaySpecific() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "135", reps: "10")
        #expect(m.loggedSetCount(for: "bench", on: day) == 1)
        #expect(m.focus?.field == .reps)
        #expect(m.finishEditing())
        #expect(m.newSet())
        #expect(m.loggedSetCount(for: "bench", on: day) == 1)
        #expect(m.addExercise("cable-row"))
        #expect(m.loggedSetCount(for: "cable-row", on: day) == 0)
        try enter(m, weight: "50", reps: "12"); #expect(m.finishEditing())
        let previous = try day.adding(days: -1)
        #expect(m.openDay(previous)); #expect(m.addExercise("bench"))
        try enter(m, weight: "145", reps: "8"); #expect(m.finishEditing())
        #expect(m.repeatLastSet())
        #expect(m.loggedSetCount(for: "bench", on: previous) == 2)
        #expect(m.loggedSetCount(for: "bench", on: day) == 1)
        #expect(m.loggedSetCount(for: "cable-row", on: day) == 1)
        #expect(m.loggedSetCount(for: "cable-row", on: previous) == 0)
        #expect(m.loggedSetCount(for: "unknown", on: day) == 0)
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

    @Test func completeRowsCountImmediatelyWhileEditingAndRemainDaySpecific() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        #expect(m.rows.count == 1 && m.rows[0].weight.isEmpty && m.rows[0].reps.isEmpty)
        try enter(m, weight: "135", reps: "10")
        #expect(m.summary(for: day).setCount == 1)
        let row = try #require(m.rows.first), focus = try #require(m.focus)
        #expect(row.performedSetID != nil && m.rowStatus(for: row) == .recorded)
        #expect(focus.rowID == row.id && focus.field == .reps)
        #expect(m.finishEditing())
        #expect(m.rows[0].performedSetID == row.performedSetID && m.focus == nil)
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
    @Test func incompleteCorrectionKeepsHistoryAndRecompletionKeepsIdentity() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "1", reps: "10"); #expect(m.finishEditing())
        let row = m.rows[0], original = try #require(row.performedSetID)
        #expect(m.selectInput(row.id, field: .weight))
        m.typeInput("", focus: try #require(m.focus))
        #expect(m.finishEditing())
        #expect(m.rows[0].id == row.id && m.rows[0].performedSetID == original)
        #expect(m.summary(for: day).setCount == 1)
        #expect(m.journal.reference(to: original)?.set.values == SetValues(weight: 100, reps: 10))
        try enter(m, weight: "2", reps: "10"); #expect(m.finishEditing())
        #expect(m.rows[0].performedSetID == original)
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
        #expect(m.personalBest?.values.weight == 20_000)
        #expect(m.focus?.field == .reps)
        #expect(m.finishEditing())
        #expect(m.personalBest?.values.weight == 20_000)
        #expect(m.lastReference?.values.weight == 13_500)
    }
    @Test func failedEditingClosureKeepsAutomaticallySavedHistoryAndCanRetry() throws {
        let store = TrainingFailureStore()
        let m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "135", reps: "10")
        let row = try #require(m.rows.first), saved = try store.loadSnapshot()
        #expect(m.summary(for: day).setCount == 1 && row.performedSetID != nil)
        store.reject = true
        #expect(!m.finishEditing())
        #expect(m.journal == saved.journal && m.rows[0] == row && m.focus != nil)
        #expect(try store.loadSnapshot() == saved)
        store.reject = false
        #expect(m.finishEditing())
        #expect(m.summary(for: day).setCount == 1)
        #expect(m.rows[0].performedSetID == row.performedSetID && m.focus == nil)
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
