import SwiftUI
import Charts
import SendaDomain

struct ExerciseProgressChart: View {
    let progress: ExerciseProgress
    let exercise: Exercise
    let unit: WeightUnit
    let calendar: Calendar
    @Environment(\.dynamicTypeSize) private var textSize
    private let heading: String?
    private let explanationOverride: String?
    private let identifier: String
    private let selection: Binding<TrainingDay>?
    private let recordDays: Set<TrainingDay>
    @GestureState private var scrubIsHorizontal: Bool?

    init(progress: ExerciseProgress, exercise: Exercise, unit: WeightUnit, calendar: Calendar,
         heading: String? = "Daily top set", explanation: String? = nil, identifier: String = "progress-chart",
         selection: Binding<TrainingDay>? = nil, recordDays: Set<TrainingDay> = []) {
        self.progress = progress; self.exercise = exercise; self.unit = unit; self.calendar = calendar
        self.heading = heading; self.explanationOverride = explanation; self.identifier = identifier
        self.selection = selection; self.recordDays = recordDays
    }

    private var metricTitle: String {
        if progress.metric == .reps { return "Best reps · body weight" }
        return exercise.requiresWeight ? "Top-set load · \(unit.symbol)" : "Added weight · \(unit.symbol)"
    }
    private var maximumValue: Double {
        max(1, progress.sessions.map { value($0.bestSet.values) }.max() ?? 1) * 1.15
    }
    private var yDomain: ClosedRange<Double> {
        guard selection != nil, exercise.requiresWeight, progress.metric == .weight else { return 0...maximumValue }
        let loads = progress.sessions.map { value($0.bestSet.values) }
        guard let low = loads.min(), let high = loads.max() else { return 0...maximumValue }
        let padding = max(1, (high - low) * 0.12, high * 0.025)
        return max(0, floor(low - padding))...ceil(high + padding)
    }

    private var xAxisTicks: AxisMarkValues {
        let largerText = textSize >= .xxLarge
        switch progress.range {
        case .oneMonth:
            return .stride(by: .weekOfYear, count: largerText ? 2 : 1, calendar: calendar)
        case .threeMonths:
            return .stride(by: .month, count: largerText ? 2 : 1, calendar: calendar)
        case .sixMonths:
            return .stride(by: .month, count: largerText ? 3 : 2, calendar: calendar)
        case .oneYear:
            return .stride(by: .month, count: largerText ? 6 : 3, calendar: calendar)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let heading {
                Text(heading).font(NotebookTypography.heading(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            }
            Text(metricTitle).font(.subheadline.weight(.medium)).foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
            chart
            Text(explanation).font(.caption).foregroundStyle(NotebookStyle.quiet)
                .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chart: some View {
        Chart {
            if let day = selection?.wrappedValue {
                RuleMark(x: .value("Selected day", day.date(in: calendar)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(NotebookStyle.quiet.opacity(0.6))
                    .accessibilityHidden(true)
            }
            ForEach(progress.sessions) { session in
                let isRecord = recordDays.contains(session.day)
                let isSelected = selection?.wrappedValue == session.day
                if progress.sessions.count > 1 {
                    LineMark(x: .value("Training day", session.day.date(in: calendar)),
                        y: .value(metricTitle, value(session.bestSet.values)))
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(NotebookStyle.clay)
                        .accessibilityHidden(true)
                }
                PointMark(x: .value("Training day", session.day.date(in: calendar)),
                    y: .value(metricTitle, value(session.bestSet.values)))
                    .symbol(isRecord ? BasicChartSymbolShape.diamond : .circle)
                    .symbolSize(isSelected ? 120 : 46)
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityLabel(ProgressFormatting.date(session.day, format: "MMMM d, yyyy", calendar: calendar)
                        + (isRecord ? ", personal record" : ""))
                    .accessibilityValue(ProgressFormatting.set(session.bestSet.values, exercise: exercise, unit: unit))
            }
        }
        .chartXScale(domain: progress.startDay.date(in: calendar)...progress.endDay.date(in: calendar),
            range: .plotDimension(padding: selection == nil ? 0 : 6))
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: xAxisTicks) { axis in
                AxisGridLine().foregroundStyle(NotebookStyle.rule)
                AxisValueLabel(anchor: axis.index == axis.count - 1 ? .topTrailing : .topLeading) {
                    if let value = axis.as(Date.self) {
                        Text(ProgressFormatting.date(TrainingDay(value, calendar: calendar),
                            format: progress.range == .oneMonth ? "MMM d" : "MMM", calendar: calendar))
                            .foregroundStyle(NotebookStyle.quiet)
                    }
                }
            }
        }
        .chartYAxis {
            if progress.metric == .reps {
                AxisMarks(position: .leading, values: .stride(by: max(1, ceil(maximumValue / 4)))) {
                    AxisGridLine().foregroundStyle(NotebookStyle.rule)
                    AxisValueLabel().foregroundStyle(NotebookStyle.quiet)
                }
            } else {
                AxisMarks(position: .leading) {
                    AxisGridLine().foregroundStyle(NotebookStyle.rule)
                    AxisValueLabel().foregroundStyle(NotebookStyle.quiet)
                }
            }
        }
        .chartOverlay { proxy in
            if let selection, progress.sessions.count > 1 { inspectionOverlay(proxy, selection: selection) }
        }
        .frame(height: 215)
        .padding(.top, 6)
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .accessibilityLabel("Daily top sets for \(exercise.name)")
        .accessibilityIdentifier(identifier)
    }

    private func inspectionOverlay(_ proxy: ChartProxy, selection: Binding<TrainingDay>) -> some View {
        GeometryReader { geometry in
            if let frame = proxy.plotFrame {
                let rect = geometry[frame]
                Color.clear.contentShape(Rectangle())
                    .simultaneousGesture(SpatialTapGesture().onEnded { tap in
                        guard rect.contains(tap.location) else { return }
                        inspect(tap.location, in: rect, proxy: proxy, selection: selection, preferPoint: true)
                    })
                    .simultaneousGesture(DragGesture(minimumDistance: 12)
                        .updating($scrubIsHorizontal) { drag, direction, _ in
                            if direction == nil {
                                direction = abs(drag.translation.width) > abs(drag.translation.height) * 1.25
                            }
                        }
                        .onChanged { drag in
                            let horizontal = scrubIsHorizontal
                                ?? (abs(drag.translation.width) > abs(drag.translation.height) * 1.25)
                            guard horizontal, rect.contains(drag.startLocation) else { return }
                            inspect(drag.location, in: rect, proxy: proxy, selection: selection, preferPoint: false)
                        })
                    .accessibilityHidden(true)
            }
        }
    }

    private func inspect(_ location: CGPoint, in rect: CGRect, proxy: ChartProxy,
                         selection: Binding<TrainingDay>, preferPoint: Bool) {
        let x = location.x - rect.minX, y = location.y - rect.minY
        var nearestDay: TrainingDay?
        var nearestX = CGFloat.infinity
        var nearestPoint: TrainingDay?
        var nearestDistance: CGFloat = 22 * 22
        for session in progress.sessions {
            guard let px = proxy.position(forX: session.day.date(in: calendar)) else { continue }
            let dx = x - px
            if abs(dx) < nearestX {
                nearestX = abs(dx)
                nearestDay = session.day
            }
            if preferPoint, let py = proxy.position(forY: value(session.bestSet.values)) {
                let dy = y - py
                let distance = dx * dx + dy * dy
                if distance < nearestDistance {
                    nearestDistance = distance
                    nearestPoint = session.day
                }
            }
        }
        if let day = nearestPoint ?? nearestDay, selection.wrappedValue != day {
            selection.wrappedValue = day
        }
    }

    private var explanation: String {
        if let explanationOverride { return explanationOverride }
        let observation = progress.sessions.count == 1
            ? "One recorded day in this window. More training days will add points to the chart."
            : "Each point is a recorded day. Straight lines join observed top sets; days between them have no plotted result."
        if progress.metric == .reps {
            return "\(observation) All sets in this window used body weight, so the chart shows the most reps each day."
        }
        if !exercise.requiresWeight {
            return "\(observation) Only added weight is plotted; body-weight sets are shown at 0 \(unit.symbol). Reps remain listed with each top set below."
        }
        return "\(observation) Top sets use the heaviest load, then reps. Read the rep counts with the loads in the recorded days below."
    }
    private func value(_ values: SetValues) -> Double {
        progress.metric == .reps ? Double(values.reps) : NSDecimalNumber(decimal: unit.amount(for: values.weight)).doubleValue
    }
}

struct ExerciseProgressFrequencyChart: View {
    let weeks: [ExerciseProgressWeek]
    let title: String
    let calendar: Calendar
    @State private var showsCounts = false
    @Environment(\.dynamicTypeSize) private var textSize

    init(progress: ExerciseProgress, calendar: Calendar) {
        self.init(weeks: progress.weeks, calendar: calendar)
    }

    init(weeks: [ExerciseProgressWeek], calendar: Calendar, title: String = "Training rhythm") {
        self.weeks = weeks
        self.calendar = calendar
        self.title = title
    }

    private var tickWeekIDs: [String] {
        let maxTicks = textSize >= .xxLarge ? 2 : 4
        let step = max(1, (weeks.count + maxTicks - 1) / maxTicks)
        return weeks.indices.filter { $0 % step == 0 }.map { weeks[$0].id }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(NotebookTypography.heading(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            Text("Training days each week").font(.subheadline.weight(.medium)).foregroundStyle(NotebookStyle.quiet)
            Chart(weeks) { week in
                // Proportional bar width needs category bands; a continuous index has no scale step.
                BarMark(x: .value("Week", week.id), y: .value("Training days", week.trainingDayCount), width: .ratio(0.62))
                    .foregroundStyle(NotebookStyle.olive)
                    .cornerRadius(2)
                    .accessibilityLabel(weekLabel(week))
                    .accessibilityValue("\(week.trainingDayCount) training days, \(week.setCount) recorded sets")
            }
            .chartXScale(domain: weeks.map(\.id))
            .chartYScale(domain: 0...max(1, weeks.map(\.trainingDayCount).max() ?? 1))
            .chartXAxis {
                AxisMarks(values: tickWeekIDs) { axis in
                    AxisValueLabel {
                        if let id = axis.as(String.self), let week = weeks.first(where: { $0.id == id }) {
                            Text(ProgressFormatting.date(week.startDay,
                                format: weeks.count > 16 ? "MMM" : "MMM d", calendar: calendar))
                                .foregroundStyle(NotebookStyle.quiet)
                                .fixedSize()
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 1)) {
                    AxisGridLine().foregroundStyle(NotebookStyle.rule)
                    AxisValueLabel().foregroundStyle(NotebookStyle.quiet)
                }
            }
            .frame(height: 140)
            .environment(\.calendar, calendar)
            .environment(\.timeZone, calendar.timeZone)
            .accessibilityLabel("Weekly training days, including weeks with no recorded sets")
            Text("Weeks start on Monday. Counts include only dates in this range.")
                .font(.caption).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
            DisclosureGroup(isExpanded: $showsCounts) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(weeks) { week in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(weekLabel(week)).font(.caption.weight(.medium))
                            Text("\(week.trainingDayCount) training \(week.trainingDayCount == 1 ? "day" : "days") · \(week.setCount) \(week.setCount == 1 ? "set" : "sets")")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                    }
                }.padding(.top, 10)
            } label: {
                Text("Weekly counts").font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
        }
    }
    private func weekLabel(_ week: ExerciseProgressWeek) -> String {
        "\(ProgressFormatting.date(week.startDay, format: "MMM d, yyyy", calendar: calendar)) – \(ProgressFormatting.date(week.endDay, format: "MMM d, yyyy", calendar: calendar))"
    }
}
