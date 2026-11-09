import Foundation
import Testing
import SendaDomain
@testable import SendaNotebook

struct WeekMonthHeadingTests {
    @Test func headingsKeepMonthAndYearContextAtBoundaries() throws {
        let today = try TrainingDay("2026-11-08")
        for (first, last, full, short) in [
            ("2026-11-23", "2026-11-29", "November", "Nov"),
            ("2026-11-30", "2026-12-06", "November – December", "Nov – Dec"),
            ("2025-11-24", "2025-11-30", "November 2025", "Nov 2025"),
            ("2026-12-28", "2027-01-03", "December 2026 – January 2027", "Dec 2026 – Jan 2027")
        ] {
            #expect(TrainingText.weekMonths(first: try TrainingDay(first), last: try TrainingDay(last), today: today, abbreviated: false, locale: Locale(identifier: "en_US")) == full)
            #expect(TrainingText.weekMonths(first: try TrainingDay(first), last: try TrainingDay(last), today: today, abbreviated: true, locale: Locale(identifier: "en_US")) == short)
        }
    }
}
