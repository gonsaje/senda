import SendaDomain

public extension LoggerModel {
    var exerciseHistory: ExerciseHistory { journal.history(for: selectedExerciseID) }
}
