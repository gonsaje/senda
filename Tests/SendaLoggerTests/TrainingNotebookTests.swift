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
