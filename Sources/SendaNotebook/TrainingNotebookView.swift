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
            switch model.section {
            case .log:
                if let day = model.selectedDay { TrainingDayView(model: model, day: day) }
                else { TrainingWeekView(model: model) }
            case .trends: TrainingTrendsView(model: model)
            case .learn: TrainingLearnView(model: model)
            case .profile: TrainingProfileView(model: model)
            }
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
    @Bindable var model: TrainingNotebookModel
    @State private var swipe = WeekSwipeState()
    @GestureState private var dragging = false
    @ScaledMetric(relativeTo: .title3) private var dateColumnWidth: CGFloat = 50
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 18) {
                    TrainingWordmark()
                    TrainingWeekNavigation(model: model)
                }
                VStack(spacing: 0) {
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    ForEach(model.weekDays, id: \.self) { day in
                        let summary = model.summary(for: day)
                        let categories = summary.muscleGroups.map(\.rawValue)
                        let unfinished = model.unfinishedSetCount(for: day)
                        let emphasizedAction = day == model.today || unfinished > 0
                        let needsValues = unfinished > 0 ? ", \(unfinished) \(unfinished == 1 ? "set needs" : "sets need") values" : ""
                        Button { model.openDay(day) } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(TrainingText.date(day, format: "EEE")).font(.title3.weight(.medium))
                                    Text(TrainingText.date(day, format: "d")).font(.title3.monospacedDigit())
                                }.frame(width: dateColumnWidth, alignment: .leading)
                                    .foregroundStyle(day == model.today ? NotebookStyle.clay : NotebookStyle.ink)
                                VStack(alignment: .leading, spacing: 4) {
                                    if summary.setCount == 0 {
                                        Label(unfinished > 0 ? "Continue workout" : "Start workout", systemImage: unfinished > 0 ? "pencil" : "plus")
                                            .font(emphasizedAction ? .title3 : .body)
                                            .foregroundStyle(emphasizedAction ? NotebookStyle.clay : NotebookStyle.quiet)
                                    } else { Text(categories.joined(separator: " · ")).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true) }
                                    if unfinished > 0 {
                                        Text("\(unfinished) \(unfinished == 1 ? "set needs" : "sets need") values\(summary.setCount > 0 ? " · Continue" : "")")
                                            .font(.body).foregroundStyle(NotebookStyle.clay)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .accessibilityIdentifier("day-\(day.rawValue)-unfinished")
                                    }
                                    if day == model.today { Text("Today").font(.body.weight(.medium)).foregroundStyle(NotebookStyle.clay) }
                                    if textSize.isAccessibilitySize && summary.setCount > 0 {
                                        Text("\(summary.setCount) \(summary.setCount == 1 ? "set" : "sets")").font(.body.monospacedDigit())
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                if !textSize.isAccessibilitySize && summary.setCount > 0 {
                                    Text("\(summary.setCount) \(summary.setCount == 1 ? "set" : "sets")").font(.body.monospacedDigit()).fixedSize()
                                }
                            }
                            .padding(.vertical, textSize.isAccessibilitySize ? 16 : 8)
                            .padding(.horizontal, 8).frame(minHeight: textSize.isAccessibilitySize ? 76 : 64)
                            .background(day == model.today ? NotebookStyle.clay.opacity(0.06) : .clear)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("\(TrainingText.date(day, format: "EEEE, MMM d, yyyy")), \(summary.setCount) \(summary.setCount == 1 ? "set" : "sets")\(needsValues), \(unfinished > 0 ? "Continue workout" : summary.setCount == 0 ? "Start workout" : categories.joined(separator: ", "))")
                        .accessibilityIdentifier("day-\(day.rawValue)")
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    }
                }
                Text("\(model.trainingDayCount) training \(model.trainingDayCount == 1 ? "day" : "days") · \(model.weekSetCount) \(model.weekSetCount == 1 ? "set" : "sets")")
                    .font(.body).foregroundStyle(NotebookStyle.quiet).accessibilityIdentifier("week-summary")
                if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
            }
            .padding(.horizontal, 24).padding(.vertical, 24).frame(maxWidth: 560).frame(maxWidth: .infinity)
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
        .background(NotebookStyle.ivory).accessibilityIdentifier("week-view")
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
