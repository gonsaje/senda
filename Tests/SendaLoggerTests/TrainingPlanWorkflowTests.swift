import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct TrainingPlanWorkflowTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private var today: TrainingDay { try! TrainingDay("2026-11-09") }
    private func model(_ repository: (any JournalRepository)? = nil) throws -> TrainingNotebookModel {
        try TrainingNotebookModel(repository: repository ?? MemoryJournalRepository(), calendar: calendar,
                                  now: { today.date(in: calendar) })
    }
    private func enter(_ model: TrainingNotebookModel, weight: String = "135", reps: String = "10") throws {
        let row = try #require(model.rows.last)
        #expect(model.selectInput(row.id, field: .weight))
        model.typeInput(weight, focus: try #require(model.focus))
        #expect(model.selectInput(row.id, field: .reps))
        model.typeInput(reps, focus: try #require(model.focus))
    }
    @Test func newRowsDefaultToWorkingWithoutInventingEffortOrRecords() throws {
        let model = try model()
        #expect(model.openToday())
        #expect(model.addExercise("bench"))
        #expect(model.rows.first?.kind?.rawValue == "working")
        #expect(model.rows.first?.repsInReserve == nil)
        try enter(model)
        #expect(model.finishEditing())
        #expect(model.newSet())
        #expect(model.rows.last?.kind?.rawValue == "working")
        #expect(model.rows.last?.repsInReserve == nil)
        #expect(model.rows.count == 2)
        #expect(model.journal.batches.flatMap(\.sets).count == 1)
        #expect(model.addExercises(["squat", "push-up"]))
        #expect(model.workout?.rows["squat"]?.first?.kind?.rawValue == "working")
        #expect(model.workout?.rows["push-up"]?.first?.kind?.rawValue == "working")
        #expect(model.createExercise(named: "Travel raise", group: .shoulders, equipment: .dumbbell))
        #expect(model.rows.first?.kind?.rawValue == "working")
    }

    @Test func storedSetKindsSurviveReopeningAndBackupWithoutNormalizingLegacyRegular() throws {
        for kind: TrainingSetKind? in [.regular, .warmup, .working, .dropSet, nil] {
            let store = MemoryJournalRepository()
            let model = try model(store)
            #expect(model.openToday()); #expect(model.addExercise("bench"))
            try enter(model); #expect(model.finishEditing())
            let row = try #require(model.rows.first)
            #expect(model.setKind(kind, for: row.id))
            let stored = try store.loadSnapshot()
            let reopened = try self.model(store)
            #expect(reopened.rows.first?.kind == kind)
            #expect(try store.loadSnapshot() == stored)
            let archive = try NotebookBackupCodec.decode(reopened.backupData())
            #expect(archive.snapshot.training?.days[today.rawValue]?.rows["bench"]?.first?.kind == kind)
            #expect(archive.snapshot == stored)
        }
    }

    @Test func dropTypeChangeRetriesWithFocusValuesAndRecordedIdentityIntact() throws {
        let store = PlanFailureRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model)
        let before = try #require(model.rows.first), focus = model.focus, journal = model.journal
        #expect(model.setRepsInReserve(3, for: before.id))
        let saved = model.snapshot
        store.reject = true
        #expect(!model.setKind(.dropSet, for: before.id))
        #expect(model.snapshot == saved && model.canRetrySave)
        #expect(try store.loadSnapshot() == saved)
        store.reject = false
        #expect(model.retrySave())
        let updated = try #require(model.rows.first)
        #expect(updated.kind == .dropSet && updated.repsInReserve == 3)
        #expect(updated.id == before.id && updated.actionID == before.actionID)
        #expect(updated.performedSetID == before.performedSetID && model.journal == journal)
        #expect(updated.weight == "135" && updated.reps == "10" && model.focus == focus)
        let reopened = try self.model(store)
        #expect(reopened.rows == model.rows && reopened.focus == focus)
    }

    @Test func metadataAndPlanEditsKeepAutomaticallySavedInputAndFocus() throws {
        let store = MemoryJournalRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model)
        let before = try #require(model.rows.first), focus = model.focus
        let plan = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)
        #expect(model.setPlan(plan, for: "bench"))
        #expect(model.updateSetDetails(before.id, kind: .warmup, repsInReserve: 4))
        var expected = before; expected.kind = .warmup; expected.repsInReserve = 4
        #expect(model.rows == [expected])
        #expect(model.focus == focus)
        #expect(model.plan(for: "bench") == plan)
        #expect(model.recordedValues(for: expected) == SetValues(weight: 13_500, reps: 10))
        #expect(model.journal.batches.flatMap(\.sets).count == 1 && expected.performedSetID != nil)
        let reopened = try self.model(store)
        #expect(reopened.rows == [expected] && reopened.focus == focus)
        #expect(reopened.journal == model.journal)
        #expect(reopened.plan(for: "bench") == plan)
    }

    @Test func editingAnnotationsDoesNotAcceptOrDiscardPendingCorrections() throws {
        let model = try model()
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model); #expect(model.finishEditing())
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .reps))
        model.typeInput("", focus: try #require(model.focus))
        let before = try #require(model.rows.first), focus = model.focus, journal = model.journal
        #expect(model.rowStatus(for: before) == .pendingCorrection)
        #expect(model.setKind(.warmup, for: row.id))
        #expect(model.setRepsInReserve(2, for: row.id))
        #expect(model.setPlan(ExercisePlan(workingSets: 2, minimumReps: 8, maximumReps: 10), for: "bench"))
        var expected = before; expected.kind = .warmup; expected.repsInReserve = 2
        #expect(model.rows == [expected] && model.focus == focus && model.journal == journal)
        #expect(model.recordedValues(for: expected)?.reps == 10)
        #expect(model.rowStatus(for: expected) == .pendingCorrection)
        #expect(model.discardCorrection(row.id))
        #expect(model.rows.first?.reps == "10")
        #expect(model.rows.first?.kind == .warmup && model.rows.first?.repsInReserve == 2)
    }

    @Test func metadataFailurePublishesOnlyAfterRetryWithOriginalIdentityAndInput() throws {
        let store = PlanFailureRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model, weight: "31.", reps: "8")
        let before = model.snapshot, row = try #require(model.rows.first)
        store.reject = true
        #expect(!model.updateSetDetails(row.id, kind: .warmup, repsInReserve: 5))
        #expect(model.snapshot == before && model.canRetrySave)
        #expect(try store.loadSnapshot() == before)
        #expect(!model.retrySave() && model.snapshot == before)
        store.reject = false
        #expect(model.retrySave())
        var expected = row; expected.kind = .warmup; expected.repsInReserve = 5
        #expect(model.rows == [expected] && model.focus == before.training?.focus)
        #expect(model.journal.batches.isEmpty && !model.canRetrySave)
        #expect(model.retrySave() && model.rows == [expected])
    }

    @Test func newerMetadataSupersedesFailedNavigationAndKeepsAutomaticallySavedSet() throws {
        let store = PlanFailureRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model)
        let row = try #require(model.rows.first), focus = model.focus
        store.reject = true
        #expect(!model.openProgress(for: "bench"))
        #expect(model.canRetryProgressAction)
        #expect(!model.setKind(.warmup, for: row.id))
        store.reject = false
        #expect(model.retrySave())
        #expect(!model.isProgressPresented && !model.canRetryProgressAction)
        #expect(model.rows.first?.kind == .warmup && model.focus == focus)
        #expect(model.recordedValues(for: try #require(model.rows.first)) == SetValues(weight: 13_500, reps: 10))
        #expect(model.rows.first?.performedSetID == row.performedSetID && model.summary(for: today).setCount == 1)
    }

    @Test func beginningMetadataEditingAbandonsFailedDoneAndRetriesVisibleNumericCorrection() throws {
        let store = PlanFailureRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model)
        let original = try #require(model.rows.first), saved = try store.loadSnapshot()
        store.reject = true
        model.typeInput("8", focus: try #require(model.focus))
        let visibleDraft = model.snapshot
        #expect(model.recordedValues(for: try #require(model.rows.first))?.reps == 10)
        #expect(try store.loadSnapshot() == saved)
        #expect(!model.finishEditing())
        #expect(!model.beginMetadataEditing())
        #expect(model.snapshot == visibleDraft && model.canRetrySave)
        store.reject = false
        #expect(model.retrySave())
        #expect(try store.loadSnapshot() == model.snapshot)
        #expect(model.rows.first?.reps == "8" && model.focus == visibleDraft.training?.focus)
        #expect(model.rows.first?.id == original.id && model.rows.first?.actionID == original.actionID)
        #expect(model.rows.first?.performedSetID == original.performedSetID)
        #expect(model.recordedValues(for: try #require(model.rows.first))?.reps == 8)
        #expect(model.journal.batches.flatMap(\.sets).count == 1 && !model.canRetrySave)
        let retried = model.snapshot
        #expect(model.retrySave() && model.snapshot == retried)
    }

    @Test func beginningMetadataEditingAbandonsFailedProgressAndPreservesAutosavedCorrection() throws {
        let store = PlanFailureRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model); #expect(model.finishEditing())
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .reps))
        model.typeInput("8", focus: try #require(model.focus))
        let visibleCorrection = model.snapshot
        store.reject = true
        #expect(!model.openProgress(for: "bench") && model.canRetryProgressAction)
        #expect(model.beginMetadataEditing())
        #expect(!model.canRetryProgressAction && !model.canRetrySave)
        store.reject = false
        #expect(model.retrySave())
        #expect(model.snapshot == visibleCorrection)
        #expect(try store.loadSnapshot() == visibleCorrection)
        #expect(!model.isProgressPresented)
        #expect(model.rows.first?.reps == "8" && model.focus == visibleCorrection.training?.focus)
        #expect(model.recordedValues(for: try #require(model.rows.first))?.reps == 8)
        #expect(model.rowStatus(for: try #require(model.rows.first)) == .recorded)
        #expect(model.rows.first?.performedSetID == row.performedSetID)
    }

    @Test func beginningMetadataEditingClearsAbandonedProfileAction() throws {
        let store = PlanFailureRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model)
        let before = model.snapshot
        store.reject = true
        #expect(!model.setPreferredUnit(.kilograms) && model.canRetryProfileAction)
        #expect(model.beginMetadataEditing())
        #expect(!model.canRetryProfileAction && !model.canRetrySave)
        store.reject = false
        #expect(model.retrySave())
        #expect(model.snapshot == before && model.workspace.preferredUnit == .pounds)
        #expect(model.journal.batches.flatMap(\.sets).count == 1)
    }

    @Test func planFailureRetriesAtomicallyAndLaterRemovalSupersedesIt() throws {
        let store = PlanFailureRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        let original = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)
        #expect(model.setPlan(original, for: "bench"))
        try enter(model)
        let before = model.snapshot
        let replacement = ExercisePlan(workingSets: 2, minimumReps: 5, maximumReps: 8)
        store.reject = true
        #expect(!model.setPlan(replacement, for: "bench"))
        #expect(model.snapshot == before && model.plan(for: "bench") == original)
        #expect(!model.retrySave())
        store.reject = false
        #expect(model.retrySave() && model.plan(for: "bench") == replacement)
        #expect(model.focus == before.training?.focus && model.journal == before.journal)
        store.reject = true
        #expect(!model.setPlan(original, for: "bench"))
        store.reject = false
        #expect(model.setPlan(nil, for: "bench"))
        #expect(model.retrySave() && model.plan(for: "bench") == nil)
        #expect(model.journal == before.journal)
    }

    @Test func invalidMetadataAndMissingTargetsLeaveVisibleAndStoredStateUntouched() throws {
        let store = MemoryJournalRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        let row = try #require(model.rows.first), before = model.snapshot
        for value in [-1, 6] {
            #expect(!model.updateSetDetails(row.id, kind: .warmup, repsInReserve: value))
            #expect(model.snapshot == before)
        }
        #expect(!model.setRepsInReserve(6, for: row.id))
        #expect(!model.setKind(.warmup, for: UUID()))
        #expect(!model.setPlan(ExercisePlan(workingSets: 0, minimumReps: 8, maximumReps: 12), for: "bench"))
        #expect(!model.setPlan(ExercisePlan(workingSets: 3, minimumReps: 12, maximumReps: 8), for: "bench"))
        #expect(!model.setPlan(ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12), for: "squat"))
        #expect(model.snapshot == before && !model.canRetrySave)
        #expect(try store.loadSnapshot() == before)
        #expect(model.showWeek())
        #expect(!model.setPlan(ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12), for: "bench"))
    }

    @Test func newDayInheritsNearestEarlierWorkoutPlanAndHonorsRemovedPlan() throws {
        let model = try model()
        let first = try TrainingDay("2026-11-02"), second = try TrainingDay("2026-11-05")
        let plan = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)
        #expect(model.openDay(first)); #expect(model.addExercise("bench"))
        #expect(model.setPlan(plan, for: "bench"))
        #expect(model.openDay(second)); #expect(model.addExercises(["bench", "squat"]))
        #expect(model.plan(for: "bench") == plan && model.plan(for: "squat") == nil)
        #expect(model.setPlan(nil, for: "bench"))
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        #expect(model.plan(for: "bench") == nil)
        #expect(model.plan(for: "bench", on: first) == plan)
        #expect(model.plan(for: "bench", on: second) == nil)
        #expect(model.rows.count == 1 && model.journal.batches.isEmpty)
        let older = try TrainingDay("2026-11-01")
        #expect(model.openDay(older)); #expect(model.addExercise("bench"))
        #expect(model.plan(for: "bench") == nil)
    }

    @Test func readdingHiddenLegacyRowsDoesNotAssignPlansOrClassifications() throws {
        let prior = try TrainingDay("2026-11-02")
        let oldRow = TrainingRow(weight: "31.", reps: "8", unit: .pounds, weightIsDirty: true)
        let plan = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)
        let training = TrainingWorkspace(visibleWeek: try today.week()[0], selectedDay: today, days: [
            prior.rawValue: DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench",
                rows: ["bench": [TrainingRow(unit: .pounds)]], exercisePlans: ["bench": plan]),
            today.rawValue: DayWorkout(rows: ["bench": [oldRow]])
        ])
        let model = try model(MemoryJournalRepository(snapshot: JournalSnapshot(training: training)))
        #expect(model.addExercise("bench"))
        #expect(model.rows == [oldRow] && model.plan(for: "bench") == nil)
        #expect(model.setPlan(plan, for: "bench"))
        #expect(model.removeExercise("bench")); #expect(model.addExercise("bench"))
        #expect(model.rows == [oldRow] && model.plan(for: "bench") == plan)
    }

    @Test func reuseCopiesChosenPlansOnlyForNewRowsAndPreservesDestination() throws {
        let model = try model()
        let source = try TrainingDay("2026-11-02"), intervening = try TrainingDay("2026-11-05")
        let sourcePlan = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)
        let laterPlan = ExercisePlan(workingSets: 2, minimumReps: 5, maximumReps: 8)
        #expect(model.openDay(source)); #expect(model.addExercise("bench"))
        try enter(model); #expect(model.finishEditing()); #expect(model.setPlan(sourcePlan, for: "bench"))
        #expect(model.addExercise("squat")); #expect(model.addExercise("push-up"))
        #expect(model.openDay(intervening)); #expect(model.addExercise("bench")); #expect(model.setPlan(laterPlan, for: "bench"))
        #expect(model.addExercise("push-up")); #expect(model.setPlan(laterPlan, for: "push-up"))
        #expect(model.openToday()); #expect(model.addExercise("squat"))
        #expect(model.setPlan(laterPlan, for: "squat"))
        try enter(model, weight: "31.", reps: "8")
        let destination = model.workout?.rows["squat"]
        #expect(model.reuseWorkout(from: source))
        #expect(model.plan(for: "bench") == sourcePlan)
        #expect(model.plan(for: "squat") == laterPlan)
        #expect(model.plan(for: "push-up") == nil)
        #expect(model.workout?.rows["squat"] == destination)
        #expect(model.workout?.rows["bench"]?.count == 1 && model.workout?.rows["bench"]?.first?.weight == "")
        #expect(model.summary(for: today).setCount == 0)
    }

    @Test func failedReuseRetriesExerciseRowsAndChosenPlansTogether() throws {
        let store = PlanFailureRepository()
        let model = try model(store)
        let source = try TrainingDay("2026-11-02")
        let plan = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)
        #expect(model.openDay(source)); #expect(model.addExercise("bench"))
        try enter(model); #expect(model.finishEditing()); #expect(model.setPlan(plan, for: "bench"))
        #expect(model.openToday()); #expect(model.addExercise("squat"))
        let before = model.snapshot
        store.reject = true
        #expect(!model.reuseWorkout(from: source))
        #expect(model.snapshot == before && model.plan(for: "bench") == nil)
        #expect(try store.loadSnapshot() == before)
        store.reject = false
        #expect(model.retrySave())
        let row = try #require(model.workout?.rows["bench"]?.first)
        #expect(model.plan(for: "bench") == plan && row.kind == .working)
        #expect(row.weight == "" && row.reps == "" && row.performedSetID == nil)
        #expect(model.summary(for: today).setCount == 0)
    }

    @Test func guidanceUsesRequestedDayAndStaysReadOnlyWhileNumericDraftIsFocused() throws {
        let store = MemoryJournalRepository()
        let model = try model(store)
        let past = try TrainingDay("2026-11-02")
        let oldPlan = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)
        let newPlan = ExercisePlan(workingSets: 2, minimumReps: 5, maximumReps: 8)
        #expect(model.openDay(past)); #expect(model.addExercise("bench")); #expect(model.setPlan(oldPlan, for: "bench"))
        #expect(model.openToday()); #expect(model.addExercise("bench")); #expect(model.setPlan(newPlan, for: "bench"))
        try enter(model)
        let before = model.snapshot
        #expect(model.nextWorkoutGuidance(for: "bench").plan == newPlan)
        #expect(model.nextWorkoutGuidance(for: "bench", on: past).plan == oldPlan)
        #expect(model.snapshot == before && model.journal.batches.flatMap(\.sets).count == 1)
        #expect(try store.loadSnapshot() == before)
        #expect(model.openDay(past)); #expect(model.nextWorkoutGuidance(for: "bench").plan == oldPlan)
        #expect(model.showWeek())
        #expect(model.plan(for: "bench") == newPlan)
        #expect(model.nextWorkoutGuidance(for: "bench").plan == newPlan)
    }

    @Test func repeatKeepsEveryKindButClearsEffortAndPrefillKeepsDestinationKind() throws {
        let kinds: [(TrainingSetKind?, TrainingSetKind?)] = [
            (.regular, .warmup), (.warmup, .working), (.working, .dropSet), (.dropSet, nil), (nil, .regular)
        ]
        for (kind, destinationKind) in kinds {
            let model = try model()
            #expect(model.openToday()); #expect(model.addExercise("bench"))
            try enter(model); #expect(model.finishEditing())
            let first = try #require(model.rows.first)
            #expect(model.updateSetDetails(first.id, kind: kind, repsInReserve: 4))
            #expect(model.repeatLastSet())
            let repeated = try #require(model.rows.last)
            #expect(repeated.kind == kind && repeated.repsInReserve == nil)
            #expect(repeated.id != first.id && repeated.actionID != first.actionID && repeated.performedSetID != first.performedSetID)
            #expect(model.newSet())
            let blank = try #require(model.rows.last)
            #expect(blank.kind == .working)
            #expect(model.updateSetDetails(blank.id, kind: destinationKind, repsInReserve: 5))
            #expect(model.prefillSet(blank.id))
            #expect(model.rows.last?.kind == destinationKind && model.rows.last?.repsInReserve == nil)
            #expect(model.rows.last?.weight == "135" && model.rows.last?.reps == "10")
            #expect(model.rows.last?.performedSetID != nil && model.focus?.rowID == blank.id)
            #expect(model.recordedValues(for: try #require(model.rows.last)) == SetValues(weight: 13_500, reps: 10))
            #expect(model.journal.batches.flatMap(\.sets).count == 3)
        }
    }

    @Test func annotationsAndPlansSurviveDeleteUndoReopenAndRestore() throws {
        let store = MemoryJournalRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model); #expect(model.finishEditing())
        let row = try #require(model.rows.first)
        let plan = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)
        #expect(model.setPlan(plan, for: "bench"))
        #expect(model.updateSetDetails(row.id, kind: .warmup, repsInReserve: 5))
        let annotated = try #require(model.rows.first)
        #expect(model.deleteSet(row.id))
        let archive = try NotebookBackupCodec.decode(model.backupData())
        let reopened = try self.model(store)
        #expect(reopened.undoChange())
        #expect(reopened.rows == [annotated] && reopened.plan(for: "bench") == plan)
        #expect(reopened.restoreBackup(archive))
        #expect(reopened.rows.isEmpty && reopened.plan(for: "bench") == plan)
        #expect(reopened.undoChange())
        #expect(reopened.rows == [annotated])
        #expect(reopened.recordedValues(for: annotated) == SetValues(weight: 13_500, reps: 10))
    }
}

@MainActor private final class PlanFailureRepository: JournalRepository {
    private var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { try snapshot.validated() }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated()
    }
}
