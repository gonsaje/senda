import Foundation

public struct WeeklyMuscleTarget: Codable, Equatable, Identifiable, Sendable {
    public let muscle: MuscleRegion
    public let minimumSets: Int
    public let maximumSets: Int
    public var id: MuscleRegion { muscle }

    public init(muscle: MuscleRegion, minimumSets: Int, maximumSets: Int) {
        self.muscle = muscle
        self.minimumSets = minimumSets
        self.maximumSets = maximumSets
    }

    func validate() throws {
        guard minimumSets > 0, maximumSets >= minimumSets else {
            throw WeeklyMuscleTargetError.invalidRange
        }
    }
}

public enum WeeklyMuscleTargetError: LocalizedError, Equatable {
    case invalidRange, duplicateMuscle

    public var errorDescription: String? {
        switch self {
        case .invalidRange: "Enter at least 1 set for the minimum. The maximum must be equal to or higher than the minimum."
        case .duplicateMuscle: "Each muscle can have one weekly target."
        }
    }
}
