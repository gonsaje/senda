import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct ManagedExerciseTests {
    @Test func manageInLibraryPreservesTheSelectedDayAndRawInput() throws {
        let store = MemoryJournalRepository()
        let model = try TrainingNotebookModel(repository: store)
        #expect(model.openToday() && model.addExercise("bench"))
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .weight))
        model.typeInput("31.", focus: try #require(model.focus))
        let before = model.workspace
        #expect(model.createLibraryExercise(named: "Garage lift", group: .back, equipment: .cable))
        let id = try #require(model.snapshot.customExercises?.last?.id)
        #expect(model.canManageCustomExercise(id) && model.workspace == before)
        #expect(!model.createLibraryExercise(named: "Garage-lift", group: .back, equipment: .cable))
        #expect(!model.updateCustomExercise(id, named: "Bench", group: .chest, equipment: .barbell))
        #expect(model.updateCustomExercise(id, named: "Porch pull", group: .arms, equipment: .dumbbell,
                                         customSetup: .init(gyms: [.home], requiredEquipment: [.dumbbells])))
        #expect(model.workspace == before && model.journal.batches.isEmpty)
        let reopened = try TrainingNotebookModel(repository: store)
        #expect(reopened.exercise(id).name == "Porch pull" && reopened.exercise(id).group == .arms)
        #expect(reopened.exercise(id).customSetup.requiredEquipment == [.dumbbells])
        #expect(reopened.snapshot.customExercises?.count == 1)
    }

    @Test func workoutCustomExerciseTagsSurviveFailedEditAndFullRestore() throws {
        let store = ManagedExerciseStore(), model = try TrainingNotebookModel(repository: store)
        #expect(model.openToday())
        #expect(model.createExercise(named: "Garden press", group: .chest, equipment: .barbell,
            customMuscleTags: [.chest, .triceps]))
        let original = try #require(model.exercise)
        store.reject = true
        #expect(!model.updateCustomExercise(original.id, named: "Garden press", group: .chest, equipment: .barbell,
            customMuscleTags: [.chest, .frontShoulders]))
        #expect(model.exercise(original.id).customMuscleTags == [.chest, .triceps])
        store.reject = false
        #expect(model.retrySave() && model.exercise(original.id).customMuscleTags == [.chest, .frontShoulders])
        #expect(model.updateCustomExercise(original.id, named: "Garden bench", group: .chest, equipment: .barbell))
        #expect(model.archiveCustomExercise(original.id))
        let archive = try NotebookBackupCodec.decode(model.backupData())
        let restored = try TrainingNotebookModel(repository: MemoryJournalRepository())
        #expect(restored.restoreBackup(archive))
        let lift = restored.exercise(original.id)
        #expect(lift.isArchived && lift.name == "Garden bench" && lift.customMuscleTags == [.chest, .frontShoulders])
        #expect(!model.updateCustomExercise("bench", named: "Bench", group: .chest, equipment: .barbell,
            customMuscleTags: [.chest]))
    }

    @Test func archivePreservesRecordedWorkoutAndFiltersOnlyNewAdditions() throws {
        let store = MemoryJournalRepository()
        let model = try TrainingNotebookModel(repository: store)
        let old = try model.today.adding(days: -2)
        #expect(model.createLibraryExercise(named: "Garage lift", group: .arms, equipment: .dumbbell))
        let id = try #require(model.snapshot.customExercises?.first?.id)
        #expect(model.openDay(old) && model.addExercise("bench") && model.addExercise(id))
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .weight))
        model.typeInput("45", focus: try #require(model.focus))
        #expect(model.selectInput(row.id, field: .reps))
        model.typeInput("8", focus: try #require(model.focus))
        #expect(model.finishEditing())
        let target = ExercisePlan(workingSets: 2, minimumReps: 8, maximumReps: 12)
        #expect(model.setPlan(target, for: id))
        let template = WorkoutTemplate(name: "Garage day", exerciseIDs: [id, "bench"], exercisePlans: [id: target])
        #expect(model.saveWorkout(template))
        let original = model.workspace, journal = model.journal
        #expect(model.archiveCustomExercise(id))
        #expect(model.workspace == original && model.journal == journal)
        #expect(!model.activeExercises.contains { $0.id == id } && !model.recentExercises().contains { $0.id == id })
        #expect(model.exercise(id).name == "Garage lift" && model.exercise(id).isArchived)
        #expect(model.snapshot.recordedSessions(for: model.exercise(id)).first?.sets.first?.values == SetValues(weight: 4_500, reps: 8))
        #expect(model.availableWorkoutExerciseIDs(template.exerciseIDs, on: old) == [id, "bench"])
        #expect(model.availableWorkoutExerciseIDs(template.exerciseIDs, on: model.today) == ["bench"])
        let archivedOnly = WorkoutTemplate(name: "Retired lift", exerciseIDs: [id])
        #expect(!model.applyWorkout(archivedOnly, on: model.today))
        #expect(model.workspace == original)
        #expect(model.applyWorkout(template, on: model.today))
        #expect(model.tabs.map(\.id) == ["bench"] && model.plan(for: id) == nil)
        #expect(!model.addExercise(id) && !model.addExercises([id]))
        #expect(!model.saveWorkout(WorkoutTemplate(name: "New day", exerciseIDs: [id])))
        let tomorrow = try model.today.adding(days: 1)
        #expect(model.reuseWorkout(from: old, on: tomorrow))
        #expect(model.tabs.map(\.id) == ["bench"] && model.plan(for: id) == nil)
        #expect(model.createLibraryExercise(named: "Garage lift", group: .back, equipment: .cable))
        let newChoice = try #require(model.activeExercises.first { $0.name == "Garage lift" })
        #expect(newChoice.id != id && model.addExercise(newChoice.id))
        #expect(model.rows.first?.performedSetID == nil && model.plan(for: newChoice.id) == nil)
        #expect(model.snapshot.recordedSessions(for: newChoice).isEmpty)
        #expect(model.availableWorkoutExerciseIDs(template.exerciseIDs, on: tomorrow) == ["bench"])
        let reopened = try TrainingNotebookModel(repository: store)
        #expect(reopened.savedWorkouts == [template] && reopened.exercise(id).isArchived)
        #expect(reopened.workspace.days[old.rawValue] == original.days[old.rawValue] && reopened.journal == journal)
    }

    @Test func catalogExercisesAndPersonalCatalogAliasesAreProtected() throws {
        let alias = Exercise(id: "custom-saved", name: "Wall chair", shortName: "Wall chair", startingWeight: 0)
        let store = try MemoryJournalRepository(snapshot: JournalSnapshot(customExercises: [alias]))
        let model = try TrainingNotebookModel(repository: store)
        let before = model.snapshot
        for id in ["bench", alias.id] {
            #expect(!model.canManageCustomExercise(id))
            #expect(!model.updateCustomExercise(id, named: "Changed", group: .arms, equipment: .cable))
            #expect(!model.updateCustomExerciseSetup(.init(gyms: [.home]), for: id))
            #expect(!model.archiveCustomExercise(id))
        }
        #expect(!model.deleteWorkout(id: "push"))
        #expect(model.snapshot == before)
    }

    @Test func failedArchiveKeepsExercisePickableUntilRetryAndCanBeCancelled() throws {
        let store = ManagedExerciseStore()
        let model = try TrainingNotebookModel(repository: store)
        #expect(model.createLibraryExercise(named: "Porch lift", group: .arms, equipment: .cable))
        let id = try #require(model.snapshot.customExercises?.first?.id)
        store.reject = true
        #expect(!model.archiveCustomExercise(id) && model.canRetrySave && !model.exercise(id).isArchived)
        store.reject = false
        #expect(model.cancelPendingAction() && model.retrySave() && model.canManageCustomExercise(id))
        store.reject = true
        #expect(!model.archiveCustomExercise(id) && !model.retrySave())
        store.reject = false
        #expect(model.retrySave() && model.exercise(id).isArchived)
        #expect(try store.loadSnapshot().customExercises?.first?.isArchived == true)
    }
}

@MainActor private final class ManagedExerciseStore: JournalRepository {
    private var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated()
    }
}
