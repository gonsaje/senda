import Foundation

public enum NumericField: String, CaseIterable, Identifiable, Codable, Sendable {
    case weight, reps, sets
    public var id: Self { self }
    public var label: String {
        switch self { case .weight: "lb"; case .reps: "reps"; case .sets: "sets" }
    }
    public var title: String {
        switch self { case .weight: "Weight"; case .reps: "Reps per set"; case .sets: "Number of sets" }
    }
    public var step: Int { self == .weight ? 250 : 1 }
    public var range: ClosedRange<Int> {
        switch self { case .weight: 0...1_000_000; case .reps: 1...999; case .sets: 1...30 }
    }
    public func parse(_ text: String) -> Int? {
        guard !text.isEmpty, text.count <= 10 else { return nil }
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        let pieces = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= (self == .weight ? 2 : 1),
              pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              let whole = Int(pieces[0]) else { return nil }
        let value: Int
        if self == .weight {
            let fractional = pieces.count == 2 ? String(pieces[1]) : ""
            guard fractional.count <= 2, whole <= 10_000 else { return nil }
            value = whole * 100 + (Int(fractional.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0)
        } else { value = whole }
        return range.contains(value) ? value : nil
    }
    public func text(_ value: Int) -> String {
        guard self == .weight else { return String(value) }
        let whole = value / 100, fraction = value % 100
        if fraction == 0 { return String(whole) }
        return "\(whole)." + (fraction % 10 == 0 ? String(fraction / 10) : String(format: "%02d", fraction))
    }
}
