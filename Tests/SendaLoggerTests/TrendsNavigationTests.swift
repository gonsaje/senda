import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct TrendsNavigationTests {
    private func enter(_ model: TrainingNotebookModel, weight: String = "135", reps: String = "10") throws {
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .weight)); model.typeInput(weight, focus: try #require(model.focus))
        #expect(model.selectInput(row.id, field: .reps)); model.typeInput(reps, focus: try #require(model.focus))
    }
    @Test func trendsFinishesValidSetAndPreservesWorkoutSelection() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model)
        let day = model.selectedDay, rowID = model.rows.first?.id
        #expect(model.selectSection(.trends))
        #expect(model.section == .trends && model.focus == nil && model.journal.batches.count == 1)
        #expect(model.selectedDay == day && model.exercise?.id == "bench" && model.rows.first?.id == rowID)
        let trends = model.snapshot.trends(through: model.today, calendar: model.calendar, exercises: model.exercises)
        #expect(trends.setCount == 1 && trends.trainingDayCount == 1)
    }
    @Test func unfinishedEntryStaysUnrecordedWhenOpeningTrends() throws {
        let store = MemoryJournalRepository(), model = try TrainingNotebookModel(repository: store)
        try enter(model, weight: "31.", reps: "8")
        #expect(model.selectSection(.trends))
        let trends = model.snapshot.trends(through: model.today)
        #expect(trends.setCount == 0 && model.journal.batches.isEmpty)
        let reopened = try TrainingNotebookModel(repository: store)
        #expect(reopened.rows.first?.weight == "31." && reopened.rows.first?.reps == "8")
    }
    @Test func failedTrendsNavigationRetriesOriginalDestinationExactlyOnce() throws {
        let store = TrendsNavigationFailureStore(), model = try TrainingNotebookModel(repository: store)
        try enter(model)
        let before = model.snapshot
        store.reject = true
        #expect(!model.selectSection(.trends))
        #expect(model.section == .log && model.snapshot == before && model.canRetrySave)
        #expect(!model.retrySave() && model.section == .log)
        store.reject = false
        #expect(model.retrySave() && model.section == .trends && model.journal.batches.count == 1)
        #expect(model.retrySave() && model.journal.batches.count == 1)
    }
    @Test func browsingRangeAndOverviewDoesNotWriteNotebookData() throws {
        let store = TrendsNavigationFailureStore(), model = try TrainingNotebookModel(repository: store)
        try enter(model); #expect(model.selectSection(.trends))
        let before = model.snapshot, writes = store.writes
        model.progressRange = .eightWeeks
        _ = model.snapshot.trends(range: model.progressRange, through: model.today, calendar: model.calendar, exercises: model.exercises)
        #expect(model.snapshot == before && store.writes == writes)
    }
    @Test func historyFromTrendsReturnsWithoutMovingCurrentWorkout() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model); #expect(model.selectSection(.trends))
        let day = model.selectedDay, rowID = model.rows.first?.id
        #expect(model.openProgress(for: "bench")); #expect(model.section == .trends && model.isProgressPresented)
        #expect(model.dismissProgress()); #expect(model.section == .trends && !model.isProgressPresented)
        #expect(model.openProgress(for: "bench")); #expect(model.returnFromProgressToWorkout())
        #expect(model.section == .log && model.selectedDay == day && model.rows.first?.id == rowID && model.exercise?.id == "bench")
    }
    @Test func restoredSnapshotImmediatelyRecomputesTheOverview() throws {
        let source = try TrainingNotebookModel(repository: MemoryJournalRepository())
        let archive = try NotebookBackupCodec.decode(source.backupData())
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model); #expect(model.selectSection(.trends))
        #expect(model.snapshot.trends(through: model.today).setCount == 1)
        #expect(model.restoreBackup(archive))
        #expect(model.section == .trends && model.snapshot.trends(through: model.today).setCount == 0)
    }
    @Test func incompleteCorrectionUsesLastRecordedValueInFeedback() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model); #expect(model.finishEditing())
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .reps)); model.typeInput("", focus: try #require(model.focus))
        #expect(model.selectSection(.trends))
        let trends = model.snapshot.trends(through: model.today, exercises: model.exercises)
        #expect(trends.exerciseSummaries.first?.latestSession.bestSet.values == SetValues(weight: 13500, reps: 10))
        #expect(model.rows.first?.pendingCorrection == true && trends.setCount == 1)
    }
}
@MainActor private final class TrendsNavigationFailureStore: JournalRepository {
    private var snapshot = JournalSnapshot()
    var reject = false, writes = 0
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated(); writes += 1
    }
}
