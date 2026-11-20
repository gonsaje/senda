import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct SupersetTests {
    let day = try! TrainingDay("2026-11-19")
    let plan = SupersetPlan(first: "bench", second: "cable-row", rounds: 2, restSeconds: 60)

    private func prepare(_ m: TrainingNotebookModel) throws -> UUID {
        try #require(m.openDay(day))
        try #require(m.addExercises(["cable-row", "goblet-squat", "bench"]))
        try #require(m.createSuperset(plan))
        #expect(m.workout?.exerciseIDs == ["bench", "cable-row", "goblet-squat"])
        return try #require(m.supersets.first?.id)
    }

    private func enterTurn(_ m: TrainingNotebookModel, _ groupID: UUID) throws {
        let row = try #require(m.supersets.first?.currentRowID)
        try #require(m.selectInput(row, field: .weight))
        m.typeInput("100", focus: try #require(m.focus))
        try #require(m.selectInput(row, field: .reps))
        m.typeInput("8", focus: try #require(m.focus))
        try #require(m.canAdvanceSuperset(groupID))
    }

    private func logTurn(_ m: TrainingNotebookModel, _ groupID: UUID) throws {
        try enterTurn(m, groupID)
        try #require(m.advanceSuperset(groupID))
    }

    @Test func pairingRestAndRelaunchPreserveRealSetsAndWaitForManualAdvance() throws {
        let store = MemoryJournalRepository()
        var clock = day.date()
        let m = try TrainingNotebookModel(repository: store, now: {clock})
        let id = try prepare(m)
        #expect(!m.createSuperset(plan))
        try #require(m.startSuperset(id))
        #expect(m.exercise?.id == "bench" && !m.canAdvanceSuperset(id))
        #expect(m.revealRowID == m.supersets.first?.currentRowID)
        try logTurn(m, id)
        #expect(m.exercise?.id == "cable-row" && m.supersets.first?.round == 1)
        try #require(m.selectExercise("bench"))
        #expect(!m.advanceSuperset(id))
        try #require(m.startSuperset(id))
        try logTurn(m, id)
        #expect(m.supersets.first?.phase == .resting && m.supersets.first?.round == 1)
        #expect(m.revealRowID == nil)
        #expect(m.summary(for: day).setCount == 2)
        clock = clock.addingTimeInterval(12)
        #expect(m.setSupersetTimer(.pause, for: id))
        let resumed = try TrainingNotebookModel(repository: store, now: {clock})
        clock = clock.addingTimeInterval(120)
        #expect(resumed.supersets.first?.timer?.remaining(at: clock) == 48)
        #expect(resumed.setSupersetTimer(.adjust(-15), for: id))
        #expect(resumed.setSupersetTimer(.resume, for: id))
        clock = clock.addingTimeInterval(90)
        #expect(resumed.supersets.first?.timer?.remaining(at: clock) == 0)
        #expect(resumed.supersets.first?.phase == .resting && !resumed.canAdvanceSuperset(id))
        try #require(resumed.startNextSupersetRound(id))
        #expect(resumed.supersets.first?.round == 2 && resumed.supersets.first?.timer == nil)
        try logTurn(resumed, id)
        try logTurn(resumed, id)
        #expect(resumed.supersets.first?.phase == .finished)
        #expect(resumed.summary(for: day).setCount == 4)
        #expect(resumed.workout?.rows["bench"]?.count == 2 && resumed.workout?.rows["cable-row"]?.count == 2)
        #expect(resumed.unlinkSuperset(id) && resumed.supersets.isEmpty)
        #expect(resumed.summary(for: day).setCount == 4)
    }

    @Test func replacingADeletedOrReclassifiedTurnNeverCountsAnOlderSet() throws {
        let m = try TrainingNotebookModel(repository: MemoryJournalRepository())
        let id = try prepare(m)
        try #require(m.startSuperset(id))
        let warmup = try #require(m.supersets.first?.currentRowID)
        try #require(m.setKind(.warmup, for: warmup))
        let replacement = try #require(m.supersets.first?.currentRowID)
        #expect(replacement != warmup && !m.canAdvanceSuperset(id))
        try #require(m.deleteSet(replacement))
        #expect(m.supersets.first?.currentRowID != replacement)
        try logTurn(m, id)
        let confirmed = try #require(m.workout?.rows["bench"]?.last?.id)
        try logTurn(m, id)
        try #require(m.selectExercise("bench"))
        try #require(m.deleteSet(confirmed))
        #expect(m.supersets.first?.phase == .working && m.supersets.first?.round == 1)
        #expect(m.supersets.first?.currentExerciseID == "bench" && m.supersets.first?.timer == nil)
        try logTurn(m, id)
        // The unaffected A2 still points at the previously logged row.
        #expect(m.canAdvanceSuperset(id))
        try #require(m.advanceSuperset(id))
        #expect(m.summary(for: day).setCount == 2)
    }

    @Test func savedTemplatesAndReusedDaysCopyStructureWithAFreshTimerAndNoCompletedSets() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("senda-superset-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileJournalRepository(url: url), m = try TrainingNotebookModel(repository: store)
        let groupID = try prepare(m)
        try #require(m.startSuperset(groupID))
        try logTurn(m, groupID)
        try logTurn(m, groupID)
        let template = WorkoutTemplate(name: "Press and pull", exerciseIDs: plan.exerciseIDs, supersets: [plan])
        try #require(m.saveWorkout(template))
        let source = m.workout
        let archive = try NotebookBackupCodec.decode(m.backupData())
        #expect(archive.snapshot.training?.days[day.rawValue] == source)
        #expect(archive.snapshot.training?.workoutTemplates?.first?.supersets == [plan])
        let next = try day.adding(days: 2)
        try #require(m.applyWorkout(template, on: next))
        #expect(m.supersets.first?.phase == .ready && m.supersets.first?.id != groupID && m.supersets.first?.timer == nil)
        #expect(m.summary(for: next).setCount == 0 && m.workout?.exerciseIDs == plan.exerciseIDs)
        let newGroupID = m.supersets.first?.id
        try #require(m.applyWorkout(template, on: next))
        #expect(m.supersets.count == 1 && m.supersets.first?.id == newGroupID)
        let third = try next.adding(days: 2)
        try #require(m.reuseWorkout(from: day, on: third))
        let reopened = try TrainingNotebookModel(repository: store)
        #expect(reopened.workspace.days[day.rawValue] == source)
        #expect(reopened.savedWorkouts.first?.supersets == [plan] && reopened.supersets.first?.plan == plan)
        #expect(reopened.supersets.first?.phase == .ready && reopened.summary(for: third).setCount == 0)
    }

    @Test func splitGroupReorderIsRejectedAndValidGroupMovePersists() throws {
        let m = try TrainingNotebookModel(repository: MemoryJournalRepository())
        let id = try prepare(m)
        #expect(!m.setExerciseOrder(["bench", "goblet-squat", "cable-row"], on: day))
        #expect(m.setExerciseOrder(["goblet-squat", "bench", "cable-row"], on: day))
        #expect(m.supersets.first?.id == id && m.supersets.first?.plan == plan)
    }

    @Test func deletingOneExerciseUnpairsItAndUndoRestoresThePairAndRows() throws {
        let m = try TrainingNotebookModel(repository: MemoryJournalRepository())
        let id = try prepare(m)
        try #require(m.startSuperset(id))
        try logTurn(m, id)
        let original = m.workout
        #expect(m.deleteFromWorkout(.exercise("bench"), on: day))
        #expect(m.supersets.isEmpty)
        #expect(m.undoChange() && m.workout == original)
        #expect(m.removeExercise("cable-row") && m.supersets.isEmpty)
        #expect(m.summary(for: day).setCount == 1)
    }

    @Test func undoingDeletionOfAConfirmedSetRestoresTheRoundItsTimerAndTheOriginalRows() throws {
        let store = MemoryJournalRepository()
        let m = try TrainingNotebookModel(repository: store)
        let id = try prepare(m)
        try #require(m.startSuperset(id))
        try logTurn(m, id)
        try logTurn(m, id)
        try #require(m.selectExercise("bench"))
        let before = m.workout
        let row = try #require(m.rows.first?.id)
        try #require(m.deleteSet(row))
        #expect(m.supersets.first?.phase == .working)
        let archive = try NotebookBackupCodec.decode(m.backupData())
        #expect(archive.snapshot.training?.undo == m.workspace.undo)
        let reopened = try TrainingNotebookModel(repository: store)
        try #require(reopened.undoChange())
        #expect(reopened.workout == before && reopened.summary(for: day).setCount == 2)
    }

    @Test func failedAdvanceCanBeRetriedWithoutChangingTheSavedSetOrDuplicatingItsNextRow() throws {
        let store = SupersetFailureStore()
        let m = try TrainingNotebookModel(repository: store)
        let id = try prepare(m)
        try #require(m.startSuperset(id))
        try enterTurn(m, id)
        try #require(m.finishEditing())
        let before = m.snapshot
        store.reject = true
        #expect(!m.advanceSuperset(id) && m.canRetrySave)
        #expect(m.snapshot == before && store.snapshot == before)
        store.reject = false
        try #require(m.retrySave())
        let after = m.snapshot
        #expect(m.exercise?.id == "cable-row" && m.supersets.first?.completedTurns == 1)
        #expect(m.revealRowID == m.supersets.first?.currentRowID)
        #expect(m.summary(for: day).setCount == 1 && m.workout?.rows["cable-row"]?.count == 1)
        #expect(m.retrySave() && !m.advanceSuperset(id) && m.snapshot == after)
    }
}

@MainActor private final class SupersetFailureStore: JournalRepository {
    var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ candidate: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try candidate.validated()
    }
}
