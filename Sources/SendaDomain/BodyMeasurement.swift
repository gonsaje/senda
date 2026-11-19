import Foundation

public enum BodyMetric: String, CaseIterable, Identifiable, Codable, Sendable {
    case weight, waist, bodyFat

    public var id: Self { self }

    public func symbol(unit: WeightUnit) -> String {
        switch self {
        case .weight: unit.symbol
        case .waist: unit == .pounds ? "in" : "cm"
        case .bodyFat: "%"
        }
    }

    /// Stored values are kilograms, centimeters, or percentage points.
    public func canonicalValue(from text: String, unit: WeightUnit) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 10 else { return nil }
        let decimalSeparator = Locale.current.decimalSeparator
        var normalized = ""
        for character in trimmed {
            if character == "." || character == "," || character == "٫" || String(character) == decimalSeparator {
                normalized.append(".")
            } else if character.unicodeScalars.count == 1,
                      character.unicodeScalars.first?.properties.numericType == .decimal,
                      let digit = character.wholeNumberValue {
                normalized.append(String(digit))
            } else {
                return nil
            }
        }
        guard let hundredths = NumericField.weight.parse(normalized) else { return nil }
        let canonical = Double(hundredths) / 100 * displayFactor(unit: unit)
        return contains(canonical) ? canonical : nil
    }

    public func displayValue(_ canonical: Double, unit: WeightUnit) -> Double {
        canonical / displayFactor(unit: unit)
    }

    private static let kilogramsPerPound = NSDecimalNumber(decimal: WeightUnit.kilograms.amount(for: 100)).doubleValue

    private func displayFactor(unit: WeightUnit) -> Double {
        guard unit == .pounds else { return 1 }
        switch self {
        case .weight: return Self.kilogramsPerPound
        case .waist: return 2.54
        case .bodyFat: return 1
        }
    }

    fileprivate func contains(_ value: Double) -> Bool {
        value.isFinite && value > 0 && value <= (self == .bodyFat ? 100 : 10_000)
    }
}

public struct BodyMeasurement: Identifiable, Equatable, Codable, Sendable {
    public enum Source: Equatable, Codable, Sendable {
        case manual
        case appleHealth(String)
    }

    public let id: UUID
    public let metric: BodyMetric
    public let value: Double
    public let date: Date
    public let source: Source
    private let manualDay: TrainingDay?

    public init(id: UUID = UUID(), metric: BodyMetric, value: Double, date: Date, source: Source = .manual,
                calendar: Calendar = .current) throws {
        guard Self.supports(date) else { throw BodyMeasurementError.invalidValue }
        self.id = id
        self.metric = metric
        self.value = value
        self.date = date
        self.source = source
        manualDay = source == .manual ? TrainingDay(date, calendar: calendar) : nil
        try validate()
    }

    /// Date-only manual entries retain their selected day after time zone changes.
    public func displayDate(in calendar: Calendar = .current) -> Date {
        guard let manualDay else { return date }
        return calendar.startOfDay(for: manualDay.date(in: calendar))
    }

    public func validate() throws {
        guard metric.contains(value), Self.supports(date),
              (manualDay != nil) == (source == .manual) else {
            throw BodyMeasurementError.invalidValue
        }
    }

    private static func supports(_ date: Date) -> Bool {
        date >= .distantPast && date <= .distantFuture
    }
}

public enum BodyMeasurementError: LocalizedError {
    case invalidValue, noValues, missingManualReading, manualHistoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidValue: "Enter a valid measurement."
        case .noValues: "Enter at least one measurement."
        case .missingManualReading: "This manual entry is no longer available."
        case .manualHistoryUnavailable: "Manual measurements couldn’t be opened. Try again before saving."
        }
    }
}
