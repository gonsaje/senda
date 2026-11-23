import Foundation
import SendaDomain

extension TrainingNotebookModel {
    public var sampleTrainer: TrainerPage {
        var page = TrainerPage.sample
        guard snapshot.customExercises?.isEmpty == false else { return page }
        let mapping = Dictionary(uniqueKeysWithValues: exercises.compactMap { exercise -> (String, String)? in
            guard let preset = exercise.presetID, preset != exercise.id else { return nil }
            return (preset, exercise.id)
        })
        guard let program = try? page.makeProgram() else { return page }
        let sessions = program.mappingExercises(mapping).blocks[0].sessions
        page.workouts = zip(page.workouts, sessions).map { original, session in
            WorkoutTemplate(id: original.id, name: original.name, exerciseIDs: session.exercises.map(\.exerciseID),
                exercisePlans: Dictionary(uniqueKeysWithValues: session.exercises.map { ($0.exerciseID, $0.plan) }),
                supersets: session.supersets, trainerDetails: original.trainerDetails)
        }
        return page
    }

    @discardableResult public func saveTrainerProgram(_ page: TrainerPage) -> Bool {
        do {
            try page.validate(availableExercises: Set(activeExercises.map(\.id)))
            guard let program = try page.makeProgram() else { throw TrainerPageError.details }
            guard !customPrograms.contains(where: { $0.id == program.id }) else { return true }
            return saveProgram(program)
        } catch { errorMessage = error.localizedDescription; return false }
    }

    @discardableResult public func saveTrainerWorkout(_ workout: WorkoutTemplate, from page: TrainerPage) -> Bool {
        guard !savedWorkouts.contains(where: { $0.id == workout.id }) else { return true }
        do {
            try page.validate()
            _ = try workout.validated(against: Set(activeExercises.map(\.id)))
            guard page.workouts.contains(workout) else { throw TrainerPageError.details }
        } catch { errorMessage = error.localizedDescription; return false }
        // Readers may already have their own template with this name.
        var name = workout.name
        var suffix = 2
        while savedWorkouts.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            let ending = " (\(suffix))"
            name = String(workout.name.prefix(80 - ending.count)) + ending
            suffix += 1
        }
        return saveWorkout(WorkoutTemplate(id: workout.id, name: name, exerciseIDs: workout.exerciseIDs,
            exercisePlans: workout.exercisePlans, supersets: workout.supersets, trainerCredit: page.name,
            trainerDetails: workout.trainerDetails, trainerOriginID: workout.trainerOriginID ?? workout.id))
    }
}
