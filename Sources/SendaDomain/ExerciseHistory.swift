import Foundation

public struct HistoricalSetReference: Equatable, Sendable {
    public let batchID: UUID
    public let setID: UUID
    public let recordedAt: Date
    public let values: SetValues
}

public struct CommonWorkingSet: Equatable, Sendable {
    public let weight: Int
    public let reps: ClosedRange<Int>
    public let occurrenceCount: Int
}

public struct ExerciseHistory: Equatable, Sendable {
    public let personalBest: HistoricalSetReference?
    public let commonWorkingSet: CommonWorkingSet?
}

public extension RecordedBatch {
    var topSet: PerformedSet? {
        sets.max { left, right in
            if left.values != right.values { return ranksBelow(left.values, right.values) }
            return left.position < right.position
        }
    }
}

public extension Journal {
    func history(for exerciseID: String) -> ExerciseHistory {
        // Entries are chronological, including a stable insertion order for tied dates.
        let samples = entries(for: exerciseID).flatMap { batch in
            batch.sets.map { HistoricalSetReference(batchID: batch.id, setID: $0.id,
                recordedAt: batch.recordedAt, values: $0.values) }
        }
        let best = samples.enumerated().max { left, right in
            if left.element.values != right.element.values {
                return ranksBelow(left.element.values, right.element.values)
            }
            return left.offset < right.offset
        }?.element
        let loads = Dictionary(grouping: samples.enumerated(), by: { $0.element.values.weight })
        let mostCommon = loads.max { left, right in
            if left.value.count != right.value.count { return left.value.count < right.value.count }
            return (left.value.last?.offset ?? -1) < (right.value.last?.offset ?? -1)
        }
        var common: CommonWorkingSet?
        if let (weight, observations) = mostCommon, observations.count >= 2 {
            let reps = observations.map { $0.element.values.reps }.sorted()
            // Outward-rounded observed quartiles keep sparse history readable and
            // prevent isolated rep outliers from defining the usual range.
            let lower = (reps.count - 1) / 4
            let upper = (3 * (reps.count - 1) + 3) / 4
            common = CommonWorkingSet(weight: weight, reps: reps[lower]...reps[upper],
                                      occurrenceCount: observations.count)
        }
        return ExerciseHistory(personalBest: best, commonWorkingSet: common)
    }
}

private func ranksBelow(_ left: SetValues, _ right: SetValues) -> Bool {
    left.weight == right.weight ? left.reps < right.reps : left.weight < right.weight
}
