import Foundation

public struct Exercise: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let shortName: String
    public let startingWeight: Int

    public static let catalog: [Exercise] = [
        Exercise(id: "bench", name: "Bench", shortName: "Bench", startingWeight: 13_500),
        Exercise(id: "deadlift", name: "Deadlift", shortName: "DL", startingWeight: 22_500),
        Exercise(id: "squat", name: "Squat", shortName: "Squat", startingWeight: 18_500),
        Exercise(id: "row", name: "Barbell row", shortName: "Row", startingWeight: 0),
        Exercise(id: "overhead-press", name: "Overhead press", shortName: "Press", startingWeight: 0),
        Exercise(id: "lat-pulldown", name: "Lat pulldown", shortName: "Pulldown", startingWeight: 0),
        Exercise(id: "romanian-deadlift", name: "Romanian deadlift", shortName: "RDL", startingWeight: 0),
        Exercise(id: "dumbbell-bench", name: "Dumbbell bench", shortName: "DB bench", startingWeight: 0),
        Exercise(id: "pull-up", name: "Pull-up", shortName: "Pull-up", startingWeight: 0),
        Exercise(id: "leg-press", name: "Leg press", shortName: "Leg press", startingWeight: 0),
        Exercise(id: "leg-curl", name: "Leg curl", shortName: "Leg curl", startingWeight: 0),
        Exercise(id: "leg-extension", name: "Leg extension", shortName: "Leg extension", startingWeight: 0),
        Exercise(id: "lunge", name: "Lunge", shortName: "Lunge", startingWeight: 0),
        Exercise(id: "biceps-curl", name: "Biceps curl", shortName: "Curl", startingWeight: 0),
        Exercise(id: "triceps-extension", name: "Triceps extension", shortName: "Triceps", startingWeight: 0),
        Exercise(id: "lateral-raise", name: "Lateral raise", shortName: "Lateral raise", startingWeight: 0),
        Exercise(id: "calf-raise", name: "Calf raise", shortName: "Calf raise", startingWeight: 0),
        Exercise(id: "hip-thrust", name: "Hip thrust", shortName: "Hip thrust", startingWeight: 0),
        Exercise(id: "cable-row", name: "Cable row", shortName: "Cable row", startingWeight: 0),
        Exercise(id: "push-up", name: "Push-up", shortName: "Push-up", startingWeight: 0)
    ]
}

/// Weight is an integer number of hundredths of a pound, never a floating point value.
public struct SetValues: Codable, Equatable, Sendable {
    public var weight: Int
    public var reps: Int

    public init(weight: Int, reps: Int) {
        self.weight = weight
        self.reps = reps
    }
}

public struct DraftBatch: Codable, Equatable, Sendable {
    public let actionID: UUID
    public let exerciseID: String
    public var sets: [SetValues]

    public init(actionID: UUID = UUID(), exerciseID: String, sets: [SetValues]) {
        self.actionID = actionID
        self.exerciseID = exerciseID
        self.sets = sets
    }
}

public struct PerformedSet: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let position: Int
    public let values: SetValues
}

public struct RecordedBatch: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let actionID: UUID
    public let exerciseID: String
    public let recordedAt: Date
    public let revision: Int
    public let sets: [PerformedSet]
    public var values: [SetValues] { sets.map(\.values) }
}

public enum JournalError: Error, Equatable, LocalizedError {
    case invalidSets, invalidExercise, actionConflict, actionUndone, missingBatch, staleRevision, corruptJournal

    public var errorDescription: String? {
        switch self {
        case .invalidSets: "Use 1–30 sets, 1–999 reps, and a weight from 0 to 10,000 lb."
        case .invalidExercise: "Choose an exercise before recording."
        case .actionConflict: "This record action was already used for different values. Start another batch."
        case .actionUndone: "This record action was undone. Record a fresh draft instead."
        case .missingBatch: "That recorded entry is no longer available."
        case .staleRevision: "That entry changed. Reopen it before making this change."
        case .corruptJournal: "The journal file is inconsistent. It has been left untouched."
        }
    }
}

public enum SetValidation {
    public static func validate(_ sets: [SetValues]) throws {
        guard (1...30).contains(sets.count), sets.allSatisfy({
            (0...1_000_000).contains($0.weight) && (1...999).contains($0.reps)
        }) else { throw JournalError.invalidSets }
    }
}

public struct EntryComparison: Equatable, Sendable {
    public let previous: RecordedBatch
    public let current: RecordedBatch

    public var repDifferenceAtSameWeight: Int? {
        guard let weight = previous.sets.first?.values.weight,
              previous.sets.allSatisfy({ $0.values.weight == weight }),
              current.sets.allSatisfy({ $0.values.weight == weight }) else { return nil }
        return current.values.reduce(0) { $0 + $1.reps } - previous.values.reduce(0) { $0 + $1.reps }
    }
}
