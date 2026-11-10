import SendaDomain

struct TrainingTrendFeedback: Equatable {
    let text: String
    let symbol: String?
    let positive: Bool

    static func make(comparison: TrainingTrendComparison, latest: SetValues,
                     previous: SetValues?, exercise: Exercise, unit: WeightUnit) -> Self {
        switch comparison {
        case .insufficientHistory:
            return Self(text: "One recorded day in this window. Record another day to compare.",
                        symbol: nil, positive: false)
        case let .repsAtSameWeight(recordedDelta, recordedWeight):
            let delta = previous.map { latest.reps - $0.reps } ?? recordedDelta
            let weight = previous == nil ? recordedWeight : latest.weight
            let load = exercise.requiresWeight
                ? "\(unit.text(for: weight)) \(unit.symbol)"
                : weight == 0 ? "BW" : "BW + \(unit.text(for: weight)) \(unit.symbol)"
            return Self(text: "\(repChange(delta)) at \(load)",
                        symbol: delta > 0 ? "arrow.up" : "arrow.down", positive: delta > 0)
        case let .weightAtSameReps(recordedDelta, recordedReps):
            let delta = previous.map { latest.weight - $0.weight } ?? recordedDelta
            let reps = previous == nil ? recordedReps : latest.reps
            return Self(text: "\(weightChange(delta, exercise: exercise, unit: unit)) for \(reps) \(reps == 1 ? "rep" : "reps")",
                        symbol: delta > 0 ? "arrow.up" : "arrow.down", positive: delta > 0)
        case .matched:
            return Self(text: "Matched prior set", symbol: "equal", positive: false)
        case .differentSets:
            guard let previous else {
                return Self(text: "Weight and reps changed", symbol: "arrow.left.arrow.right", positive: false)
            }
            let weight = weightChange(latest.weight - previous.weight, exercise: exercise, unit: unit)
            let reps = repChange(latest.reps - previous.reps)
            return Self(text: "\(weight) · \(reps)", symbol: "arrow.left.arrow.right", positive: false)
        }
    }

    private static func repChange(_ delta: Int) -> String {
        "\(abs(delta)) \(delta > 0 ? "more" : "fewer") \(abs(delta) == 1 ? "rep" : "reps")"
    }

    private static func weightChange(_ delta: Int, exercise: Exercise, unit: WeightUnit) -> String {
        let amount = unit.text(for: abs(delta))
        let change = amount == "0" && delta != 0
            ? "Less than 0.01 \(unit.symbol) \(delta > 0 ? "more" : "less")"
            : "\(amount) \(unit.symbol) \(delta > 0 ? "more" : "less")"
        return "\(change)\(exercise.requiresWeight ? "" : " added weight")"
    }
}
