import Foundation
import SendaDomain

/// Positions are measured in ticks and finger translation in points.
struct WeightDialScale {
    static let tickSpacing: CGFloat = 32
    private static let engagementDistance: CGFloat = 0.60
    let unit: WeightUnit
    let lastTick: Int

    init(unit: WeightUnit) {
        self.unit = unit
        lastTick = Int(ceil(NSDecimalNumber(decimal: unit.maximumAmount / unit.step).doubleValue))
    }

    func weight(at tick: Int) -> Int {
        if tick <= 0 { return 0 }
        if tick >= lastTick { return NumericField.weight.range.upperBound }
        // Every interior tick is strictly within the canonical storage range.
        return unit.canonicalValue(for: Decimal(tick) * unit.step)!
    }

    func position(for weight: Int) -> CGFloat {
        if weight <= 0 { return 0 }
        if weight >= NumericField.weight.range.upperBound { return CGFloat(lastTick) }
        let estimate = NSDecimalNumber(decimal: unit.amount(for: weight) / unit.step).doubleValue
        let lower = min(lastTick - 1, Int(estimate))
        // Interpolate between actual stored weights so rounded kg ticks line up exactly.
        // This also handles the shorter final interval at the maximum weight.
        let lowWeight = self.weight(at: lower)
        let highWeight = self.weight(at: lower + 1)
        return CGFloat(lower) + CGFloat(weight - lowWeight) / CGFloat(highWeight - lowWeight)
    }

    func dragPosition(from start: CGFloat, translation: CGFloat) -> CGFloat {
        min(CGFloat(lastTick), max(0, start - translation / Self.tickSpacing))
    }

    func nearestTick(to position: CGFloat) -> Int {
        Int(min(CGFloat(lastTick), max(0, position)).rounded())
    }

    /// A detent holds past the midpoint in either direction. Reversing at the ridge
    /// therefore does not click back until the finger has actually crossed the return ridge.
    func engagedTick(at rawPosition: CGFloat, from engaged: Int, preserving typedPosition: CGFloat? = nil) -> Int {
        let raw = min(CGFloat(lastTick), max(0, rawPosition))
        if let typedPosition, abs(raw - typedPosition) < 0.25 { return engaged }
        let allowance = 1 - Self.engagementDistance
        // Move one ULP outward to include a threshold hit after floating-point translation.
        if raw >= CGFloat(engaged) { return Int(floor((raw + allowance).nextUp)) }
        return Int(ceil((raw - allowance).nextDown))
    }

    /// Pull the visual scale toward the selected notch. When the next notch engages,
    /// the pull switches sides, producing a small catch at the same instant as the click.
    func dragDisplayPosition(at rawPosition: CGFloat, engaged: Int) -> CGFloat {
        let raw = min(CGFloat(lastTick), max(0, rawPosition))
        let offset = raw - CGFloat(engaged)
        let fraction = min(1, max(-1, offset / Self.engagementDistance))
        return raw - 0.075 * fraction * fraction * fraction
    }
}

/// A critically damped return to the already selected weight. Releasing a finger
/// never selects another notch, even after a fast turn.
struct WeightDialRelease: Equatable {
    let start: CGFloat
    let end: CGFloat

    init(from start: CGFloat, to end: CGFloat) {
        self.start = start
        self.end = end
    }

    func position(after seconds: TimeInterval) -> CGFloat {
        guard seconds > 0 else { return start }
        let decayTime = 44 * CGFloat(seconds)
        let displacement = (start - end) * (1 + decayTime) * exp(-decayTime)
        return abs(displacement) < 0.002 ? end : end + displacement
    }
}
