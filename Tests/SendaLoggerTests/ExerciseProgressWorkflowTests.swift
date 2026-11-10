import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct ExerciseProgressWorkflowTests {
    private func enter(_ model: TrainingNotebookModel, weight: String = "135", reps: String = "10") throws {
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .weight)); model.typeInput(weight, focus: try #require(model.focus))
        #expect(model.selectInput(row.id, field: .reps)); model.typeInput(reps, focus: try #require(model.focus))
    }
    @Test func progressOpensOverAutomaticallySavedWorkoutWithoutDuplicatingSets() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model)
        let day = model.selectedDay, rowID = model.rows.first?.id, setID = model.rows.first?.performedSetID
        #expect(model.journal.batches.count == 1 && setID != nil && model.focus != nil)
        #expect(model.openProgress(for: "bench"))
        #expect(model.isProgressPresented && model.progressExerciseID == "bench")
        #expect(model.selectedDay == day && model.exercise?.id == "bench" && model.rows.first?.id == rowID)
        #expect(model.journal.batches.count == 1 && model.focus == nil)
        #expect(model.rows.first?.performedSetID == setID)
        #expect(model.dismissProgress())
        #expect(!model.isProgressPresented && model.journal.batches.count == 1)
    }
    @Test func browsingAndClosingHistoryPreservesUnfinishedWorkoutWithoutWrites() throws {
        let store = ProgressFailureRepository()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model, weight: "31.", reps: "8")
        #expect(model.openProgress(for: "bench"))
        let snapshot = model.snapshot, writes = store.writeCount
        model.progressRange = .eightWeeks
        model.progressExerciseID = "push-up"
        _ = model.snapshot.progress(for: model.exercise("bench"), range: model.progressRange, through: model.today, calendar: model.calendar)
        #expect(model.dismissProgress())
        #expect(model.snapshot == snapshot && store.writeCount == writes)
        #expect(model.rows.first?.weight == "31." && model.rows.first?.reps == "8" && model.journal.batches.isEmpty)
    }
    @Test func profileProgressReturnsToTheSameWorkout() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model); #expect(model.selectSection(.profile))
        let day = model.selectedDay, rowID = model.rows.first?.id
        #expect(model.openProgress())
        #expect(model.progressExerciseID == nil && model.section == .profile)
        #expect(model.returnFromProgressToWorkout())
        #expect(model.section == .log && !model.isProgressPresented)
        #expect(model.selectedDay == day && model.exercise?.id == "bench" && model.rows.first?.id == rowID)
    }
    @Test func failedProgressOpenRetainsContextAndRetryOpensExactlyOnce() throws {
        let store = ProgressFailureRepository()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model)
        let before = model.snapshot
        store.reject = true
        #expect(!model.openProgress(for: "bench"))
        #expect(!model.isProgressPresented && model.canRetryProgressAction && model.snapshot == before)
        #expect(!model.retrySave() && !model.isProgressPresented)
        store.reject = false
        #expect(model.retrySave() && model.isProgressPresented && model.journal.batches.count == 1)
        #expect(model.retrySave() && model.journal.batches.count == 1)
    }
    @Test func canceledFailedOpenCannotReappearDuringLaterRetry() throws {
        let store = ProgressFailureRepository()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model)
        let saved = try store.loadSnapshot(), row = try #require(model.rows.first)
        store.reject = true
        #expect(!model.openProgress(for: "bench"))
        #expect(model.dismissProgress())
        store.reject = false
        #expect(model.retrySave())
        #expect(!model.isProgressPresented && !model.canRetryProgressAction && model.journal.batches.count == 1)
        #expect(model.snapshot == saved && model.rows == [row] && model.focus != nil)
        #expect(try store.loadSnapshot() == saved)
    }
    @Test func newerNavigationSupersedesFailedProgressOpen() throws {
        let store = ProgressFailureRepository()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model); store.reject = true
        #expect(!model.openProgress(for: "bench"))
        store.reject = false
        #expect(model.selectSection(.learn)); #expect(model.retrySave())
        #expect(model.section == .learn && !model.isProgressPresented && !model.canRetryProgressAction)
    }
    @Test func restoreClosesOldProgressAndResetsItsSelection() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        let archive = try NotebookBackupCodec.decode(model.backupData())
        #expect(model.openProgress(for: "bench")); model.progressRange = .eightWeeks
        #expect(model.restoreBackup(archive))
        #expect(!model.isProgressPresented && model.progressExerciseID == nil && model.progressRange == .twelveWeeks)
    }
    @Test func unknownExerciseCannotOpenAMisleadingProgressDetail() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        let before = model.snapshot
        #expect(!model.openProgress(for: "not-an-exercise"))
        #expect(!model.isProgressPresented && model.snapshot == before && model.errorMessage != nil)
    }
}
@MainActor private final class ProgressFailureRepository: JournalRepository {
    private var snapshot = JournalSnapshot()
    var reject = false, writeCount = 0
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated(); writeCount += 1
    }
}
