import Foundation
import SendaDomain
import Testing
@testable import SendaNotebook

struct BodyMeasurementTrendChartTests {
    private func sample(_ day: String, _ value: Double) throws -> MeasurementTrendSample {
        let day = try TrainingDay(day)
        return MeasurementTrendSample(day: day, date: day.date(), value: value, spokenValue: String(value))
    }

    @Test func sparseWeightHoldsAcrossWorkoutDaysAndEndsAtTheRangeBoundary() throws {
        let prior = try sample("2026-10-29", 170), newer = try sample("2026-11-11", 175)
        let start = try sample("2026-11-01", 0).date, end = try sample("2026-11-19", 0).date
        let spans = WeightTrendSpan.make(daily: [newer], preceding: prior, domain: start...end)
        #expect(spans.map(\.value) == [170, 175])
        #expect(spans.map(\.start) == [start, newer.date])
        #expect(spans.map(\.end) == [newer.date, end])
        #expect(spans[1].previousValue == 170)
        #expect(spans.allSatisfy { !$0.isReference })
        #expect(WeightTrendSpan.make(daily: [], preceding: prior, domain: start...end).map(\.value) == [170])
        #expect(WeightTrendSpan.make(daily: [], preceding: nil, domain: start...end).isEmpty)
    }

    @Test func loneWeighInGetsADatedReferenceEvenOnTheLastDay() throws {
        let lone = try sample("2026-11-19", 160)
        let start = try sample("2026-11-01", 0).date
        let domain = start...lone.date
        let spans = WeightTrendSpan.make(daily: [lone], preceding: nil, domain: domain)
        #expect(spans.first?.start == start && spans.first?.end == lone.date)
        #expect(spans.first?.isReference == true)
        #expect(spans.allSatisfy { $0.value == 160 })
        let first = try sample("2026-11-08", 165)
        let multiple = WeightTrendSpan.make(daily: [first, lone], preceding: nil, domain: domain)
        #expect(multiple.first?.start == first.date)
        #expect(multiple.map(\.value) == [165, 160])
        let prior = try sample("2026-10-30", 160)
        let atStart = WeightTrendSpan.make(daily: [try sample("2026-11-01", 161)], preceding: prior, domain: domain)
        #expect(atStart.map(\.value) == [161])
    }

    @Test func oneDayUsesThatDaysWeighInAcrossTheEntireChart() throws {
        let prior = try sample("2026-11-18", 165), today = try sample("2026-11-19", 170)
        let bounds = try #require(Calendar.current.dateInterval(of: .day, for: today.date))
        let spans = WeightTrendSpan.make(daily: [today], preceding: prior, domain: bounds.start...bounds.end, singleDay: true)
        #expect(spans.map(\.value) == [170])
        #expect(spans.first?.start == bounds.start && spans.first?.end == bounds.end)
        #expect(spans.first?.isReference == false)
    }

    @Test func independentScalesLabelTheActualValuesAndAccommodateOneReading() {
        let body = MeasurementTrendAxis(values: [160, 180])
        let lift = MeasurementTrendAxis(values: [60, 100])
        #expect(body.label(at: body.position(of: 170)) == "170")
        #expect(lift.label(at: lift.position(of: 80)) == "80")

        for value in [0.01, 12.5, 100] {
            let scale = MeasurementTrendAxis(values: [value], upperLimit: 100)
            #expect((0...1).contains(scale.position(of: value)))
            #expect(scale.positions.count >= 2 && scale.positions.last == 1)
            #expect(scale.positions.allSatisfy { $0.isFinite && (0...1).contains($0) })
        }
    }

    @Test func repetitionAxisTicksStayAtWholeValuesAcrossShortRanges() {
        let reps = MeasurementTrendAxis(values: [4, 5], wholeNumbers: true)
        #expect(reps.positions.map { reps.label(at: $0) } == ["4", "5"])
    }
}
