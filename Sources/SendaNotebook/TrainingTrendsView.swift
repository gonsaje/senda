import SwiftUI
import SendaDomain
import SendaLogger

/// Recorded training across the notebook. Opening history preserves the current workout.
public struct TrainingTrendsView: View {
    @Bindable private var model: TrainingNotebookModel
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var showAllBests = false
    @State private var showsAllTimeRecords = false
    @State private var strengthExerciseID: String?

    public init(model: TrainingNotebookModel) {
        self.model = model
    }

    @_spi(Preview) public init(model: TrainingNotebookModel, showsAllTimeRecords: Bool, strengthExerciseID: String? = nil) {
        self.model = model
        _showsAllTimeRecords = State(initialValue: showsAllTimeRecords)
        _strengthExerciseID = State(initialValue: strengthExerciseID)
    }

    public var body: some View {
        let trends = model.snapshot.trends(range: model.progressRange, through: model.today,
            calendar: model.calendar, exercises: model.exercises)
        let hasHistory = !model.snapshot.journal.batches.isEmpty
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heading(hasHistory: hasHistory)
                if hasHistory && showsAllTimeRecords { allTimeRecords }
                window(trends)
                if trends.setCount == 0 {
                    emptyState(trends, hasHistory: hasHistory)
                } else {
                    strengthProgress(trends)
                    performance(trends)
                    if !trends.recentBests.isEmpty { recordedBests(trends) }
                }
                if trends.setCount > 0 {
                    periodSummary(trends)
                    thisWeek(trends)
                    ExerciseProgressFrequencyChart(weeks: trends.weeks, range: trends.range,
                        calendar: model.calendar, title: "Training rhythm")
                }
            }
            .padding(24)
            .padding(.bottom, 12)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .clipped()
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.never)
        .safeAreaInset(edge: .bottom, spacing: 0) { errorRecovery }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .accessibilityIdentifier("trends-scroll")
    }

    private func heading(hasHistory: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            if textSize < .xxxLarge {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    title.fixedSize(horizontal: true, vertical: true)
                    Spacer(minLength: 8)
                    if hasHistory { headerActions.fixedSize(horizontal: true, vertical: true) }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                title
                if hasHistory { headerActions }
            }
        }
    }

    private var headerActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { historyButton; recordsButton }
                .fixedSize(horizontal: true, vertical: true)
            VStack(alignment: .leading, spacing: 0) { historyButton; recordsButton }
        }
    }

    private var title: some View {
        Text("Trends")
            .font(NotebookTypography.heading(31))
            .accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var historyButton: some View {
        Button { model.openProgress() } label: {
            Text("History")
                .font(.body.weight(.medium))
                .foregroundStyle(NotebookStyle.clay)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Browse exercise history")
        .accessibilityIdentifier("trends-history")
    }

    private func window(_ trends: TrainingTrends) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressRangeControl(selection: $model.progressRange, identifierPrefix: "trends-range")
            Text(ProgressFormatting.dateRange(from: trends.startDay, through: trends.endDay, calendar: model.calendar))
                .font(.caption)
                .foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func periodSummary(_ trends: TrainingTrends) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            rule
            Text("\(trends.range.rawValue)-week totals")
                .font(.subheadline.weight(.medium))
            Text("\(trends.trainingDayCount) training \(trends.trainingDayCount == 1 ? "day" : "days") · \(trends.setCount) recorded \(trends.setCount == 1 ? "set" : "sets") · \(trends.activeExerciseCount) \(trends.activeExerciseCount == 1 ? "exercise" : "exercises")")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trends-period-summary")
    }

    private var allTimeRecords: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All-time records")
                .font(NotebookTypography.heading(22, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            TrainingRecordsSection(model: model)
            rule
        }
    }

    private var recordsButton: some View {
        Button { showsAllTimeRecords.toggle() } label: {
            HStack(spacing: 6) {
                Text("Records").font(.body.weight(showsAllTimeRecords ? .semibold : .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: showsAllTimeRecords ? "chevron.up" : "chevron.down")
                    .font(.caption).accessibilityHidden(true)
            }
            .frame(minWidth: 44, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.clay)
        .accessibilityLabel("All-time records")
        .accessibilityValue(showsAllTimeRecords ? "Expanded" : "Collapsed")
        .accessibilityHint("Show or hide personal records for all dates")
        .accessibilityIdentifier("trends-records-toggle")
    }

    private func thisWeek(_ trends: TrainingTrends) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week so far")
                .font(NotebookTypography.heading(22, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            Text(weekCounts(trends.thisWeek))
                .font(.body.weight(.medium).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
            if let lastWeek = trends.lastWeekComparable {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lastWeekLabel)
                        .font(.caption)
                        .foregroundStyle(NotebookStyle.quiet)
                    Text(weekCounts(lastWeek))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(NotebookStyle.quiet)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("trends-this-week")
    }

    private var lastWeekLabel: String {
        model.calendar.component(.weekday, from: model.today.date(in: model.calendar)) == 2
            ? "By Monday last week" : "Same weekdays last week"
    }

    private func weekCounts(_ week: ExerciseProgressWeek) -> String {
        "\(week.trainingDayCount) training \(week.trainingDayCount == 1 ? "day" : "days") · \(week.setCount) \(week.setCount == 1 ? "set" : "sets")"
    }

    @ViewBuilder
    private func strengthProgress(_ trends: TrainingTrends) -> some View {
        if let summary = trends.exerciseSummaries.first(where: { $0.exerciseID == strengthExerciseID })
            ?? trends.exerciseSummaries.first {
            let exercise = model.exercise(summary.exerciseID)
            let feedback = TrainingTrendFeedback.make(comparison: summary.comparison,
                latest: summary.latestSession.bestSet.values, previous: summary.previousSession?.bestSet.values,
                exercise: exercise, unit: model.workspace.preferredUnit)
            VStack(alignment: .leading, spacing: 12) {
                Text("Strength progress")
                    .font(NotebookTypography.heading(22, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                Menu {
                    ForEach(trends.exerciseSummaries) { option in
                        let selected = option.exerciseID == summary.exerciseID
                        let name = model.exercise(option.exerciseID).name
                        Button { strengthExerciseID = option.exerciseID } label: {
                            if selected { Label(name, systemImage: "checkmark") }
                            else { Text(name) }
                        }
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("trends-strength-exercise-\(option.exerciseID)")
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(exercise.name).font(.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down").font(.system(size: 12)).accessibilityHidden(true)
                    }
                    .foregroundStyle(NotebookStyle.clay)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Exercise")
                .accessibilityValue(exercise.name)
                .accessibilityIdentifier("trends-strength-picker")
                ExerciseProgressChart(progress: summary.progress, exercise: exercise,
                    unit: model.workspace.preferredUnit, calendar: model.calendar,
                    heading: nil, explanation: strengthChartExplanation(summary.progress, exercise: exercise),
                    identifier: "trends-strength-chart")
                VStack(alignment: .leading, spacing: 4) {
                    datedSetLabel(summary.latestSession, label: "Latest")
                    Text(ProgressFormatting.set(summary.latestSession.bestSet.values, exercise: exercise,
                        unit: model.workspace.preferredUnit))
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .fixedSize(horizontal: false, vertical: true)
                    if let symbol = feedback.symbol {
                        Label(feedback.text, systemImage: symbol)
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundStyle(feedback.positive ? NotebookStyle.olive : NotebookStyle.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("trends-strength-latest")
                Button { model.openProgress(for: exercise.id) } label: {
                    Text("View history").font(.body.weight(.medium))
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityLabel("View \(exercise.name) history")
                .accessibilityIdentifier("trends-strength-history")
                rule
            }
        }
    }

    private func strengthChartExplanation(_ progress: ExerciseProgress, exercise: Exercise) -> String {
        if progress.sessions.count == 1 {
            return "One recorded day. More training days will add points."
        }
        if progress.metric == .reps {
            return "Best body-weight reps on each recorded day. Lines join observations."
        }
        if !exercise.requiresWeight {
            return "Added weight per recorded day; body-weight sets plot at 0 \(model.workspace.preferredUnit.symbol)."
        }
        return "Each point is a recorded day. Compare reps as well as weight."
    }

    private func performance(_ trends: TrainingTrends) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top-set comparisons")
                .font(NotebookTypography.heading(22, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                rule
                ForEach(trends.exerciseSummaries) { summary in
                    performanceRow(summary)
                    rule
                }
            }
        }
    }

    private func performanceRow(_ summary: ExerciseTrendSummary) -> some View {
        let exercise = model.exercise(summary.exerciseID)
        let feedback = TrainingTrendFeedback.make(comparison: summary.comparison,
            latest: summary.latestSession.bestSet.values,
            previous: summary.previousSession?.bestSet.values,
            exercise: exercise, unit: model.workspace.preferredUnit)
        return Button { model.openProgress(for: exercise.id) } label: {
            VStack(alignment: .leading, spacing: textSize.isAccessibilitySize ? 10 : 6) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(exercise.name)
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    chevron
                }
                if let symbol = feedback.symbol {
                    Label(feedback.text, systemImage: symbol)
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(feedback.positive ? NotebookStyle.olive : NotebookStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(feedback.text)
                        .font(.subheadline)
                        .foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
                datedSets(summary, exercise: exercise)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.vertical, textSize.isAccessibilitySize ? 17 : 12)
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Show exercise history")
        .accessibilityIdentifier("trends-exercise-\(exercise.id)")
    }

    @ViewBuilder
    private func datedSets(_ summary: ExerciseTrendSummary, exercise: Exercise) -> some View {
        if let previous = summary.previousSession {
            if textSize >= .xxxLarge {
                VStack(alignment: .leading, spacing: 10) {
                    datedSet(summary.latestSession, label: "Latest", exercise: exercise)
                    datedSet(previous, label: "Previous", exercise: exercise)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    datedSet(summary.latestSession, label: "Latest", exercise: exercise)
                    datedSet(previous, label: "Previous", exercise: exercise)
                }
            }
        } else {
            datedSet(summary.latestSession, label: "Latest", exercise: exercise)
        }
    }

    private func datedSet(_ session: ExerciseProgressSession, label: String, exercise: Exercise) -> some View {
        ViewThatFits(in: .horizontal) {
            if textSize < .xxxLarge {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    datedSetLabel(session, label: label).fixedSize()
                    Spacer(minLength: 4)
                    datedSetValue(session, exercise: exercise).fixedSize()
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                datedSetLabel(session, label: label)
                datedSetValue(session, exercise: exercise)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func datedSetLabel(_ session: ExerciseProgressSession, label: String) -> some View {
        Text("\(label) · \(date(session.day, format: "MMM d, yyyy"))")
            .font(.caption).foregroundStyle(NotebookStyle.quiet)
            .accessibilityLabel("\(label) top set, \(date(session.day, format: "MMM d, yyyy"))")
    }
    private func datedSetValue(_ session: ExerciseProgressSession, exercise: Exercise) -> some View {
        Text(ProgressFormatting.set(session.bestSet.values, exercise: exercise, unit: model.workspace.preferredUnit))
            .font(.body.monospacedDigit())
    }

    private func recordedBests(_ trends: TrainingTrends) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(NotebookTypography.heading(22, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            Text("Heavier weight, or more reps at the same weight, than an earlier recorded best.")
                .font(.caption)
                .foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                rule
                ForEach(showAllBests ? trends.recentBests : Array(trends.recentBests.prefix(3))) { best in
                    bestRow(best)
                    rule
                }
            }
            if trends.recentBests.count > 3 {
                Button { showAllBests.toggle() } label: {
                    Text(showAllBests ? "Show fewer" : "Show all")
                        .font(.body.weight(.medium))
                        .foregroundStyle(NotebookStyle.clay)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityValue(showAllBests ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("trends-bests-expand")
            }
        }
    }

    private func bestRow(_ best: TrainingTrendBest) -> some View {
        let exercise = model.exercise(best.exerciseID)
        return Button { model.openProgress(for: exercise.id) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.name).font(.body.weight(.semibold))
                    Text(ProgressFormatting.set(best.values, exercise: exercise, unit: model.workspace.preferredUnit))
                        .font(.body.monospacedDigit())
                    Text("Recorded best · \(date(best.day, format: "MMM d, yyyy"))")
                        .font(.caption)
                        .foregroundStyle(NotebookStyle.quiet)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                chevron
            }
            .frame(minHeight: 44)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Show exercise history")
        .accessibilityIdentifier("trends-best-\(best.exerciseID)")
    }

    private func emptyState(_ trends: TrainingTrends, hasHistory: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasHistory ? "No sets in this window" : "No recorded sets")
                .font(NotebookTypography.heading(22, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
            Text(hasHistory
                ? "No sets were recorded in these \(trends.range.rawValue) weeks. Your earlier sets are in History."
                : "Record a set to see your training days and exercise comparisons here.")
                .font(.body)
                .foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
            Button { model.selectSection(.log) } label: {
                Text("Log a set")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(NotebookStyle.clay)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("trends-empty-log")
        }
        .padding(.vertical, 12)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(NotebookStyle.quiet)
            .accessibilityHidden(true)
    }

    private var rule: some View {
        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
    }

    @ViewBuilder
    private var errorRecovery: some View {
        if let message = model.errorMessage {
            Group {
                if model.canRetryProfileAction {
                    ProfileActionError(model: model, message: message)
                } else {
                    TrainingSaveError(model: model, message: message)
                }
            }
            .frame(maxWidth: 552, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(NotebookStyle.ivory)
            .overlay(alignment: .top) { rule }
            .accessibilityIdentifier("trends-error-recovery")
        }
    }

    private func date(_ day: TrainingDay, format: String) -> String {
        ProgressFormatting.date(day, format: format, calendar: model.calendar)
    }
}
