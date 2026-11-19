import Charts
import SwiftUI
import SendaDomain

struct BodyMeasurementTrendChart: View {
    let metric: BodyMetric
    /// Measurements are ordered newest first, as returned by BodyMeasurementsModel.
    let readings: [BodyMeasurement]
    let days: ClosedRange<TrainingDay>
    let comparison: ExerciseProgress?
    let exercise: Exercise?
    let unit: WeightUnit
    let calendar: Calendar
    @Environment(\.dynamicTypeSize) private var textSize

    private struct Sample: Identifiable {
        var id: TrainingDay { day }
        let day: TrainingDay
        let date: Date
        let value: Double
        let spokenValue: String
    }

    private var measurementSamples: [Sample] {
        var seen: Set<TrainingDay> = []
        return readings.compactMap { reading in
            let day = TrainingDay(reading.displayDate(in: calendar), calendar: calendar)
            guard reading.metric == metric, days.contains(day), seen.insert(day).inserted else { return nil }
            return Sample(day: day, date: day.date(in: calendar), value: metric.displayValue(reading.value, unit: unit),
                          spokenValue: metric.formattedValue(reading.value, unit: unit))
        }.reversed()
    }

    private var strengthSamples: [Sample] {
        guard let comparison, let exercise else { return [] }
        return comparison.sessions.compactMap { session in
            guard days.contains(session.day) else { return nil }
            let set = session.bestSet.values
            let amount = comparison.metric == .reps ? Double(set.reps) : NSDecimalNumber(decimal: unit.amount(for: set.weight)).doubleValue
            return Sample(day: session.day, date: session.day.date(in: calendar), value: amount,
                          spokenValue: ProgressFormatting.set(set, exercise: exercise, unit: unit))
        }
    }

    private var strengthTitle: String {
        let name = exercise?.displayName ?? "Top set"
        return "\(name) · \(comparison?.metric == .reps ? "reps" : unit.symbol)"
    }

    var body: some View {
        let bodySamples = measurementSamples, strength = strengthSamples
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    if !bodySamples.isEmpty { seriesLabel(strength: false).fixedSize(horizontal: true, vertical: false) }
                    if !bodySamples.isEmpty && !strength.isEmpty { Spacer(minLength: 0) }
                    if !strength.isEmpty { seriesLabel(strength: true).fixedSize(horizontal: true, vertical: false) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    if !bodySamples.isEmpty { seriesLabel(strength: false) }
                    if !strength.isEmpty { seriesLabel(strength: true) }
                }
            }
            chart(bodySamples, strength)
            if bodySamples.count < readings.count {
                Text("Latest reading per day").font(.caption).foregroundStyle(NotebookStyle.quiet)
            }
        }
    }

    private func seriesLabel(strength: Bool) -> some View {
        Label {
            Text(strength ? strengthTitle : "\(metric.title) · \(metric.symbol(unit: unit))")
                .foregroundStyle(NotebookStyle.ink).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: strength ? "diamond.fill" : "circle.fill")
                .font(.caption2).foregroundStyle(strength ? NotebookStyle.olive : NotebookStyle.clay)
        }
        .font(.caption.weight(.medium))
    }

    private func chart(_ bodySamples: [Sample], _ strength: [Sample]) -> some View {
        let sharedWeightAxis = metric == .weight && comparison?.metric == .weight && !bodySamples.isEmpty && !strength.isEmpty
        let bodyValues = bodySamples.map(\.value)
        let strengthValues = strength.map(\.value)
        let bodyScale = MeasurementTrendAxis(values: sharedWeightAxis ? bodyValues + strengthValues : bodyValues,
                                            upperLimit: metric == .bodyFat ? 100 : nil)
        let strengthScale = sharedWeightAxis ? bodyScale : MeasurementTrendAxis(values: strengthValues, wholeNumbers: comparison?.metric == .reps)
        var titles: [String] = []
        if !bodySamples.isEmpty { titles.append(metric.title) }
        if !strength.isEmpty, let exercise { titles.append("\(exercise.displayName) top sets") }
        return Chart {
            marks(bodySamples, scale: bodyScale, strength: false)
            marks(strength, scale: strengthScale, strength: true)
        }
        .chartYScale(domain: 0.0...1.0)
        .chartXScale(domain: dateDomain, range: .plotDimension(padding: 5))
        .chartXAxis {
            AxisMarks(values: dateTicks) { mark in
                AxisValueLabel(anchor: mark.index == 0 ? .topLeading : mark.index == mark.count - 1 ? .topTrailing : .top) {
                    if let date = mark.as(Date.self) {
                        Text(ProgressFormatting.date(TrainingDay(date, calendar: calendar), format: dateFormat, calendar: calendar))
                            .foregroundStyle(NotebookStyle.quiet)
                    }
                }
            }
        }
        .chartYAxis {
            if !bodySamples.isEmpty {
                AxisMarks(position: .leading, values: bodyScale.positions) { mark in
                    AxisGridLine().foregroundStyle(NotebookStyle.rule)
                    if let position = mark.as(Double.self) {
                        AxisValueLabel { Text(bodyScale.label(at: position)).foregroundStyle(sharedWeightAxis ? NotebookStyle.quiet : NotebookStyle.clay) }
                    }
                }
            }
            if !strength.isEmpty && !sharedWeightAxis {
                AxisMarks(position: bodySamples.isEmpty ? .leading : .trailing, values: strengthScale.positions) { mark in
                    if bodySamples.isEmpty { AxisGridLine().foregroundStyle(NotebookStyle.rule) }
                    if let position = mark.as(Double.self) {
                        AxisValueLabel { Text(strengthScale.label(at: position)).foregroundStyle(NotebookStyle.olive) }
                    }
                }
            }
        }
        .frame(height: textSize.isAccessibilitySize ? 215 : 175)
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .accessibilityLabel(titles.joined(separator: " and "))
        .accessibilityIdentifier("body-measurements-chart")
    }

    @ChartContentBuilder private func marks(_ samples: [Sample], scale: MeasurementTrendAxis, strength: Bool) -> some ChartContent {
        let title = strength ? strengthTitle : metric.title
        let color = strength ? NotebookStyle.olive : NotebookStyle.clay
        ForEach(samples) { sample in
            if samples.count > 1 {
                LineMark(x: .value("Date", sample.date), y: .value(title, scale.position(of: sample.value)),
                         series: .value("Series", strength ? "Top set" : "Measurement"))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: strength ? [5, 3] : []))
                    .foregroundStyle(color).accessibilityHidden(true)
            }
            PointMark(x: .value("Date", sample.date), y: .value(title, scale.position(of: sample.value)))
                .symbol(strength ? BasicChartSymbolShape.diamond : .circle)
                .symbolSize(32).foregroundStyle(color)
                .accessibilityLabel("\(title), \(ProgressFormatting.date(sample.day, format: "MMMM d, yyyy", calendar: calendar))")
                .accessibilityValue(sample.spokenValue)
        }
    }

    private var dateDomain: ClosedRange<Date> {
        let start = days.lowerBound.date(in: calendar), end = days.upperBound.date(in: calendar)
        if start == end, let interval = calendar.dateInterval(of: .day, for: start) { return interval.start...interval.end }
        return start...end
    }

    private var dateTicks: [Date] {
        let start = days.lowerBound.date(in: calendar), end = days.upperBound.date(in: calendar)
        if start == end { return [start] }
        let span = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        guard span >= 2, textSize < .xxLarge, let middle = calendar.date(byAdding: .day, value: span / 2, to: start) else { return [start, end] }
        return [start, middle, end]
    }

    private var dateFormat: String { dateDomain.upperBound.timeIntervalSince(dateDomain.lowerBound) > 365 * 86_400 ? "MMM yy" : "MMM d" }
}

/// Charts shares one plot area. Each side maps its labeled real units onto that area's height.
struct MeasurementTrendAxis {
    private let lower: Double
    private let upper: Double
    private let step: Double

    init(values: [Double], upperLimit: Double? = nil, wholeNumbers: Bool = false) {
        let low = values.min() ?? 0, high = values.max() ?? low
        let span = high == low ? max(1, high * 0.05) : high - low
        let target = max(wholeNumbers ? 1 : 0.01, span / 3)
        let power = pow(10.0, floor(log10(target)))
        let increment = ([1.0, 2, 5, 10].first { $0 * power >= target } ?? 10) * power
        self.step = increment
        let bottom = max(0, floor(low / increment) * increment - (low == high ? increment : 0))
        let top = ceil(high / increment) * increment + (low == high ? increment : 0)
        self.lower = bottom
        self.upper = min(upperLimit ?? .infinity, max(bottom + increment, top))
    }

    func position(of value: Double) -> Double { (value - lower) / (upper - lower) }
    var positions: [Double] {
        var result = stride(from: lower, to: upper - step * 0.001, by: step).map(position(of:))
        result.append(1)
        return result
    }
    func label(at position: Double) -> String {
        (lower + position * (upper - lower)).formatted(.number.precision(.fractionLength(0...2)))
    }
}
