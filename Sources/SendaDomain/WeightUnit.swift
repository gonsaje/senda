import Foundation

public enum WeightUnit: String, Codable, CaseIterable, Sendable {
    case pounds = "lb"
    case kilograms = "kg"

    // NIST's exact definition: one avoirdupois pound is 0.45359237 kilograms.
    private static let kilogramsPerPound = Decimal(45_359_237) / 100_000_000

    public var symbol: String { rawValue }
    public var alternate: WeightUnit { self == .pounds ? .kilograms : .pounds }
    public var step: Decimal { self == .pounds ? Decimal(5) / 2 : Decimal(5) / 4 }
    public var maximumAmount: Decimal { amount(for: NumericField.weight.range.upperBound) }

    /// Converts the stored hundredths of a pound without rounding the display amount.
    public func amount(for canonicalWeight: Int) -> Decimal {
        let pounds = Decimal(canonicalWeight) / 100
        return self == .pounds ? pounds : pounds * Self.kilogramsPerPound
    }

    public func text(for canonicalWeight: Int) -> String {
        var displayed = Self.rounded(amount(for: canonicalWeight), scale: 2)
        var text = NSDecimalString(&displayed, Locale(identifier: "en_US_POSIX"))
        if text.contains(".") {
            while text.last == "0" { text.removeLast() }
            if text.last == "." { text.removeLast() }
        }
        return text
    }

    /// Rounds to the nearest stored hundredth of a pound, with ties rounded up.
    public func canonicalValue(for amount: Decimal) -> Int? {
        guard !amount.isNaN, amount >= 0, amount <= maximumAmount else { return nil }
        let pounds = self == .pounds ? amount : amount / Self.kilogramsPerPound
        let value = NSDecimalNumber(decimal: Self.rounded(pounds * 100, scale: 0)).intValue
        return NumericField.weight.range.contains(value) ? value : nil
    }

    public func parse(_ text: String) -> Int? {
        guard let hundredths = NumericField.weight.parse(text) else { return nil }
        return canonicalValue(for: Decimal(hundredths) / 100)
    }

    public func stepped(_ canonicalWeight: Int, increasing: Bool) -> Int {
        let range = NumericField.weight.range
        let current = min(max(canonicalWeight, range.lowerBound), range.upperBound)
        // Start from the displayed precision so kilogram rounding does not accumulate.
        let displayed = Self.rounded(amount(for: current), scale: 2)
        let next = displayed + (increasing ? step : -step)
        if next <= 0 { return range.lowerBound }
        if next >= maximumAmount { return range.upperBound }
        return canonicalValue(for: next)!
    }

    private static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var value = value
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
