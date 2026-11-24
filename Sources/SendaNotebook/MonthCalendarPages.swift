import SwiftUI
import SendaDomain

/// Calendar dates and their localized text depend on the month and locale alone.
/// Workout activity is read from the notebook separately so edits appear immediately.
@MainActor final class MonthCalendarPages {
    struct DayText: Sendable {
        let number: String
        let date: Date
    }

    struct Page: Sendable {
        let month: TrainingMonth
        let locale: Locale
        let includesNeighbors: Bool
        let spokenDates: [TrainingDay: String]
        let listDateStyle: Date.FormatStyle
        let visibleDays: [TrainingDay]
        let monthDays: [TrainingDay]
        let window: MonthWeekWindow
        let text: [TrainingDay: DayText]
    }

    private struct Cache: Sendable {
        let page: Page
        let slots: [TrainingDay: [TrainingDay?]]
    }
    private var cache: Cache?

    func page(for month: TrainingMonth, locale: Locale, includesNeighbors: Bool = true) -> Page {
        if let page = cache?.page, page.month == month, page.locale == locale,
           page.includesNeighbors == includesNeighbors { return page }
        let next = Self.build(month: month, locale: locale, includesNeighbors: includesNeighbors, reusing: cache)
        cache = next
        return next.page
    }

    /// Prepare the first calendar while Week is on screen. A tap can always open Month immediately.
    func prepareIfNeeded(for day: TrainingDay, locale: Locale, includesNeighbors: Bool) async {
        guard cache == nil else { return }
        let prepared = await Task.detached(priority: .utility) {
            Self.build(month: TrainingMonth(containing: day), locale: locale, includesNeighbors: includesNeighbors, reusing: nil)
        }.value
        if !Task.isCancelled, cache == nil { cache = prepared }
    }

    nonisolated private static func build(month: TrainingMonth, locale: Locale, includesNeighbors: Bool,
                                          reusing cache: Cache?) -> Cache {
        // Retain the overlapping grids on a page turn, and bound storage to three months.
        let previous = includesNeighbors ? month.adding(months: -1) : nil
        let next = includesNeighbors ? month.adding(months: 1) : nil
        var adjacent: [TrainingDay: [TrainingDay?]] = [:]
        for page in [previous, month, next].compactMap({ $0 }) {
            adjacent[page.firstDay] = cache?.slots[page.firstDay] ?? page.calendarSlots
        }
        let visible = adjacent[month.firstDay] ?? []
        let window = MonthWeekWindow(previous: previous.flatMap { adjacent[$0.firstDay] } ?? [],
                                     current: visible, next: next.flatMap { adjacent[$0.firstDay] } ?? [])
        let calendar = TrainingText.utc
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let number = style.day()
        let reusable = cache?.page.locale == locale ? cache?.page : nil
        var text: [TrainingDay: DayText] = [:]
        for week in window.weeks {
            for case let day? in week.dates {
                if let existing = reusable?.text[day] {
                    text[day] = existing
                } else {
                    let date = day.date(in: calendar)
                    text[day] = DayText(number: date.formatted(number), date: date)
                }
            }
        }
        let visibleDays = visible.compactMap { $0 }
        let longDate = style.weekday(.wide).month(.wide).day().year()
        var spokenDates: [TrainingDay: String] = [:]
        for day in visibleDays {
            spokenDates[day] = reusable?.spokenDates[day] ?? text[day]?.date.formatted(longDate)
        }
        let prefix = month.firstDay.rawValue.prefix(7)
        let page = Page(month: month, locale: locale, includesNeighbors: includesNeighbors,
                        spokenDates: spokenDates,
                        listDateStyle: style.weekday(.abbreviated).month(.abbreviated).day(), visibleDays: visibleDays,
                        monthDays: visibleDays.filter { $0.rawValue.hasPrefix(prefix) }, window: window, text: text)
        return Cache(page: page, slots: adjacent)
    }
}

/// A shared boundary week has one identity and moves by whole rows as the active month changes.
struct MonthWeekWindow: Sendable {
    struct Week: Identifiable, Sendable {
        let id: TrainingDay
        let offset: Int
        let dates: [TrainingDay?]
    }

    let weeks: [Week]
    let previousWeekCount: Int
    let nextWeekOffset: Int

    init(previous previousSlots: [TrainingDay?], current currentSlots: [TrainingDay?], next nextSlots: [TrainingDay?]) {
        func rows(_ slots: [TrainingDay?]) -> [[TrainingDay?]] {
            stride(from: 0, to: slots.count, by: 7).map { Array(slots[$0..<($0 + 7)]) }
        }

        let current = rows(currentSlots)
        let previous = rows(previousSlots)
        let next = rows(nextSlots)
        // Each page starts on the Monday on or before the first of its month.
        // Keep only the leading weeks of each page up to the next page's start.
        func leadingWeeks(_ page: [[TrainingDay?]], before following: [[TrainingDay?]]) -> Int {
            guard let first = following.first, let overlap = page.firstIndex(of: first) else { return page.count }
            return overlap
        }
        let preceding = leadingWeeks(previous, before: current)
        let advance = leadingWeeks(current, before: next)
        previousWeekCount = preceding
        nextWeekOffset = next.isEmpty ? 0 : advance
        let sequence = previous.prefix(preceding) + current.prefix(advance) + next[...]
        weeks = sequence.enumerated().compactMap { index, dates in
            guard let first = dates.compactMap({ $0 }).first else { return nil }
            return Week(id: first, offset: index - preceding, dates: dates)
        }
    }
}
