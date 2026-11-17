import SwiftUI
import SendaDomain
import SendaLogger
#if canImport(UIKit)
import UIKit
#endif

public struct TrainingNotebookView: View {
    @Bindable private var model: TrainingNotebookModel
    public init(model: TrainingNotebookModel) { self.model = model }
    public var body: some View {
        Group {
            if model.backupRecoveryRequired {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Finish restoring your notebook").font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                        Text(model.backupErrorMessage ?? "Your original files need to be recovered before continuing.")
                        Button("Try recovery again") { model.retryBackupRecovery() }
                            .frame(minHeight: 44).accessibilityIdentifier("retry-backup-recovery")
                    }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }.accessibilityIdentifier("backup-recovery-screen")
            } else {
                TrainingNotebookPages(model: model)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.hasHistoryReturnContext && model.section == .log {
                Button { model.returnToWorkoutFromHistory() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.historyReturnsToWeek ? "Return to week" : "Return to workout")
                                .font(.subheadline.weight(.medium))
                            if let day = model.selectedDay {
                                Text("Editing \(TrainingText.date(day, format: "MMM d, yyyy"))")
                                    .font(.caption).foregroundStyle(NotebookStyle.quiet)
                            }
                        }.fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 24).contentShape(Rectangle())
                }
                .background(NotebookStyle.ivory)
                .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
                .accessibilityIdentifier("history-return-workout")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { if !model.backupRecoveryRequired { TrainingDock(model: model) } }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .scrollIndicators(.never)
        .tint(NotebookStyle.clay).buttonStyle(.plain)
        .sheet(isPresented: $model.isProgressPresented, onDismiss: { model.progressSheetDidDismiss() }) {
            TrainingProgressView(model: model, close: { model.dismissProgress() })
        }
        .onChange(of: model.errorMessage) { _, message in
            if let message { TrainingAccessibility.announce("Could not save. \(message)") }
        }
    }
}

enum TrainingText {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    static func date(_ day: TrainingDay, format: String, locale: Locale = .current) -> String {
        let formatter = DateFormatter(); formatter.locale = locale; formatter.calendar = utc; formatter.timeZone = utc.timeZone
        formatter.dateFormat = format
        return formatter.string(from: day.date(in: utc))
    }
    static func weekMonths(first: TrainingDay, last: TrainingDay, abbreviated: Bool, locale: Locale = .current) -> String {
        let month = abbreviated ? "LLL" : "LLLL"
        if first.rawValue.prefix(7) == last.rawValue.prefix(7) {
            return date(first, format: month, locale: locale)
        }
        return date(first, format: month, locale: locale) + " – " + date(last, format: month, locale: locale)
    }
    static func set(_ values: SetValues, unit: WeightUnit) -> String { "\(unit.text(for: values.weight)) \(unit.symbol) × \(values.reps)" }
}

struct TrainingWeekView: View {
    private enum Sheet: String, Identifiable {
        case calendar, muscles
        var id: Self { self }
    }

    @Bindable var model: TrainingNotebookModel
    @State private var swipe = WeekSwipeState()
    @State private var sheet: Sheet?
    @GestureState private var dragging = false
    @ScaledMetric(relativeTo: .title3) private var dateColumnWidth: CGFloat = 67
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let week = model.weekDays
        let weekdayLabels = week.map { TrainingText.date($0, format: "EEE") }
        let training = model.snapshot.weeklyMuscleTraining(days: week, through: model.today, calendar: model.calendar)
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    TrainingWeekLayout(availableHeight: viewport.size.height - 30, expandsRows: !textSize.isAccessibilitySize) {
                        TrainingWeekNavigation(model: model, week: week, training: training,
                            showCalendar: { sheet = .calendar }, showMuscles: { sheet = .muscles })
                        ForEach(week, id: \.self) { day in
                            dayRow(day, weekdayLabels: weekdayLabels)
                        }
                    }
                    if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
                }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 20)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .disabled(swipe.isHorizontal)
            }
            .accessibilityIdentifier("week-view")
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 16)
            .updating($dragging) { _, active, _ in active = true }
            .onChanged { value in swipe.move(value.translation) }
            .onEnded { value in
                if let direction = swipe.finish(value.translation) { model.changeWeek(direction) }
            })
        .onChange(of: dragging) { _, active in
            if !active {
                Task { @MainActor in
                    // Ended gestures settle first; cancelled drags only reset controls.
                    await Task.yield()
                    if !dragging { swipe.cancel() }
                }
            }
        }
        .onDisappear { swipe.cancel() }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .calendar:
                TrainingMonthCalendar(model: model,
                    initialDay: week.contains(model.today) ? model.today : model.workspace.visibleWeek)
            case .muscles:
                TrainingWeekMusclesView(training: training, targets: model.profile.details.weeklyMuscleTargets,
                    exerciseName: { model.exercise($0).name })
            }
        }
        .background(NotebookStyle.ivory)
    }

    private func dayRow(_ day: TrainingDay, weekdayLabels: [String]) -> some View {
        let summary = model.summary(for: day)
        let bodyParts = summary.muscleGroups.map(\.rawValue)
        let unfinished = model.unfinishedSetCount(for: day)
        let isToday = day == model.today
        let action = unfinished > 0 ? "Continue workout" : "Add workout"
        let date = TrainingText.date(day, format: "EEEE, MMM d, yyyy")
        let dateLabel = isToday ? "Today, \(date)" : date
        let setLabel = "\(summary.setCount) \(summary.setCount == 1 ? "set" : "sets")"
        let needsValues = "\(unfinished) \(unfinished == 1 ? "set needs" : "sets need") values"
        let detail = (bodyParts.isEmpty ? [action] : bodyParts) +
            (unfinished > 0 ? (bodyParts.isEmpty ? [needsValues] : [needsValues, action]) : [])
        let rowLayout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return Button { model.openDay(day) } label: {
            rowLayout {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    ZStack(alignment: .leading) {
                        if !textSize.isAccessibilitySize {
                            // Reserve the widest weekday so dates align in every row.
                            ForEach(weekdayLabels.indices, id: \.self) { index in
                                Text(weekdayLabels[index]).hidden()
                            }
                        }
                        Text(TrainingText.date(day, format: "EEE"))
                    }
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    ZStack(alignment: .leading) {
                        if !textSize.isAccessibilitySize {
                            Text(TrainingText.date(day, format: "dd")).hidden()
                        }
                        Text(TrainingText.date(day, format: "d"))
                    }
                    .font(NotebookTypography.heading(25, relativeTo: .title3))
                    .monospacedDigit()
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: textSize.isAccessibilitySize ? nil : dateColumnWidth, alignment: .leading)
                .foregroundStyle(isToday ? NotebookStyle.clay : NotebookStyle.ink)
                VStack(alignment: .leading, spacing: 2) {
                    if let primary = bodyParts.first {
                        Text(primary).font(.callout.weight(.semibold))
                            .lineLimit(textSize.isAccessibilitySize ? nil : 1)
                        let remaining = bodyParts.dropFirst()
                        if let secondary = remaining.first {
                            let names = remaining.joined(separator: " · ")
                            Group {
                                if textSize.isAccessibilitySize {
                                    Text(names)
                                } else {
                                    ViewThatFits(in: .horizontal) {
                                        Text(names).fixedSize(horizontal: true, vertical: false)
                                        Text(remaining.count > 1 ? "\(secondary) +\(remaining.count - 1)" : secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .font(.caption).foregroundStyle(NotebookStyle.quiet)
                        }
                    } else {
                        Label(action, systemImage: unfinished > 0 ? "pencil" : "plus")
                            .font(.callout)
                            .foregroundStyle(unfinished > 0 ? NotebookStyle.clay : NotebookStyle.quiet)
                    }
                    if unfinished > 0 {
                        Text(summary.setCount > 0 ? "\(needsValues) · Continue" : needsValues)
                            .font(.caption).foregroundStyle(NotebookStyle.clay)
                            .accessibilityIdentifier("day-\(day.rawValue)-unfinished")
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                if summary.setCount > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(summary.setCount)").font(.callout.weight(.semibold).monospacedDigit())
                        Text(summary.setCount == 1 ? "set" : "sets").font(.caption)
                            .foregroundStyle(NotebookStyle.quiet)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, textSize.isAccessibilitySize ? 10 : 3)
            .frame(minHeight: 54, maxHeight: .infinity)
            .background(isToday ? NotebookStyle.clay.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .accessibilityLabel(([dateLabel, setLabel] + detail).joined(separator: ", "))
        .accessibilityIdentifier("day-\(day.rawValue)")
    }
}

private struct TrainingWeekLayout: Layout {
    let availableHeight: CGFloat
    let expandsRows: Bool
    private let headerSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = sizes(for: proposal.width, subviews: subviews)
        return CGSize(
            width: proposal.width ?? sizes.map(\.width).max() ?? 0,
            height: sizes.reduce(0) { $0 + $1.height } + (sizes.count > 1 ? headerSpacing : 0)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = sizes(for: bounds.width, subviews: subviews)
        var top = bounds.minY
        for (index, pair) in zip(subviews, sizes).enumerated() {
            let (subview, size) = pair
            subview.place(at: CGPoint(x: bounds.midX, y: top), anchor: .top,
                proposal: ProposedViewSize(width: bounds.width, height: size.height))
            top += size.height + (index == 0 ? headerSpacing : 0)
        }
    }

    private func sizes(for width: CGFloat?, subviews: Subviews) -> [CGSize] {
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        guard expandsRows, let header = sizes.first, sizes.count > 1 else { return sizes }
        let days = sizes.dropFirst()
        let fittingHeight = floor((availableHeight - header.height - headerSpacing) / CGFloat(days.count))
        let rowHeight = max(days.map(\.height).max() ?? 54, min(72, fittingHeight))
        return [header] + days.map { CGSize(width: $0.width, height: rowHeight) }
    }
}

struct TrainingSaveError: View {
    var model: TrainingNotebookModel
    let message: String
    var retrySucceeded: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message).font(.callout).foregroundStyle(NotebookStyle.clay)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("save-error-message")
            if model.canRetrySave {
                Button("Try again") {
                    if model.retrySave() { retrySucceeded?(); TrainingAccessibility.announce("Changes saved.") }
                    else { TrainingAccessibility.announce("Still unable to save. \(model.errorMessage ?? message)") }
                }
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                .accessibilityHint("Retry the action that could not be saved")
                .accessibilityIdentifier("retry-save")
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("save-error")
    }
}

enum TrainingAccessibility {
    @MainActor static func announce(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}
