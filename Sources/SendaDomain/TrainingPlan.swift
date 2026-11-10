import Foundation

public struct ExercisePlan: Codable, Equatable, Sendable {
    public var workingSets: Int
    public var minimumReps: Int
    public var maximumReps: Int

    public init(workingSets: Int, minimumReps: Int, maximumReps: Int) {
        self.workingSets = workingSets
        self.minimumReps = minimumReps
        self.maximumReps = maximumReps
    }

    public func validated() throws -> Self {
        guard NumericField.sets.range.contains(workingSets),
              NumericField.reps.range.contains(minimumReps),
              NumericField.reps.range.contains(maximumReps),
              minimumReps <= maximumReps else { throw TrainingError.invalidWorkspace }
        return self
    }
}

public enum TrainingSetKind: String, Codable, CaseIterable, Sendable {
    case regular, warmup, working, dropSet

    public var countsTowardWorkingPlan: Bool {
        switch self {
        case .regular, .working: true
        case .warmup, .dropSet: false
        }
    }
}
