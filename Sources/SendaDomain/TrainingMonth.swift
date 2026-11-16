import Foundation

public struct TrainingMonth: Equatable, Sendable {
    public let firstDay: TrainingDay

    public init(containing day: TrainingDay) {
        let calendar = TrainingDay.utc
        let date = day.date(in: calendar)
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? date
        firstDay = TrainingDay(start, calendar: calendar)
    }

    public var days: [TrainingDay] {
        let calendar = TrainingDay.utc
        let date = firstDay.date(in: calendar)
        let length = calendar.range(of: .day, in: .month, for: date)?.count ?? 0
        let yearMonth = firstDay.rawValue.prefix(7)
        return Array((0..<length).lazy
            .compactMap { try? firstDay.adding(days: $0) }
            .prefix { $0.rawValue.prefix(7) == yearMonth })
    }

    /// Keeps the month grid aligned with the notebook's Monday-first weeks.
    public var leadingEmptyDays: Int {
        let calendar = TrainingDay.utc
        let weekday = calendar.component(.weekday, from: firstDay.date(in: calendar))
        return (weekday + 5) % 7
    }

    public func adding(months: Int) -> TrainingMonth? {
        let calendar = TrainingDay.utc
        let components = calendar.dateComponents([.year, .month], from: firstDay.date(in: calendar))
        guard let year = components.year, let month = components.month else { return nil }
        let index = (year - 1) * 12 + month - 1
        let (next, overflow) = index.addingReportingOverflow(months)
        guard !overflow, (0..<(9999 * 12)).contains(next),
              let day = TrainingDay(rawValue: String(format: "%04d-%02d-01", next / 12 + 1, next % 12 + 1))
        else { return nil }
        return TrainingMonth(containing: day)
    }
}
