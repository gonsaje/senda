import Foundation
import SendaDomain
import Testing
@testable import SendaNotebook

struct MonthWeekWindowTests {
    @MainActor @Test func changingLayoutAndLocaleRefreshesTheCachedPage() throws {
        let pages = MonthCalendarPages()
        let leapDay = try TrainingDay("2024-02-29")
        let month = TrainingMonth(containing: leapDay)
        let english = Locale(identifier: "en_US")
        let arabic = Locale(identifier: "ar_EG")
        let grid = pages.page(for: month, locale: english)
        let list = pages.page(for: month, locale: arabic, includesNeighbors: false)
        #expect(grid.window.weeks.count > 6)
        #expect(list.window.weeks.count == 6)
        #expect(list.monthDays == month.days)
        let text = try #require(list.text[leapDay])
        let format = Date.FormatStyle(locale: arabic, calendar: TrainingText.utc, timeZone: TrainingText.utc.timeZone)
        #expect(text.number == text.date.formatted(format.day()))
        #expect(grid.text[leapDay]?.number != text.number)
        let rebuilt = pages.page(for: month, locale: english)
        #expect(rebuilt.window.weeks.map(\.id) == grid.window.weeks.map(\.id))
        #expect(rebuilt.text[leapDay]?.number == grid.text[leapDay]?.number)
    }

    @MainActor @Test(arguments: ["2026-10-01", "2026-11-01", "2026-12-01", "2021-02-01", "2024-02-01"])
    func adjacentMonthsShareOneChronologicalSequence(_ key: String) throws {
        let month = TrainingMonth(containing: try TrainingDay(key))
        let next = try #require(month.adding(months: 1))
        let pages = MonthCalendarPages()
        let window = pages.page(for: month, locale: .current).window
        let nextWindow = pages.page(for: next, locale: .current).window
        let days = window.weeks.flatMap(\.dates).compactMap { $0 }
        #expect(Set(days).count == days.count)
        for (day, following) in zip(days, days.dropFirst()) {
            #expect(try day.adding(days: 1) == following)
        }

        func visibleWeeks(start: Int) -> [MonthWeekWindow.Week] {
            window.weeks.filter { (start..<(start + 6)).contains($0.offset) }
        }
        #expect(visibleWeeks(start: 0).flatMap(\.dates) == month.calendarSlots)
        #expect(visibleWeeks(start: window.nextWeekOffset).flatMap(\.dates) == next.calendarSlots)
        #expect(window.nextWeekOffset == nextWindow.previousWeekCount)
        #expect(visibleWeeks(start: window.nextWeekOffset).map(\.id)
                == nextWindow.weeks.filter { (0..<6).contains($0.offset) }.map(\.id))
    }
}
