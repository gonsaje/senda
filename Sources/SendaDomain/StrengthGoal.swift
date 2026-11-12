import Foundation

public struct StrengthGoal: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let exerciseID: String
    public let target: SetValues

    public init(id: UUID = UUID(), exerciseID: String, target: SetValues) {
        self.id = id
        self.exerciseID = exerciseID
        self.target = target
    }

    func validate() throws {
        guard !exerciseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              exerciseID.count <= 80 else { throw StrengthGoalError.invalidExercise }
        guard NumericField.weight.range.contains(target.weight),
              NumericField.reps.range.contains(target.reps) else { throw StrengthGoalError.invalidTarget }
    }
}

public enum StrengthGoalError: LocalizedError {
    case invalidExercise, invalidTarget, duplicateGoal

    public var errorDescription: String? {
        switch self {
        case .invalidExercise: "Choose an exercise for this goal."
        case .invalidTarget: "Enter a valid goal weight and rep count."
        case .duplicateGoal: "The saved goals contain a duplicate identifier."
        }
    }
}

public struct StrengthGoalProgress: Equatable, Identifiable, Sendable {
    public let goal: StrengthGoal
    public let best: ExerciseProgressSet?
    public let completedDay: TrainingDay?

    public var id: UUID { goal.id }
    public var isCompleted: Bool { completedDay != nil }
}

public extension JournalSnapshot {
    /// Projects goals from saved sets so correcting or deleting a set updates the result.
    func strengthGoalProgress(for goals: [StrengthGoal], through today: TrainingDay,
                              calendar: Calendar = .current) -> [StrengthGoalProgress] {
        guard !goals.isEmpty else { return [] }
        let history = progressHistory(through: today, calendar: calendar)
        let earliest = TrainingDay(rawValue: "0001-01-01")!
        return goals.map { goal in
            let setsByDay = history.sets(for: goal.exerciseID, from: earliest)
            let candidates = setsByDay.keys.sorted().compactMap { day -> (day: TrainingDay, set: ExerciseProgressSet)? in
                let qualifying = (setsByDay[day] ?? []).filter { $0.values.reps >= goal.target.reps }
                guard let best = progressBestSet(in: qualifying, metric: .weight) else { return nil }
                return (day, best)
            }
            let completedDay = candidates.first { $0.set.values.weight >= goal.target.weight }?.day
            let best = progressBestSet(in: candidates.map(\.set), metric: .weight)
            return StrengthGoalProgress(goal: goal, best: best, completedDay: completedDay)
        }
    }
}
