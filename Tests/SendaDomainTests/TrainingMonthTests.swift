import Testing
@testable import SendaDomain

struct TrainingMonthTests {
    @Test func datesIncludeLeapDayAndAlignToMonday() throws {
        let month = TrainingMonth(containing: try TrainingDay("2024-02-17"))
        #expect(month.firstDay.rawValue == "2024-02-01")
        #expect(month.leadingEmptyDays == 3)
        #expect(month.days.map(\.rawValue) == (1...29).map { "2024-02-\($0 < 10 ? "0" : "")\($0)" })
    }

    @Test func navigatingAcrossYearsPreservesMonthBoundaries() throws {
        let december = TrainingMonth(containing: try TrainingDay("2024-12-31"))
        let january = try #require(december.adding(months: 1))
        #expect(december.leadingEmptyDays == 6)
        #expect(january.firstDay.rawValue == "2025-01-01")
        #expect(january.days.last?.rawValue == "2025-01-31")
        #expect(january.adding(months: -1) == december)
        #expect(january.adding(months: 1)?.days.count == 28)
    }

    @Test func monthsCannotMoveOutsideTheSupportedYears() throws {
        let earliest = TrainingMonth(containing: try TrainingDay("0001-01-01"))
        let latest = TrainingMonth(containing: try TrainingDay("9999-12-31"))
        #expect(earliest.adding(months: -1) == nil)
        #expect(latest.adding(months: 1) == nil)
        #expect(earliest.adding(months: .max) == nil)
        #expect(latest.adding(months: .min) == nil)
        #expect(latest.days.last?.rawValue == "9999-12-31")
    }
}
