import Foundation
import Testing
import SendaDomain
@testable import SendaNotebook

struct WeekMonthHeadingTests {
    @Test func headingsShowOnlyMonthsAtCalendarBoundaries() throws {
        for (first, last, full, short) in [
            ("2026-11-23", "2026-11-29", "November", "Nov"),
            ("2026-11-30", "2026-12-06", "November – December", "Nov – Dec"),
            ("2025-11-24", "2025-11-30", "November", "Nov"),
            ("2026-12-28", "2027-01-03", "December – January", "Dec – Jan")
        ] {
            #expect(TrainingText.weekMonths(first: try TrainingDay(first), last: try TrainingDay(last), abbreviated: false, locale: Locale(identifier: "en_US")) == full)
            #expect(TrainingText.weekMonths(first: try TrainingDay(first), last: try TrainingDay(last), abbreviated: true, locale: Locale(identifier: "en_US")) == short)
        }
    }
}
