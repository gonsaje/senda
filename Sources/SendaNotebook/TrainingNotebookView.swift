import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingNotebookView: View {
    @Bindable private var model: TrainingNotebookModel
    public init(model: TrainingNotebookModel) { self.model = model }
    public var body: some View {
        Group {
            switch model.section {
            case .log:
                if let day = model.selectedDay { TrainingDayView(model: model, day: day) }
                else { TrainingWeekView(model: model) }
            case .learn: TrainingLearnView(model: model)
            case .profile: TrainingProfileView(model: model)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { TrainingDock(model: model) }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .scrollIndicators(.never)
        .tint(NotebookStyle.clay).buttonStyle(.plain)
    }
}

enum TrainingText {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    static func date(_ day: TrainingDay, format: String, locale: Locale = .current) -> String {
        let formatter = DateFormatter(); formatter.locale = locale; formatter.calendar = utc; formatter.timeZone = utc.timeZone
        formatter.dateFormat = format
        return formatter.string(from: day.date(in: utc))
    }
    static func weekMonths(first: TrainingDay, last: TrainingDay, today: TrainingDay, abbreviated: Bool, locale: Locale = .current) -> String {
        let month = abbreviated ? "LLL" : "LLLL"
        let firstYear = first.rawValue.prefix(4), lastYear = last.rawValue.prefix(4)
        if first.rawValue.prefix(7) == last.rawValue.prefix(7) {
            return date(first, format: month + (firstYear == today.rawValue.prefix(4) ? "" : " yyyy"), locale: locale)
        }
        if firstYear == lastYear {
            return date(first, format: month, locale: locale) + " – " + date(last, format: month + (lastYear == today.rawValue.prefix(4) ? "" : " yyyy"), locale: locale)
        }
        return date(first, format: month + " yyyy", locale: locale) + " – " + date(last, format: month + " yyyy", locale: locale)
    }
    static func set(_ values: SetValues, unit: WeightUnit) -> String { "\(unit.text(for: values.weight)) \(unit.symbol) × \(values.reps)" }
}

struct TrainingWeekView: View {
    @Bindable var model: TrainingNotebookModel
    @State private var swipe = WeekSwipeState()
    @GestureState private var dragging = false
    @ScaledMetric(relativeTo: .body) private var dateColumnWidth: CGFloat = 44
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TrainingWordmark()
                Text("Your week").font(NotebookTypography.heading(37))
                TrainingWeekNavigation(model: model)
                VStack(spacing: 0) {
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    ForEach(model.weekDays, id: \.self) { day in
                        let summary = model.summary(for: day)
                        let categories = summary.muscleGroups.map(\.rawValue)
                        Button { model.openDay(day) } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(TrainingText.date(day, format: "EEE")).font(.body.weight(.medium))
                                    Text(TrainingText.date(day, format: "d")).font(.body.monospacedDigit())
                                }.frame(width: dateColumnWidth, alignment: .leading)
                                    .foregroundStyle(day == model.today ? NotebookStyle.clay : NotebookStyle.ink)
                                VStack(alignment: .leading, spacing: 4) {
                                    if summary.setCount == 0 {
                                        Label("Start workout", systemImage: "plus")
                                            .font(.body).foregroundStyle(NotebookStyle.clay)
                                    } else { Text(categories.joined(separator: " · ")).font(.body.bold()).fixedSize(horizontal: false, vertical: true) }
                                    if day == model.today { Text("Today").font(.subheadline.weight(.medium)).foregroundStyle(NotebookStyle.clay) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                if summary.setCount > 0 { Text("\(summary.setCount) sets").font(.subheadline.monospacedDigit()).fixedSize() }
                            }
                            .padding(.vertical, 14).padding(.horizontal, 8).frame(minHeight: 64)
                            .background(day == model.today ? NotebookStyle.clay.opacity(0.06) : .clear)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("\(TrainingText.date(day, format: "EEEE, MMM d")), \(summary.setCount) sets, \(summary.setCount == 0 ? "Start workout" : categories.joined(separator: ", "))")
                        .accessibilityIdentifier("day-\(day.rawValue)")
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    }
                }
                Text("\(model.trainingDayCount) training days · \(model.weekSetCount) sets")
                    .font(.body).foregroundStyle(NotebookStyle.quiet).accessibilityIdentifier("week-summary")
                if let error = model.errorMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error).foregroundStyle(NotebookStyle.clay)
                        Text("Try the same action again.").foregroundStyle(NotebookStyle.quiet)
                    }.font(.callout)
                }
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
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message).font(.callout).foregroundStyle(NotebookStyle.clay)
            Button("Try again") { model.flushRecovery() }.frame(minHeight: 44).accessibilityIdentifier("retry-save")
        }
    }
}
