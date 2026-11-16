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
    @ScaledMetric(relativeTo: .caption) private var weekdayWidth: CGFloat = 27
    @ScaledMetric(relativeTo: .title3) private var dateColumnWidth: CGFloat = 67
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let week = model.weekDays
        let training = model.snapshot.weeklyMuscleTraining(days: week, through: model.today, calendar: model.calendar)
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TrainingWeekNavigation(model: model, week: week, training: training,
                    showCalendar: { sheet = .calendar }, showMuscles: { sheet = .muscles })
                VStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        dayRow(day)
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                            .accessibilityHidden(true)
                    }
                }
                if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .disabled(swipe.isHorizontal)
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
        .background(NotebookStyle.ivory).accessibilityIdentifier("week-view")
    }

    private func dayRow(_ day: TrainingDay) -> some View {
        let summary = model.summary(for: day)
        let unfinished = model.unfinishedSetCount(for: day)
        let isToday = day == model.today
        let action = unfinished > 0 ? "Continue workout" : "Add workout"
        let date = TrainingText.date(day, format: "EEEE, MMM d, yyyy")
        let dateLabel = isToday ? "Today, \(date)" : date
        let setLabel = "\(summary.setCount) \(summary.setCount == 1 ? "set" : "sets")"
        let needsValues = "\(unfinished) \(unfinished == 1 ? "set needs" : "sets need") values"
        let detail = (summary.exercises.isEmpty ? [action] : summary.exercises) +
            (unfinished > 0 ? (summary.exercises.isEmpty ? [needsValues] : [needsValues, action]) : [])
        let rowLayout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return Button { model.openDay(day) } label: {
            rowLayout {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(TrainingText.date(day, format: "EEE"))
                        .font(.caption.weight(.semibold))
                        .frame(width: textSize.isAccessibilitySize ? nil : weekdayWidth, alignment: .leading)
                    Text(TrainingText.date(day, format: "d"))
                        .font(NotebookTypography.heading(22, relativeTo: .title3))
                        .monospacedDigit()
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: textSize.isAccessibilitySize ? nil : dateColumnWidth, alignment: .leading)
                .foregroundStyle(isToday ? NotebookStyle.clay : NotebookStyle.ink)
                VStack(alignment: .leading, spacing: 2) {
                    if let primaryLift = summary.exercises.first {
                        Text(primaryLift).font(.subheadline.weight(.semibold))
                            .lineLimit(textSize.isAccessibilitySize ? nil : 1)
                        if summary.exercises.count > 1 {
                            let secondary = summary.exercises[1]
                            Text(summary.exercises.count > 2 ? "\(secondary) +\(summary.exercises.count - 2)" : secondary)
                                .font(.caption).foregroundStyle(NotebookStyle.quiet)
                                .lineLimit(textSize.isAccessibilitySize ? nil : 1)
                        }
                    } else {
                        Label(action, systemImage: unfinished > 0 ? "pencil" : "plus")
                            .font(.subheadline)
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
                        Text("\(summary.setCount)").font(.subheadline.weight(.semibold).monospacedDigit())
                        Text(summary.setCount == 1 ? "set" : "sets").font(.caption)
                            .foregroundStyle(NotebookStyle.quiet)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, textSize.isAccessibilitySize ? 10 : 4)
            .frame(minHeight: 54)
            .background(isToday ? NotebookStyle.clay.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .accessibilityLabel(([dateLabel, setLabel] + detail).joined(separator: ", "))
        .accessibilityIdentifier("day-\(day.rawValue)")
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
