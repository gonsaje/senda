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

    init(progress: ExerciseProgress, exercise: Exercise, unit: WeightUnit, calendar: Calendar,
         heading: String? = "Daily top set", explanation: String? = nil, identifier: String = "progress-chart") {
        self.progress = progress; self.exercise = exercise; self.unit = unit; self.calendar = calendar
        self.heading = heading; self.explanationOverride = explanation; self.identifier = identifier
    }

    private var metricTitle: String {
        if progress.metric == .reps { return "Best reps · body weight" }
        return exercise.requiresWeight ? "Top-set load · \(unit.symbol)" : "Added weight · \(unit.symbol)"
    }
    private var maximumValue: Double {
        max(1, progress.sessions.map { value($0.bestSet.values) }.max() ?? 1) * 1.15
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let heading {
                Text(heading).font(NotebookTypography.heading(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            }
            Text(metricTitle).font(.subheadline.weight(.medium)).foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
            Chart(progress.sessions) { session in
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
                    .symbolSize(46)
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityLabel(ProgressFormatting.date(session.day, format: "MMMM d, yyyy", calendar: calendar))
                    .accessibilityValue(ProgressFormatting.set(session.bestSet.values, exercise: exercise, unit: unit))
            }
            .chartXScale(domain: progress.startDay.date(in: calendar)...progress.endDay.date(in: calendar))
            .chartYScale(domain: 0...maximumValue)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: textSize.isAccessibilitySize
                    ? progress.range.rawValue / 2 : (progress.range == .twelveWeeks ? 3 : 2))) { axis in
                    AxisGridLine().foregroundStyle(NotebookStyle.rule)
                    AxisValueLabel {
                        if let value = axis.as(Date.self) {
                            Text(ProgressFormatting.date(TrainingDay(value, calendar: calendar), format: "MMM d", calendar: calendar))
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
            .frame(height: 215)
            .padding(.top, 6)
            .environment(\.calendar, calendar)
            .environment(\.timeZone, calendar.timeZone)
            .accessibilityLabel("Daily top sets for \(exercise.name)")
            .accessibilityIdentifier(identifier)
            Text(explanation).font(.caption).foregroundStyle(NotebookStyle.quiet)
                .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
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
    let range: ExerciseProgressRange
    let title: String
    let calendar: Calendar
    @State private var showsCounts = false
    @Environment(\.dynamicTypeSize) private var textSize

    init(progress: ExerciseProgress, calendar: Calendar) {
        self.init(weeks: progress.weeks, range: progress.range, calendar: calendar)
    }

    init(weeks: [ExerciseProgressWeek], range: ExerciseProgressRange, calendar: Calendar, title: String = "Training rhythm") {
        self.weeks = weeks
        self.range = range
        self.calendar = calendar
        self.title = title
    }

    private var tickWeekIDs: [String] {
        let step = textSize.isAccessibilitySize ? range.rawValue / 2 : (range == .twelveWeeks ? 3 : 2)
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
                            Text(ProgressFormatting.date(week.startDay, format: "MMM d", calendar: calendar))
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
            Text("Weeks start on Monday. The current week runs through today; weeks without recorded sets count as zero.")
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
