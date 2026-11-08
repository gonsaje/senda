import Foundation

public struct ExercisePersonalRecord: Identifiable, Equatable, Sendable {
    public let exerciseID: String
    public let reference: HistoricalSetReference
    public var id: String { exerciseID }
}

public struct BigThreeProgress: Equatable, Sendable {
    public static let exerciseIDs = ["bench", "deadlift", "squat"]
    public let records: [ExercisePersonalRecord]
    public var totalWeight: Int? {
        records.count == Self.exerciseIDs.count ? records.reduce(0) { $0 + $1.reference.values.weight } : nil
    }
    public init(records: [ExercisePersonalRecord]) {
        self.records = Self.exerciseIDs.compactMap { id in records.first { $0.exerciseID == id } }
    }
}

public extension Journal {
    var personalRecords: [ExercisePersonalRecord] {
        Set(batches.map(\.exerciseID)).sorted().compactMap { id in
            history(for: id).personalBest.map { ExercisePersonalRecord(exerciseID: id, reference: $0) }
        }
    }
    var bigThreeProgress: BigThreeProgress { BigThreeProgress(records: personalRecords) }
}
