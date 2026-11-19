import Testing
@testable import SendaNotebook

struct BodyMeasurementTrendChartTests {
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
