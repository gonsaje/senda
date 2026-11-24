import SwiftUI
import SendaDomain

enum MonthDayActivity {
    case empty, planned, inProgress, logged

    init(_ workout: DayWorkout?) {
        guard let workout else { self = .empty; return }
        if workout.rows.values.contains(where: { $0.contains { $0.performedSetID != nil } }) {
            self = .logged
        } else if workout.rows.values.contains(where: { $0.contains { !$0.weight.isEmpty || !$0.reps.isEmpty } }) {
            self = .inProgress
        } else if workout.programSession != nil || !workout.exerciseIDs.isEmpty || !workout.hiddenSupersets.isEmpty {
            self = .planned
        } else {
            self = .empty
        }
    }

    var description: String {
        switch self {
        case .empty: "No workout logged"
        case .planned: "Workout planned"
        case .inProgress: "Workout in progress"
        case .logged: "Workout logged"
        }
    }
}

/// Date numerals and markers share one drawing surface per week. Only visible dates need controls.
struct MonthGridWeek: View {
    let week: MonthWeekWindow.Week
    let page: MonthCalendarPages.Page
    let activity: [TrainingDay: MonthDayActivity]
    let today: TrainingDay
    let selected: TrainingDay?
    let isVisible: Bool
    let motion: CalendarPageMotion
    let select: (TrainingDay) -> Void
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ZStack {
            artwork
            if isVisible {
                HStack(spacing: 0) {
                    ForEach(week.dates.indices, id: \.self) { index in
                        if let day = week.dates[index], let text = page.text[day] {
                            button(day: day, text: text)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    private func button(day: TrainingDay, text: MonthCalendarPages.DayText) -> some View {
        let status = activity[day] ?? .empty
        return Button { select(day) } label: {
            ZStack {
                Color.clear
                if day == selected {
                    SelectedMonthDay(day: day, number: text.number, isToday: day == today,
                                     activity: status, motion: motion)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityLabel((day == today ? "Today, " : "") + (page.spokenDates[day] ?? day.rawValue))
        .accessibilityValue(status.description)
        .accessibilityAddTraits(day == selected ? .isSelected : [])
        .accessibilityHint("Shows this date’s workout details")
        .accessibilityIdentifier("calendar-day-\(day.rawValue)")
    }

    private var artwork: some View {
        let rtl = layoutDirection == .rightToLeft
        let prefix = page.month.firstDay.rawValue.prefix(7)
        return Canvas { context, size in
            let width = size.width / 7
            for (index, slot) in week.dates.enumerated() {
                guard let day = slot, day != selected, let text = page.text[day] else { continue }
                let outside = !day.rawValue.hasPrefix(prefix)
                let isToday = day == today
                let color = outside ? NotebookStyle.quiet : (isToday ? NotebookStyle.clay : NotebookStyle.ink)
                let label = Text(verbatim: text.number)
                    .font(.body.weight(isToday ? .bold : .regular).monospacedDigit())
                    .underline(isToday)
                    .foregroundColor(color)
                let number = context.resolve(label)
                let x = (CGFloat(rtl ? 6 - index : index) + 0.5) * width
                context.draw(number, at: CGPoint(x: x, y: size.height / 2 - 3))
                if let mark = activity[day], mark != .empty {
                    let height = number.measure(in: size).height
                    mark.draw(in: context, center: CGPoint(x: x, y: (size.height + height) / 2 + 1),
                              color: outside ? NotebookStyle.quiet : NotebookStyle.clay)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private extension MonthDayActivity {
    var width: CGFloat { self == .logged ? 12 : 9 }

    func draw(in context: GraphicsContext, center: CGPoint, color: Color) {
        guard self != .empty else { return }
        let rect = CGRect(x: center.x - width / 2, y: center.y - 2, width: width, height: 4)
        let path = Path(roundedRect: rect, cornerRadius: 1, style: .continuous)
        if self == .logged {
            context.fill(path, with: .color(color))
        } else {
            if self == .inProgress {
                var partial = context
                partial.clip(to: path)
                partial.fill(Path(CGRect(origin: rect.origin, size: CGSize(width: 4, height: 4))), with: .color(color))
            }
            context.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 0.5, style: .continuous),
                           with: .color(color), lineWidth: 1)
        }
    }
}

struct MonthActivityMark: View {
    let activity: MonthDayActivity
    let color: Color

    var body: some View {
        Canvas { context, size in
            activity.draw(in: context, center: CGPoint(x: size.width / 2, y: size.height / 2), color: color)
        }
        .frame(width: activity.width, height: 4)
        .accessibilityHidden(true)
    }
}

private struct SelectedMonthDay: View {
    let day: TrainingDay
    let number: String
    let isToday: Bool
    let activity: MonthDayActivity
    let motion: CalendarPageMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var laidOut: TrainingDay?
    @State private var revealed = false

    var body: some View {
        let ready = laidOut == day && !motion.isMoving
        face(highlighted: false)
            .overlay {
                face(highlighted: true)
                    .background(NotebookStyle.primaryFill, in: NotebookStyle.squircle(10))
                    .compositingGroup()
                    .opacity(ready && revealed ? 1 : 0)
                    .animation(ready && !reduceMotion ? .easeIn(duration: 0.16) : nil, value: revealed)
                    .accessibilityHidden(true)
            }
            .onPreferenceChange(LaidOutMonthDay.self) { laidOut = $0 }
            .task(id: ready) { revealed = ready }
    }

    private func face(highlighted: Bool) -> some View {
        Text(verbatim: number)
            .font(.body.weight(highlighted || isToday ? .bold : .regular).monospacedDigit())
            .underline(isToday && !highlighted)
            .foregroundStyle(highlighted ? NotebookStyle.onPrimary : (isToday ? NotebookStyle.clay : NotebookStyle.ink))
            .overlay {
                if !highlighted { LaidOutMonthDay.report(day) }
            }
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) {
                if activity != .empty {
                    MonthActivityMark(activity: activity, color: highlighted ? NotebookStyle.onPrimary : NotebookStyle.clay)
                }
            }
            .frame(minWidth: 37, minHeight: 37)
    }
}

/// The selected number reports its first layout before its fill and contrasting ink are enabled together.
private struct LaidOutMonthDay: PreferenceKey {
    static let defaultValue: TrainingDay? = nil

    @MainActor static func report(_ day: TrainingDay) -> some View {
        GeometryReader { geometry in
            let hasSize = geometry.size.width > 0 && geometry.size.height > 0
            Color.clear.preference(key: Self.self, value: hasSize ? day : nil)
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    static func reduce(value: inout TrainingDay?, nextValue: () -> TrainingDay?) {
        if let day = nextValue() { value = day }
    }
}
