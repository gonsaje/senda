import Foundation

/// A balanced barbell load. Totals use the journal's hundredths of a pound. Plate sizes use the selected unit.
public enum PlateLoading: Equatable, Sendable {
    public struct PlateCount: Equatable, Sendable {
        public let size: Decimal
        public let count: Int

        public init(size: Decimal, count: Int) {
            self.size = size
            self.count = count
        }
    }

    case belowBar
    case exact(total: Int, perSide: [PlateCount])
    case between(lower: Int, upper: Int?)

    public static func calculate(totalWeight: Int, barbellWeight: Int, unit: WeightUnit) -> Self? {
        guard NumericField.weight.range.contains(totalWeight), barbellWeight > 0,
              NumericField.weight.range.contains(barbellWeight) else { return nil }

        // The bar and target are read at the same displayed precision as manual plate entry.
        let bar = unit.displayedAmount(for: barbellWeight)
        let total = unit.displayedAmount(for: totalWeight)
        if total < bar { return .belowBar }
        if total == bar { return .exact(total: barbellWeight, perSide: []) }

        let sizes = unit.plateSizes
        guard let smallest = sizes.first else { return nil }
        let pairStep = smallest * 2
        let steps = NSDecimalNumber(decimal: (total - bar) / pairStep).intValue
        let lower = bar + Decimal(steps) * pairStep
        if total != lower {
            let lowerWeight = steps == 0 ? barbellWeight : unit.canonicalValue(for: lower)
            guard let lowerWeight else { return nil }
            return .between(lower: lowerWeight, upper: unit.canonicalValue(for: lower + pairStep))
        }
        return .exact(total: totalWeight, perSide: fewestPlates(steps: steps, smallest: smallest, sizes: sizes))
    }

    /// One step represents a smallest-size plate on each side. Trying larger plates first breaks equal-count ties.
    private static func fewestPlates(steps: Int, smallest: Decimal, sizes: [Decimal]) -> [PlateCount] {
        let sizes = Array(sizes.reversed())
        let denominations = sizes.map { NSDecimalNumber(decimal: $0 / smallest).intValue }
        var minimum = Array(repeating: steps + 1, count: steps + 1)
        var choice = Array(repeating: 0, count: steps + 1)
        minimum[0] = 0

        for amount in 1...steps {
            for index in denominations.indices where denominations[index] <= amount {
                let count = 1 + minimum[amount - denominations[index]]
                if count < minimum[amount] {
                    minimum[amount] = count
                    choice[amount] = index
                }
            }
        }

        var counts = Array(repeating: 0, count: sizes.count)
        var remaining = steps
        while remaining > 0 {
            let index = choice[remaining]
            counts[index] += 1
            remaining -= denominations[index]
        }
        return sizes.indices.compactMap { index in
            counts[index] > 0 ? PlateCount(size: sizes[index], count: counts[index]) : nil
        }
    }
}
