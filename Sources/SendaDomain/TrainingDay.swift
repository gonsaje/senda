import Foundation

public struct TrainingDay: RawRepresentable, Codable, Hashable, Comparable, Sendable {
    public let rawValue: String
    private static var utc: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    public init(_ text: String) throws {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard text.count == 10, parts.count == 3, (1...9999).contains(parts[0]),
              let date = Self.utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
              Self.key(date, calendar: Self.utc) == text else { throw TrainingError.invalidDay }
        rawValue = text
    }
    public init?(rawValue: String) { try? self.init(rawValue) }
    public init(_ date: Date, calendar: Calendar = .current) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        rawValue = Self.key(date, calendar: gregorian)
    }
    private static func key(_ date: Date, calendar: Calendar) -> String {
        let value = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", value.year!, value.month!, value.day!)
    }
    public func date(in calendar: Calendar = .current) -> Date {
        let parts = rawValue.split(separator: "-").map { Int($0)! }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
    }
    public func adding(days: Int) throws -> TrainingDay {
        guard let date = Self.utc.date(byAdding: .day, value: days, to: date(in: Self.utc)) else { throw TrainingError.invalidDay }
        return try TrainingDay(Self.key(date, calendar: Self.utc))
    }
    public func week() throws -> [TrainingDay] {
        let weekday = Self.utc.component(.weekday, from: date(in: Self.utc))
        let monday = try adding(days: -(weekday == 1 ? 6 : weekday - 2))
        return try (0..<7).map { try monday.adding(days: $0) }
    }
    public static func < (left: Self, right: Self) -> Bool { left.rawValue < right.rawValue }
    public init(from decoder: any Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: any Encoder) throws { var box = encoder.singleValueContainer(); try box.encode(rawValue) }
}

public enum TrainingError: Error, LocalizedError {
    case invalidDay, invalidWorkspace, incompleteWeight, missingRow
    public var errorDescription: String? {
        switch self {
        case .invalidDay: "That date is not valid."
        case .invalidWorkspace: "The saved notebook could not be restored. Your file has been left untouched."
        case .incompleteWeight: "Finish or clear the incomplete weight before changing units."
        case .missingRow: "That set is no longer available."
        }
    }
}
