import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct WorkoutExerciseTests {
    @Test func addingPresetsExtendsTheWorkoutAndRecordingDoesNotReorderIt() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        for id in ["row", "overhead-press", "lat-pulldown", "leg-press"] { #expect(model.addExercise(id)) }
        let order = ["bench", "deadlift", "squat", "row", "overhead-press", "lat-pulldown", "leg-press"]
        #expect(model.workoutExercises.map(\.id) == order)
        #expect(model.selectedExerciseID == "leg-press")
        #expect(model.addExercise("row"))
        #expect(model.workoutExercises.map(\.id) == order)
        #expect(model.selectedExerciseID == "row")
        #expect(model.record())
        #expect(model.workoutExercises.map(\.id) == order)
    }

    @Test func customExerciseTabsAndIndividualSetsSurviveReopening() throws {
        let store = MemoryJournalRepository()
        let model = try LoggerModel(repository: store)
        #expect(model.createAndAddExercise(named: "My row"))
        let id = model.selectedExerciseID
        #expect(model.exercise.name == "My row")
        #expect(model.values.allSatisfy { $0.weight == 0 })
        #expect(model.exerciseHistory.personalBest == nil)
        model.selectSet(3, field: .reps)
        model.typeNumber("8")
        #expect(model.closeNumberEditor())
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.selectedExerciseID == id)
        #expect(reopened.workoutExercises.map(\.id).last == id)
        #expect(reopened.values.map(\.reps) == [10, 10, 10, 8])
        #expect(reopened.journal.batches.isEmpty)
        #expect(reopened.record())
        reopened.selectSet(0, field: .weight, unit: .kilograms)
        reopened.typeNumber("20")
        #expect(reopened.finishEditing())
        #expect(reopened.exerciseHistory.personalBest?.values.weight == 4_409)
        #expect(reopened.undo())
        #expect(reopened.exerciseHistory.personalBest == nil)
        #expect(reopened.availableExercises.contains { $0.id == id && $0.name == "My row" })
    }

    @Test func removedTabsKeepHistoryAndUnfinishedSessionsWhenReadded() throws {
        let store = MemoryJournalRepository()
        let model = try LoggerModel(repository: store)
        #expect(model.createAndAddExercise(named: "Cable fly"))
        let id = model.selectedExerciseID
        model.selectSet(2, field: .reps)
        model.typeNumber("7")
        #expect(model.closeNumberEditor())
        #expect(model.removeExercise(id))
        #expect(!model.workoutExercises.contains { $0.id == id })
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.addExercise(id))
        #expect(reopened.values.map(\.reps) == [10, 10, 7, 10])
        #expect(reopened.record())
        let recorded = reopened.recorded
        #expect(reopened.removeExercise(id))
        #expect(reopened.addExercise(id))
        #expect(reopened.recorded == recorded)
        #expect(reopened.journal.batches.count == 1)
    }

    @Test func failedAddsAndRemovalsDoNotPublishCatalogOrWorkoutChanges() throws {
        let store = WorkoutFailureStore()
        let model = try LoggerModel(repository: store)
        let original = model.workoutExercises
        store.rejectWrites = true
        #expect(!model.addExercise("row"))
        #expect(model.workoutExercises == original)
        #expect(!model.createAndAddExercise(named: "My lift"))
        #expect(!model.availableExercises.contains { $0.name == "My lift" })
        #expect(!model.removeExercise("bench"))
        #expect(model.workoutExercises == original)
        #expect(model.selectedExerciseID == "bench")
        store.rejectWrites = false
        #expect(model.createAndAddExercise(named: "My lift"))
        #expect(try LoggerModel(repository: store).exercise.name == "My lift")
    }

    @Test func invalidCurrentInputBlocksWorkoutChangesWithoutLosingText() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.selectSet(0, field: .weight, unit: .kilograms)
        model.typeNumber("61.")
        #expect(!model.addExercise("row"))
        #expect(!model.createAndAddExercise(named: "New lift"))
        #expect(!model.removeExercise("bench"))
        #expect(model.numberInputText == "61.")
        #expect(model.selectedExerciseID == "bench")
        #expect(model.workoutExercises.count == 3)
    }

    @Test func duplicatesAreRejectedAndTheLastWorkoutTabCannotBeRemoved() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        #expect(!model.createAndAddExercise(named: " bench "))
        #expect(model.createAndAddExercise(named: "Café row"))
        #expect(!model.createAndAddExercise(named: "CAFE ROW"))
        for exercise in model.workoutExercises.dropLast() { #expect(model.removeExercise(exercise.id)) }
        #expect(model.workoutExercises.count == 1)
        #expect(!model.removeExercise(model.selectedExerciseID))
    }
}

@MainActor private final class WorkoutFailureStore: JournalRepository {
    private var snapshot = JournalSnapshot()
    var rejectWrites = false
    func loadSnapshot() throws -> JournalSnapshot { try snapshot.validated() }
    func saveSnapshot(_ value: JournalSnapshot) throws {
        if rejectWrites { throw CocoaError(.fileWriteUnknown) }
        snapshot = try value.validated()
    }
}
