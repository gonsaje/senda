import SwiftUI
import SendaDomain
import SendaLogger
#if os(iOS)
import UIKit
#endif

struct TrainingMonthCalendar: View {
    let model: TrainingNotebookModel
    let today: TrainingDay
    @Binding var selectedDay: TrainingDay
    let showWeek: () -> Void
    let openWorkout: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @AccessibilityFocusState private var workoutActionFocused: Bool
    @Namespace private var monthContent
    @State private var workoutTop: CGFloat?
    @State private var workoutBelowViewport = false
    @State private var showsMuscles = false

    private static let weekdayHeight: CGFloat = 22
    private static let dateHeight: CGFloat = 46
    private static let gridHeight: CGFloat = 6 * dateHeight
    private static let dateStyle = Date.FormatStyle(locale: .autoupdatingCurrent, calendar: TrainingText.utc,
                                                    timeZone: TrainingText.utc.timeZone)

    private enum Activity {
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

    private var month: TrainingMonth { TrainingMonth(containing: selectedDay) }
    private var weeklyMuscles: WeeklyMuscleTraining {
        model.snapshot.weeklyMuscleTraining(days: (try? selectedDay.week()) ?? [], through: today,
                                            calendar: model.calendar)
    }

    var body: some View {
        let month = self.month
        let days = month.days
        let dates = month.calendarSlots
        let activity = monthActivity(for: dates)
        let trained = days.filter { activity[$0] == .logged }.count

        GeometryReader { viewport in
            let useList = textSize >= .xxxLarge || viewport.size.width < 318
            let viewportHeight = viewport.size.height
            let bottomPadding: CGFloat = 18
            let remainingHeight = workoutTop.map { max(0, viewportHeight - $0 - bottomPadding) }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TrainingCalendarMasthead(showsMonth: true, toggle: showWeek)
                            .trainingCalendarColumn().id("month-start")
                        header(trained: trained).trainingCalendarColumn()
                        if let message = model.errorMessage {
                            TrainingSaveError(model: model, message: message).trainingCalendarColumn()
                        }
                        if useList {
                            selectedWorkout(activity: activity[selectedDay] ?? .empty)
                                .trainingCalendarColumn().id("month-workout")
                            VStack(spacing: 0) {
                                ForEach(days, id: \.self) { day in
                                    dateButton(day, in: month, activity: activity[day] ?? .empty, asRow: true) {
                                        selectedDay = day
                                        proxy.scrollTo("month-workout", anchor: .top)
                                        workoutActionFocused = true
                                    }
                                    Divider()
                                }
                            }
                            .trainingCalendarColumn()
                        } else {
                            calendarGrid(month: month, dates: dates, activity: activity) { day in
                                selectedDay = day
                                if workoutBelowViewport { proxy.scrollTo("month-workout", anchor: .bottom) }
                            }
                            legend(hasDraft: activity.values.contains(.inProgress))
                            selectedWorkout(activity: activity[selectedDay] ?? .empty, minHeight: remainingHeight)
                                .trainingCalendarColumn().id("month-workout")
                                .onGeometryChange(for: CGFloat.self) { [monthContent] geometry in
                                    geometry.frame(in: .named(monthContent)).minY
                                } action: { workoutTop = $0 }
                                .onGeometryChange(for: Bool.self) { geometry in
                                    geometry.frame(in: .scrollView(axis: .vertical)).maxY > viewportHeight + 1
                                } action: { workoutBelowViewport = $0 }
                        }
                    }
                    .padding(.top, 10).padding(.bottom, bottomPadding)
                    .frame(maxWidth: .infinity)
                    .coordinateSpace(.named(monthContent))
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .accessibilityIdentifier("month-calendar")
                .onChange(of: model.landingResetID) { _, _ in
                    proxy.scrollTo("month-start", anchor: .top)
                }
            }
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .buttonStyle(.plain)
        .sheet(isPresented: $showsMuscles) {
            TrainingWeekMusclesView(training: weeklyMuscles, profile: model.profile,
                exerciseName: { model.exercise($0).displayName })
        }
    }

    private func header(trained: Int) -> some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return VStack(alignment: .leading, spacing: 0) {
            layout {
                VStack(alignment: .leading, spacing: 0) {
                    Text(TrainingText.date(month.firstDay, format: "yyyy"))
                        .font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                        .accessibilityHidden(true)
                    ViewThatFits(in: .horizontal) {
                        Text(TrainingText.date(month.firstDay, format: "LLLL")).fixedSize()
                        Text(TrainingText.date(month.firstDay, format: "LLL")).lineLimit(1)
                    }
                        .font(NotebookTypography.heading(43, relativeTo: .largeTitle)).tracking(-1.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(TrainingText.date(month.firstDay, format: "LLLL yyyy"))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("calendar-month-title")
                    Text("\(trained) \(trained == 1 ? "day" : "days") trained")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .accessibilityIdentifier("calendar-trained-days")
                }
                HStack(alignment: .trainingTodayIconCenter, spacing: 2) {
                    TrainingTodayButton(day: today, isVisible: selectedDay != today) {
                        selectedDay = model.today
                    }
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityIdentifier("today-month")
                    VStack(spacing: 0) {
                        monthArrow(-1, symbol: "chevron.up", label: "Previous month", identifier: "calendar-previous-month")
                        monthArrow(1, symbol: "chevron.down", label: "Next month", identifier: "calendar-next-month")
                    }
                    .accessibilityElement(children: .contain)
                }
                .fixedSize()
            }
            .padding(.bottom, 10)
            Rectangle().fill(NotebookStyle.rule).frame(height: 1).accessibilityHidden(true)
        }
    }

    private func monthArrow(_ offset: Int, symbol: String, label: String, identifier: String) -> some View {
        let destination = month.adding(months: offset)
        return Button {
            if let destination {
                selectMonth(destination.firstDay)
            }
        } label: {
            Image(systemName: symbol).font(.subheadline.weight(.medium))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .disabled(destination == nil)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func selectMonth(_ firstDay: TrainingDay) {
        guard firstDay != month.firstDay else { return }
        selectedDay = firstDay == TrainingMonth(containing: today).firstDay ? today : firstDay
    }

    private func calendarGrid(month: TrainingMonth, dates: [TrainingDay?], activity: [TrainingDay: Activity],
                              select: @escaping (TrainingDay) -> Void) -> some View {
        MonthGridPager(month: month, height: Self.gridHeight, onPage: { selectMonth($0.firstDay) }) { pages, dragOffset in
            VStack(spacing: 0) {
                weekdayLabels
                ZStack(alignment: .top) {
                    ForEach(pages, id: \.month.firstDay) { page in
                        let isCurrent = page.offset == 0
                        let pageDates = isCurrent ? dates : page.month.calendarSlots
                        monthGrid(month: page.month, dates: pageDates,
                            activity: isCurrent ? activity : monthActivity(for: pageDates), select: select)
                            .frame(height: Self.gridHeight, alignment: .top)
                            .offset(y: CGFloat(page.offset) * Self.gridHeight + dragOffset)
                            .allowsHitTesting(isCurrent)
                            .accessibilityHidden(!isCurrent)
                            .transition(.identity)
                    }
                }
                .frame(height: Self.gridHeight)
                .clipped()
            }
        }
    }

    private func monthActivity(for dates: [TrainingDay?]) -> [TrainingDay: Activity] {
        Dictionary(uniqueKeysWithValues: dates.compactMap { $0 }.map {
            ($0, Activity(model.workspace.days[$0.rawValue]))
        })
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 44), spacing: 0), count: 7)
    }

    private var weekdayLabels: some View {
        let weekdays = model.calendar.shortStandaloneWeekdaySymbols
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<7) { index in
                Text(weekdays[(index + 1) % 7]).textCase(.uppercase)
                    .font(.caption2.weight(.semibold)).foregroundStyle(NotebookStyle.quiet)
                    .frame(height: Self.weekdayHeight).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: 530)
        .frame(maxWidth: .infinity)
    }

    private func monthGrid(month: TrainingMonth, dates: [TrainingDay?], activity: [TrainingDay: Activity],
                           select: @escaping (TrainingDay) -> Void) -> some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(dates.indices, id: \.self) { index in
                if let day = dates[index] {
                    dateButton(day, in: month, activity: activity[day] ?? .empty, asRow: false) { select(day) }
                } else {
                    Color.clear.frame(height: Self.dateHeight).accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: 530)
        .frame(maxWidth: .infinity)
    }

    private func marker(_ activity: Activity) -> some View {
        Circle()
            .fill(activity == .logged ? NotebookStyle.clay : .clear)
            .overlay(alignment: .leading) {
                if activity == .inProgress {
                    Rectangle().fill(NotebookStyle.clay).frame(width: 3.5)
                }
            }
            .clipShape(Circle())
            .overlay { Circle().strokeBorder(NotebookStyle.clay, lineWidth: 1.3) }
            .frame(width: 7, height: 7)
            .opacity(activity == .empty ? 0 : 1)
            .accessibilityHidden(true)
    }

    private func legend(hasDraft: Bool) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) { marker(.logged); Text("Logged") }
            HStack(spacing: 4) { marker(.planned); Text("Planned") }
            if hasDraft { HStack(spacing: 4) { marker(.inProgress); Text("In progress") } }
        }
        .font(.caption).foregroundStyle(NotebookStyle.quiet)
        .fixedSize(horizontal: true, vertical: true)
        .frame(maxWidth: .infinity).accessibilityHidden(true)
    }

    private func dateButton(_ day: TrainingDay, in page: TrainingMonth, activity: Activity, asRow: Bool,
                            select: @escaping () -> Void) -> some View {
        let isToday = day == today
        let outsideMonth = day.rawValue.prefix(7) != page.firstDay.rawValue.prefix(7)
        let isSelected = day == selectedDay && !outsideMonth
        let ink = outsideMonth ? NotebookStyle.quiet : (isToday || activity == .logged ? NotebookStyle.clay : NotebookStyle.ink)
        let date = day.date(in: Self.dateStyle.calendar)
        let label = date.formatted(Self.dateStyle.weekday(.wide).month(.wide).day().year())
        return Button(action: select) {
            if asRow {
                VStack(alignment: .leading, spacing: 3) {
                    Text(date.formatted(Self.dateStyle.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.body.weight(isSelected || isToday ? .semibold : .regular))
                    Text((isToday ? "Today · " : "") + activity.description)
                        .font(.caption).foregroundStyle(NotebookStyle.quiet)
                }
                .padding(8).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(isSelected ? NotebookStyle.dockSelectionFill : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            } else {
                VStack(spacing: 1) {
                    Text(date.formatted(Self.dateStyle.day()))
                        .font(.body.weight(isSelected || isToday || activity == .logged ? .semibold : .regular).monospacedDigit())
                        .underline(isToday && !isSelected)
                        .foregroundStyle(isSelected ? NotebookStyle.ivory : ink)
                        .padding(4).frame(minWidth: 32, minHeight: 32)
                        .background(isSelected ? NotebookStyle.ink : .clear, in: Circle())
                    marker(activity)
                }
                .frame(maxWidth: .infinity).frame(height: Self.dateHeight).contentShape(Rectangle())
            }
        }
        .accessibilityLabel(isToday ? "Today, \(label)" : label)
        .accessibilityValue(activity.description)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Shows this date’s workout details")
        .accessibilityIdentifier("calendar-day-\(day.rawValue)")
    }

    private func selectedWorkout(activity: Activity, minHeight: CGFloat? = nil) -> some View {
        let day = selectedDay
        let summary = model.summary(for: day)
        let exercises = model.indexedExercises(on: day).map(\.displayName)
        let session = model.workspace.days[day.rawValue]?.programSession
        let singleExercise = exercises.count == 1 ? exercises.first : nil
        let headline = activity == .empty ? "Start workout" : (summary.weekFocus ?? session?.sessionTitle ?? singleExercise ?? "Workout")
        let dateText = (day == today ? "Today · " : "") + TrainingText.date(day, format: "EEE, MMM d")
        let status: String
        if summary.setCount > 0 { status = "\(summary.setCount) \(summary.setCount == 1 ? "set" : "sets") logged" }
        else if activity == .planned { status = "Planned" }
        else if activity == .inProgress { status = "In progress" }
        else { status = "" }
        let exerciseNames = singleExercise == headline ? "" : exercises.prefix(3).joined(separator: " · ")
        let preview = exercises.count > 3 ? "\(exerciseNames) · +\(exercises.count - 3) more" : exerciseNames
        let metadata = textSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        return VStack(spacing: 0) {
            Button(action: openWorkout) {
                VStack(alignment: .leading, spacing: 6) {
                    metadata {
                        Text(dateText).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(status.isEmpty ? "Planned" : status).lineLimit(1)
                            .opacity(status.isEmpty ? 0 : 1)
                            .accessibilityHidden(status.isEmpty)
                    }
                    .font(.caption).foregroundStyle(NotebookStyle.onCover.opacity(0.84))
                    HStack(spacing: 12) {
                        Text(headline).font(NotebookTypography.heading(27, relativeTo: .title2))
                            .lineLimit(textSize.isAccessibilitySize ? 2 : 1, reservesSpace: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold)).accessibilityHidden(true)
                    }
                    // Use the same font metrics even on dates without exercises.
                    Text(preview.isEmpty ? headline : preview).lineLimit(1)
                        .font(.subheadline).foregroundStyle(NotebookStyle.onCover.opacity(0.90))
                        .opacity(preview.isEmpty ? 0 : 1)
                        .accessibilityHidden(preview.isEmpty)
                }
                .padding(.vertical, 12)
                .frame(maxHeight: minHeight == nil ? nil : .infinity)
                .contentShape(Rectangle())
            }
            .accessibilityFocused($workoutActionFocused)
            .accessibilityIdentifier("calendar-open-workout")

            Rectangle().fill(NotebookStyle.coverRule).frame(height: 0.5).accessibilityHidden(true)
            TrainingWeekMusclesButton(training: weeklyMuscles,
                hasTargets: !model.profile.details.weeklyMuscleTargets.isEmpty,
                title: "Weekly muscles", action: { showsMuscles = true })
                .accessibilityHint("Shows the week containing the selected date")
                .accessibilityIdentifier("calendar-week-muscles")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(NotebookStyle.onCover)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .frame(minHeight: minHeight)
        .background(NotebookStyle.cover, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct MonthGridPager<Content: View>: View {
    let month: TrainingMonth
    let height: CGFloat
    let onPage: (TrainingMonth) -> Void
    @ViewBuilder let content: ([(month: TrainingMonth, offset: Int)], CGFloat) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @GestureState private var dragging = false
    private static var axisRatio: CGFloat { 1.3 }

    var body: some View {
        let offsets = reduceMotion ? 0...0 : -1...1
        let pages = offsets.compactMap { offset in
            month.adding(months: offset).map { (month: $0, offset: offset) }
        }
        let grid = content(pages, dragOffset)
            .contentShape(Rectangle())
            .onChange(of: reduceMotion) { _, _ in dragOffset = 0 }
        #if os(iOS)
        if #available(iOS 18.0, *) {
            grid.gesture(CalendarPan(axis: .vertical, axisRatio: Self.axisRatio,
                onChange: move, onEnd: finish, onCancel: { settle() }))
        } else {
            legacy(grid)
        }
        #else
        legacy(grid)
        #endif
    }

    private func legacy(_ grid: some View) -> some View {
        grid.highPriorityGesture(DragGesture(minimumDistance: 18, coordinateSpace: .global)
            .updating($dragging) { _, active, _ in active = true }
            .onChanged { move($0.translation) }
            .onEnded { finish($0.translation) })
            .onChange(of: dragging) { _, active in
                if !active {
                    Task { @MainActor in
                        // Let the release handler run before resetting a cancelled drag.
                        await Task.yield()
                        if !dragging { settle() }
                    }
                }
            }
    }

    private func move(_ translation: CGSize) {
        guard !reduceMotion, destination(for: translation) != nil else {
            dragOffset = 0
            return
        }
        dragOffset = min(max(translation.height, -height), height)
    }

    private func finish(_ translation: CGSize) {
        settle(abs(translation.height) >= 48 ? destination(for: translation) : nil)
    }

    private func destination(for translation: CGSize) -> TrainingMonth? {
        guard abs(translation.height) > abs(translation.width) * Self.axisRatio else { return nil }
        return month.adding(months: translation.height < 0 ? 1 : -1)
    }

    private func settle(_ destination: TrainingMonth? = nil) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.34)) {
            dragOffset = 0
            if let destination { onPage(destination) }
        }
    }
}

#if os(iOS)
@available(iOS 18.0, *)
struct CalendarPan: UIGestureRecognizerRepresentable {
    let axis: Axis?
    let axisRatio: CGFloat
    var onChange: ((CGSize) -> Void)? = nil
    var onEnd: ((CGSize) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(axis: axis, axisRatio: axisRatio)
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let point = recognizer.translation(in: nil)
        let translation = CGSize(width: point.x, height: point.y)
        switch recognizer.state {
        case .began, .changed: onChange?(translation)
        case .ended: onEnd?(translation)
        case .cancelled, .failed: onCancel?()
        default: break
        }
    }

    @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let axis: Axis?
        private let axisRatio: CGFloat

        init(axis: Axis?, axisRatio: CGFloat) {
            self.axis = axis
            self.axisRatio = axisRatio
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            guard let axis else { return true }
            let translation = pan.translation(in: nil)
            let movement = translation == .zero ? pan.velocity(in: nil) : translation
            let width = abs(movement.x)
            let height = abs(movement.y)
            return axis == .vertical ? height > width * axisRatio : width > height * axisRatio
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Let a drag on the paging surface take precedence over the enclosing scroll view.
            guard let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
            return otherGestureRecognizer === scrollView.panGestureRecognizer
        }
    }
}
#endif
