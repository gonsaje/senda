import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct PremiumLoggingTests {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private var day: TrainingDay { try! TrainingDay("2026-11-07") }
    private func model(_ store: any JournalRepository) throws -> TrainingNotebookModel {
        try TrainingNotebookModel(repository: store, calendar: calendar, now: { self.day.date(in: self.calendar) })
    }
    private func start(_ m: TrainingNotebookModel, exercise: String = "bench", weight: String = "135", reps: String = "10") throws {
        #expect(m.openDay(day)); #expect(m.addExercise(exercise))
        let row = try #require(m.rows.first)
        #expect(m.selectInput(row.id, field: .weight)); m.typeInput(weight, focus: try #require(m.focus))
        #expect(m.selectInput(row.id, field: .reps)); m.typeInput(reps, focus: try #require(m.focus))
    }
    @Test func incompleteCorrectionKeepsPerformedIdentityAndValuesAcrossNavigationAndRelaunch() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        try start(m); #expect(m.finishEditing())
        let original = try #require(m.rows.first), setID = try #require(original.performedSetID)
        #expect(m.selectInput(original.id, field: .weight)); m.typeInput("31.", focus: try #require(m.focus))
        #expect(m.showWeek())
        #expect(m.summary(for: day).setCount == 1)
        #expect(m.journal.reference(to: setID)?.set.values == SetValues(weight: 13_500, reps: 10))
        let reopened = try model(store)
        #expect(reopened.openDay(day))
        let draft = try #require(reopened.rows.first)
        #expect(draft.id == original.id && draft.actionID == original.actionID && draft.performedSetID == setID)
        #expect(draft.weight == "31." && reopened.focus == nil)
        #expect(reopened.selectInput(draft.id, field: .weight)); reopened.typeInput("140", focus: try #require(reopened.focus))
        #expect(reopened.finishEditing())
        #expect(reopened.rows[0].performedSetID == setID)
        #expect(reopened.journal.reference(to: setID)?.set.values == SetValues(weight: 14_000, reps: 10))
        #expect(reopened.journal.batches.count == 1)
    }
    @Test func backgroundRecoveryReplaysFailedDayDestinationAndRecordsExactlyOnce() throws {
        let store = PremiumFailureStore(), m = try model(store)
        try start(m)
        store.reject = true
        #expect(!m.changeDay(1))
        let attempts = store.attempts
        #expect(!m.flushRecovery())
        #expect(store.attempts == attempts + 1)
        #expect(m.selectedDay == day && m.journal.batches.count == 1)
        #expect(m.recordedValues(for: m.rows[0]) == SetValues(weight: 13_500, reps: 10))
        store.reject = false
        #expect(m.flushRecovery())
        #expect(m.selectedDay?.rawValue == "2026-11-08")
        #expect(m.summary(for: day).setCount == 1 && m.focus == nil)
        #expect(m.flushRecovery())
        #expect(m.journal.batches.count == 1)
    }
    @Test func backgroundRecoveryReplaysFailedSectionDestination() throws {
        let store = PremiumFailureStore(), m = try model(store)
        try start(m)
        store.reject = true
        #expect(!m.selectSection(.profile))
        store.reject = false
        #expect(m.flushRecovery())
        #expect(m.section == .profile && m.focus == nil)
        #expect(m.summary(for: day).setCount == 1)
    }
    @Test func rowStatesDistinguishBlankZeroPartialAndPendingCorrection() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        #expect(m.rowStatus(for: m.rows[0]) == .empty)
        #expect(m.unfinishedSetCount(for: day) == 0)
        #expect(m.selectInput(m.rows[0].id, field: .weight)); m.typeInput("0", focus: try #require(m.focus))
        #expect(m.rowStatus(for: m.rows[0]) == .unfinished)
        #expect(m.unfinishedSetCount(for: day) == 1)
        #expect(m.selectInput(m.rows[0].id, field: .reps)); m.typeInput("10", focus: try #require(m.focus))
        #expect(m.rowStatus(for: m.rows[0]) == .recorded)
        #expect(m.unfinishedSetCount(for: day) == 0 && m.summary(for: day).setCount == 1)
        #expect(m.finishEditing())
        #expect(m.rowStatus(for: m.rows[0]) == .recorded)
        #expect(m.recordedValues(for: m.rows[0]) == SetValues(weight: 0, reps: 10))
        #expect(m.selectInput(m.rows[0].id, field: .weight)); m.typeInput("31.", focus: try #require(m.focus))
        #expect(m.rowStatus(for: m.rows[0]) == .pendingCorrection)
        #expect(m.finishEditing())
        #expect(m.unfinishedSetCount(for: day) == 1)
        #expect(m.summary(for: day).setCount == 1)
    }
    @Test func discardRestoresSavedValuesAndIdentityAfterRelaunchAndUnitConversion() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        try start(m, weight: "1"); #expect(m.finishEditing())
        let original = m.rows[0]
        #expect(m.selectInput(original.id, field: .reps)); m.typeInput("", focus: try #require(m.focus))
        #expect(m.finishEditing()); #expect(m.changeUnit(.kilograms))
        let reopened = try model(store)
        #expect(reopened.rowStatus(for: reopened.rows[0]) == .pendingCorrection)
        #expect(reopened.discardCorrection(original.id))
        #expect(reopened.rows[0].id == original.id && reopened.rows[0].actionID == original.actionID)
        #expect(reopened.rows[0].performedSetID == original.performedSetID)
        #expect(reopened.rows[0].weight == "0.45" && reopened.rows[0].reps == "10")
        #expect(reopened.rows[0].canonicalWeight == 100 && reopened.focus == nil)
        #expect(reopened.rowStatus(for: reopened.rows[0]) == .recorded)
        #expect(try model(store).rows[0] == reopened.rows[0])
    }
    @Test func pendingCorrectionDeleteUndoRetainsDraftAndPerformedIdentity() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        try start(m); #expect(m.finishEditing())
        let original = m.rows[0]
        #expect(m.selectInput(original.id, field: .weight)); m.typeInput("31.", focus: try #require(m.focus))
        #expect(m.deleteSet(original.id))
        #expect(m.summary(for: day).setCount == 0 && m.rows.isEmpty)
        #expect(m.changeUnit(.kilograms)); #expect(m.undoChange())
        #expect(m.unit == .pounds && m.rows[0].weight == "31.")
        #expect(m.rows[0].performedSetID == original.performedSetID)
        #expect(m.rowStatus(for: m.rows[0]) == .pendingCorrection)
        #expect(m.summary(for: day).setCount == 1)
        #expect(try model(store).rows[0] == m.rows[0])
    }
    @Test func bodyweightCorrectionKeepsHistoryAndExplicitZeroSavesWhileEditing() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        try start(m, exercise: "push-up", weight: "", reps: "12"); #expect(m.finishEditing())
        let original = m.rows[0]
        #expect(m.recordedValues(for: original) == SetValues(weight: 0, reps: 12))
        #expect(m.selectInput(original.id, field: .reps)); m.typeInput("", focus: try #require(m.focus))
        #expect(m.addExercise("bench"))
        #expect(m.unfinishedSetCount(for: day) == 1 && m.summary(for: day).setCount == 1)
        #expect(m.selectExercise("push-up")); #expect(m.discardCorrection(original.id))
        #expect(m.rows[0].weight.isEmpty && m.rows[0].reps == "12")
        #expect(m.selectInput(original.id, field: .weight)); m.typeInput("0", focus: try #require(m.focus))
        #expect(m.rowStatus(for: m.rows[0]) == .recorded && m.focus != nil)
        #expect(m.finishEditing())
        #expect(m.rows[0].performedSetID == original.performedSetID)
        #expect(m.recordedValues(for: m.rows[0]) == SetValues(weight: 0, reps: 12))
    }
    @Test func retryDoneKeepsSavedSetWhileStorageFailsAndThenClosesEditing() throws {
        let store = PremiumFailureStore(), m = try model(store)
        try start(m)
        let original = m.rows[0], saved = try store.loadSnapshot()
        store.reject = true
        #expect(!m.finishEditing() && m.canRetrySave)
        let attempts = store.attempts
        #expect(!m.retrySave() && m.canRetrySave)
        #expect(store.attempts == attempts + 1 && m.journal.batches.count == 1)
        #expect(m.rows[0] == original && m.focus != nil)
        #expect(try store.loadSnapshot() == saved)
        store.reject = false
        #expect(m.retrySave() && !m.canRetrySave)
        let snapshot = m.snapshot
        #expect(m.retrySave())
        #expect(m.snapshot == snapshot && m.summary(for: day).setCount == 1)
        #expect(m.rows[0].performedSetID == original.performedSetID && m.focus == nil)
        #expect(try model(store).summary(for: day).setCount == 1)
    }
    @Test func newInputSupersedesFailedDestinationEvenWhenItsOwnWriteFails() throws {
        let store = PremiumFailureStore(), m = try model(store)
        try start(m); store.reject = true
        #expect(!m.changeDay(1))
        m.typeInput("11", focus: try #require(m.focus))
        #expect(m.rows[0].reps == "11" && m.canRetrySave)
        store.reject = false
        #expect(m.retrySave())
        #expect(m.selectedDay == day && m.rows[0].reps == "11" && m.focus != nil)
        #expect(m.journal.batches.count == 1)
        #expect(m.recordedValues(for: m.rows[0]) == SetValues(weight: 13_500, reps: 11))
        #expect(m.finishEditing())
        #expect(m.recordedValues(for: m.rows[0]) == SetValues(weight: 13_500, reps: 11))
    }
    @Test func failedRecordRetryShowsTheOriginalSetWithoutMovingTheWorkout() throws {
        let store = PremiumFailureStore(), m = try model(store)
        try start(m); #expect(m.finishEditing())
        let record = try #require(m.personalRecords.first)
        #expect(m.changeDay(1)); #expect(m.addExercise("squat"))
        let currentDay = m.selectedDay
        #expect(m.selectInput(m.rows[0].id, field: .weight))
        m.typeInput("31.", focus: try #require(m.focus))
        store.reject = true
        #expect(!m.openPersonalRecord(record))
        #expect(!m.isProgressPresented && m.revealRowID == nil)
        store.reject = false
        #expect(m.retrySave())
        #expect(m.isProgressPresented && m.selectedDay == currentDay && m.exercise?.id == "squat")
        #expect(m.progressSessionDay == day && m.progressSetID == record.reference.setID)
        #expect(!m.canRetryProfileAction && m.journal.batches.count == 1)
    }
    @Test func failedRepeatRetryKeepsActionIdentityAndUndoRemovesOnlyTheRepeat() throws {
        let store = PremiumFailureStore(), m = try model(store)
        try start(m); #expect(m.finishEditing())
        let original = m.rows[0], action = UUID()
        store.reject = true; #expect(!m.repeatLastSet(actionID: action))
        store.reject = false; #expect(m.retrySave()); #expect(m.retrySave())
        #expect(m.repeatLastSet(actionID: action))
        #expect(m.rows.count == 2 && m.rows[1].actionID == action)
        #expect(m.undoChange())
        #expect(m.rows == [original] && m.summary(for: day).setCount == 1)
    }
    @Test func openTodayPreservesPreviousDayDraftWithoutCreatingHistory() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        let yesterday = try TrainingDay("2026-11-06")
        #expect(m.openDay(yesterday)); #expect(m.addExercise("bench"))
        let original = m.rows[0]
        #expect(m.selectInput(original.id, field: .weight)); m.typeInput("31.", focus: try #require(m.focus))
        #expect(m.openToday())
        #expect(m.selectedDay == day && m.rows.isEmpty && m.focus == nil)
        #expect(m.unfinishedSetCount(for: yesterday) == 1 && m.journal.batches.isEmpty)
        let reopened = try model(store)
        #expect(reopened.openDay(yesterday))
        #expect(reopened.rows[0].id == original.id && reopened.rows[0].weight == "31.")
        #expect(reopened.journal.batches.isEmpty)
    }
    @Test func restoredPreviousDayAndRolloverKeepDraftOnItsOriginalDate() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        try start(m, weight: "31.")
        let next = try TrainingDay("2026-11-08")
        let reopened = try TrainingNotebookModel(repository: store, calendar: calendar, now: { next.date(in: self.calendar) })
        #expect(reopened.today == next && reopened.selectedDay == day)
        #expect(reopened.rows[0].weight == "31.")
        #expect(reopened.openToday())
        #expect(reopened.selectedDay == next && reopened.unfinishedSetCount(for: day) == 1)
        #expect(reopened.summary(for: next).setCount == 0 && reopened.journal.batches.isEmpty)
    }

    @Test func backgroundSuspensionDoesNotReplaceAFailedSectionAction() throws {
        let store = PremiumFailureStore(), session = TrainingSession(repository: store)
        let m = try #require(session.notebook)
        try start(m)
        store.reject = true
        #expect(!m.selectSection(.learn))
        session.suspend()
        #expect(m.section == .log && m.focus != nil && m.canRetrySave)
        store.reject = false
        session.suspend()
        #expect(m.section == .learn && m.focus == nil && !m.canRetrySave)
        #expect(m.summary(for: day).setCount == 1)
    }

    @Test func failedDestinationDoesNotRetainItsClosedNotebook() throws {
        let store = PremiumFailureStore()
        weak var released: TrainingNotebookModel?
        do {
            let m = try model(store)
            try start(m)
            store.reject = true
            #expect(!m.selectSection(.profile))
            released = m
        }
        #expect(released == nil)
    }

    @Test func backgroundSuspensionRetriesUnsavedInputThenFinishesTheCompleteSet() throws {
        let store = PremiumFailureStore(), session = TrainingSession(repository: store)
        let m = try #require(session.notebook)
        try start(m)
        store.reject = true
        m.typeInput("11", focus: try #require(m.focus))
        #expect(m.canRetrySave && m.journal.batches.count == 1)
        #expect(m.rows[0].reps == "11")
        #expect(m.recordedValues(for: m.rows[0]) == SetValues(weight: 13_500, reps: 10))
        #expect(try store.loadSnapshot().journal == m.journal)
        store.reject = false
        session.suspend()
        #expect(m.focus == nil && !m.canRetrySave)
        #expect(m.summary(for: day).setCount == 1)
        #expect(m.journal.batches.first?.values == [SetValues(weight: 13_500, reps: 11)])
    }
    @Test func completingAHistoricalCorrectionPreservesItsOriginalRecordedDate() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        try start(m); #expect(m.finishEditing())
        let row = m.rows[0], setID = try #require(row.performedSetID)
        #expect(m.selectInput(row.id, field: .weight)); m.typeInput("31.", focus: try #require(m.focus))
        #expect(m.showWeek())
        let next = try TrainingDay("2026-11-08")
        let reopened = try TrainingNotebookModel(repository: store, calendar: calendar, now: { next.date(in: self.calendar) })
        #expect(reopened.openDay(day)); #expect(reopened.selectInput(row.id, field: .weight))
        reopened.typeInput("140", focus: try #require(reopened.focus)); #expect(reopened.finishEditing())
        #expect(reopened.journal.reference(to: setID)?.batch.recordedAt == day.date(in: calendar))
        #expect(reopened.summary(for: day).setCount == 1 && reopened.summary(for: next).setCount == 0)
    }

}

@MainActor private final class PremiumFailureStore: JournalRepository {
    var snapshot = JournalSnapshot()
    var reject = false
    var attempts = 0
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        attempts += 1
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated()
    }
}
