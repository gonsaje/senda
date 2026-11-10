import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct HistoryNavigationTests {
    private let oldDay = try! TrainingDay("2026-01-05")
    private let today = try! TrainingDay("2026-11-09")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func model(_ store: any JournalRepository = MemoryJournalRepository()) throws -> TrainingNotebookModel {
        try TrainingNotebookModel(repository: store, calendar: calendar, now: { today.date(in: calendar) })
    }
    @discardableResult private func record(_ model: TrainingNotebookModel, on day: TrainingDay,
                                          exercise: String = "bench", weight: String = "135", reps: String = "10") throws -> UUID {
        #expect(model.openDay(day)); #expect(model.addExercise(exercise))
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .weight)); model.typeInput(weight, focus: try #require(model.focus))
        #expect(model.selectInput(row.id, field: .reps)); model.typeInput(reps, focus: try #require(model.focus))
        #expect(model.finishEditing())
        return try #require(model.rows.first?.performedSetID)
    }
    @Test func personalRecordBrowsingPreservesCurrentWorkoutAndSection() throws {
        let model = try model()
        _ = try record(model, on: oldDay)
        let record = try #require(model.personalRecords.first)
        _ = try self.record(model, on: today, exercise: "squat", weight: "95")
        #expect(model.selectSection(.trends))
        let before = model.snapshot
        #expect(model.openPersonalRecord(record))
        #expect(model.isProgressPresented)
        #expect(model.section == .trends && model.selectedDay == today && model.exercise?.id == "squat")
        #expect(model.snapshot == before)
    }
    @Test func browsingHiddenRecordDoesNotRestoreItsExerciseTab() throws {
        let model = try model()
        _ = try record(model, on: oldDay)
        let record = try #require(model.personalRecords.first)
        #expect(model.removeExercise("bench"))
        let before = model.snapshot
        #expect(model.openPersonalRecord(record))
        #expect(model.isProgressPresented && model.snapshot == before)
        #expect(model.workout?.exerciseIDs.contains("bench") == false)
    }

    @Test func exactOldAndFutureRecordsOpenOutsideChartWindows() throws {
        for day in [oldDay, try today.adding(days: 30)] {
            let model = try model()
            let setID = try record(model, on: day)
            let record = try #require(model.personalRecords.first)
            #expect(model.openToday())
            #expect(model.openPersonalRecord(record))
            #expect(model.progressExerciseID == "bench" && model.progressSessionDay == day && model.progressSetID == setID)
            #expect(model.selectedDay == today)
        }
    }

    @Test func explicitHistoricalEditReturnsToUnfinishedWorkoutAndKeepsCorrection() throws {
        let model = try model()
        let oldSetID = try record(model, on: oldDay)
        #expect(model.removeExercise("bench"))
        #expect(model.openToday()); #expect(model.addExercise("squat"))
        let draft = try #require(model.rows.first)
        #expect(model.selectInput(draft.id, field: .weight)); model.typeInput("31.", focus: try #require(model.focus))
        #expect(model.selectInput(draft.id, field: .reps)); model.typeInput("8", focus: try #require(model.focus))
        #expect(model.openProgress(for: "bench", on: oldDay, highlighting: oldSetID))
        #expect(model.editRecordedSession(for: "bench", on: oldDay, setID: oldSetID))
        #expect(!model.isProgressPresented && model.selectedDay == oldDay && model.exercise?.id == "bench")
        #expect(model.hasHistoryReturnContext && model.revealRowID == model.rows.first?.id)
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .reps)); model.typeInput("12", focus: try #require(model.focus))
        #expect(model.returnToWorkoutFromHistory())
        #expect(model.section == .log && model.selectedDay == today && model.exercise?.id == "squat")
        #expect(model.rows.first?.id == draft.id && model.rows.first?.weight == "31." && model.rows.first?.reps == "8")
        #expect(model.journal.reference(to: oldSetID)?.set.values.reps == 12 && !model.hasHistoryReturnContext)
    }

    @Test func historicalEditReturnsToTheOriginalExerciseOnTheSameDay() throws {
        let model = try model()
        let setID = try record(model, on: today)
        #expect(model.addExercise("squat"))
        #expect(model.editRecordedSession(for: "bench", on: today, setID: setID))
        #expect(model.exercise?.id == "bench")
        #expect(model.returnToWorkoutFromHistory())
        #expect(model.selectedDay == today && model.exercise?.id == "squat")
    }

    @Test func historyEditingCanReturnToAWeekWithoutCreatingAWorkout() throws {
        let model = try model()
        let setID = try record(model, on: oldDay)
        #expect(model.showCurrentWeek())
        let week = model.workspace.visibleWeek, days = Set(model.workspace.days.keys)
        #expect(model.editRecordedSession(for: "bench", on: oldDay, setID: setID))
        #expect(model.returnToWorkoutFromHistory())
        #expect(model.selectedDay == nil && model.workspace.visibleWeek == week)
        #expect(Set(model.workspace.days.keys) == days)
    }

    @Test func failedEditAndReturnRetryWithoutLosingTheOrigin() throws {
        let store = HistoryFailureStore(), model = try model(store)
        let setID = try record(model, on: oldDay)
        #expect(model.openToday()); #expect(model.addExercise("squat"))
        store.reject = true
        #expect(!model.editRecordedSession(for: "bench", on: oldDay, setID: setID))
        #expect(model.selectedDay == today && !model.hasHistoryReturnContext)
        store.reject = false
        #expect(model.retrySave() && model.selectedDay == oldDay && model.hasHistoryReturnContext)
        store.reject = true
        #expect(!model.returnToWorkoutFromHistory())
        #expect(model.selectedDay == oldDay && model.hasHistoryReturnContext)
        store.reject = false
        #expect(model.retrySave() && model.selectedDay == today && !model.hasHistoryReturnContext)
        #expect(model.retrySave() && model.journal.batches.count == 1)
    }

    @Test func newerNavigationSupersedesFailedHistoricalEdit() throws {
        let store = HistoryFailureStore(), model = try model(store)
        let setID = try record(model, on: oldDay)
        #expect(model.openToday())
        store.reject = true
        #expect(!model.editRecordedSession(for: "bench", on: oldDay, setID: setID))
        store.reject = false
        #expect(model.selectSection(.learn)); #expect(model.retrySave())
        #expect(model.section == .learn && model.selectedDay == today && !model.hasHistoryReturnContext)
    }

    @Test(arguments: [false, true]) func dismissingFailedHistoricalEditCancelsItsDestination(bySwiping: Bool) throws {
        let store = HistoryFailureStore(), model = try model(store)
        let setID = try record(model, on: oldDay)
        #expect(model.openToday()); #expect(model.addExercise("squat"))
        #expect(model.openProgress(for: "bench", on: oldDay, highlighting: setID))
        store.reject = true
        #expect(!model.editRecordedSession(for: "bench", on: oldDay, setID: setID))
        if bySwiping { model.isProgressPresented = false }
        else { #expect(model.dismissProgress()) }
        model.progressSheetDidDismiss()
        store.reject = false
        #expect(model.retrySave())
        #expect(model.selectedDay == today && model.exercise?.id == "squat" && !model.hasHistoryReturnContext)
        #expect(!model.isProgressPresented && model.journal.batches.count == 1)
    }

    @Test func browsingAwayFromFailedHistoricalEditCancelsItsDestination() throws {
        let store = HistoryFailureStore(), model = try model(store)
        let setID = try record(model, on: oldDay)
        #expect(model.openToday()); #expect(model.addExercise("squat"))
        #expect(model.openProgress(for: "bench", on: oldDay, highlighting: setID))
        store.reject = true
        #expect(!model.editRecordedSession(for: "bench", on: oldDay, setID: setID))
        model.cancelProgressNavigation()
        model.progressExerciseID = nil
        store.reject = false
        #expect(model.retrySave())
        #expect(model.isProgressPresented && model.progressExerciseID == nil)
        #expect(model.selectedDay == today && !model.hasHistoryReturnContext)
    }

    @Test func restoreClearsHistoryDestinationsAndReturnContext() throws {
        let model = try model()
        let archive = try NotebookBackupCodec.decode(model.backupData())
        let setID = try record(model, on: oldDay)
        #expect(model.openToday())
        #expect(model.editRecordedSession(for: "bench", on: oldDay, setID: setID))
        #expect(model.openProgress(for: "bench", on: oldDay, highlighting: setID))
        #expect(model.restoreBackup(archive))
        #expect(!model.hasHistoryReturnContext && !model.isProgressPresented)
        #expect(model.progressSessionDay == nil && model.progressSetID == nil)
    }
}

@MainActor private final class HistoryFailureStore: JournalRepository {
    private var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated()
    }
}
