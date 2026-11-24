import SwiftUI
import SendaDomain
import SendaLogger
#if os(iOS)
import UIKit
#endif

struct TrainingMonthCalendar: View {
    let model: TrainingNotebookModel
    let today: TrainingDay
    let pages: MonthCalendarPages
    @Binding var selectedDay: TrainingDay
    let showWeek: () -> Void
    let openWorkout: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @AccessibilityFocusState private var workoutActionFocused: Bool
    @State private var showsMuscles = false
    @Environment(\.locale) private var locale
    @State private var pageMotion = CalendarPageMotion()

    @ScaledMetric(relativeTo: .body) private var minimumRowHeight: CGFloat = 44
    private static let weeks = 6

    private var month: TrainingMonth { TrainingMonth(containing: selectedDay) }
    private var weeklyMuscles: WeeklyMuscleTraining {
        model.snapshot.weeklyMuscleTraining(days: (try? selectedDay.week()) ?? [], through: today,
                                            calendar: model.calendar)
    }

    var body: some View {
        let month = self.month
        GeometryReader { viewport in
            let minimumGridWidth: CGFloat = 7 * 44
            let useList = textSize >= .xxxLarge || viewport.size.width < minimumGridWidth
            let page = pages.page(for: month, locale: locale, includesNeighbors: !useList)
            let activity = monthActivity(for: page.window)
            let trained = page.monthDays.filter { activity[$0] == .logged }.count
            let gutter = min(20, max(0, (viewport.size.width - minimumGridWidth) / 2))
            let viewportHeight = viewport.size.height
            let compact = !useList && viewportHeight < 660
            let topInset: CGFloat = compact ? 4 : 8
            let bottomInset: CGFloat = compact ? 8 : 12
            let layout = useList
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(MonthPageLayout(availableHeight: viewportHeight - topInset - bottomInset,
                                            spacing: compact ? 6 : 10))
            ScrollViewReader { proxy in
                ScrollView {
                    layout {
                        TrainingCalendarMasthead(showsMonth: true, toggle: showWeek)
                            .trainingCalendarColumn().id("month-start")
                        monthHeader(month)
                            .trainingCalendarColumn()
                        if let message = model.errorMessage {
                            TrainingSaveError(model: model, message: message).trainingCalendarColumn()
                        }
                        if useList {
                            trainedCount(trained).trainingCalendarColumn()
                            selectedWorkout(activity: activity[selectedDay] ?? .empty)
                                .trainingCalendarColumn().id("month-workout")
                            VStack(spacing: 0) {
                                ForEach(page.monthDays, id: \.self) { day in
                                    if let text = page.text[day] {
                                        listDateButton(day, text: text, page: page, activity: activity[day] ?? .empty) {
                                            selectedDay = day
                                            proxy.scrollTo("month-workout", anchor: .top)
                                            workoutActionFocused = true
                                        }
                                    }
                                    Divider()
                                }
                            }
                            .trainingCalendarColumn()
                        } else {
                            calendarGrid(page: page, activity: activity) { day in
                                pageMotion.reset()
                                selectedDay = day
                                proxy.scrollTo("month-workout")
                            }
                            .padding(.horizontal, gutter)
                            .frame(maxWidth: 560)
                            .frame(maxWidth: .infinity)
                            .layoutValue(key: MonthGridItem.self, value: true)
                            calendarKey(trained: trained, hasDraft: page.visibleDays.contains { activity[$0] == .inProgress })
                                .trainingCalendarColumn()
                            selectedWorkout(activity: activity[selectedDay] ?? .empty, previewLines: compact ? 1 : 2)
                                .trainingCalendarColumn().id("month-workout")
                        }
                    }
                    .padding(.top, topInset).padding(.bottom, bottomInset)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .accessibilityIdentifier("month-calendar")
                .onChange(of: model.landingResetID) { _, _ in
                    pageMotion.reset()
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

    private func monthHeader(_ month: TrainingMonth) -> some View {
        let name = TrainingText.date(month.firstDay, format: "LLLL")
        let year = TrainingText.date(month.firstDay, format: "yyyy")
        let title = VStack(alignment: .leading, spacing: 0) {
            Text(year).font(.caption.weight(.semibold).monospacedDigit())
                .tracking(1.2).accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                Text(name).fixedSize()
                Text(TrainingText.date(month.firstDay, format: "LLL")).fixedSize(horizontal: false, vertical: true)
            }
            .font(NotebookTypography.heading(35, relativeTo: .largeTitle)).tracking(-1.5)
            .accessibilityLabel(TrainingText.date(month.firstDay, format: "LLLL yyyy"))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("calendar-month-title")
        }
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 6))
        return layout {
            title.frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .trainingTodayIconCenter, spacing: 2) {
                TrainingTodayButton(day: today, isVisible: selectedDay != today) {
                    pageMotion.reset()
                    selectedDay = model.today
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityIdentifier("today-month")
                VStack(spacing: 0) {
                    monthArrow(in: month, offset: -1, symbol: "chevron.up", label: "Previous month", identifier: "calendar-previous-month")
                    monthArrow(in: month, offset: 1, symbol: "chevron.down", label: "Next month", identifier: "calendar-next-month")
                }
                .accessibilityElement(children: .contain)
            }
            .fixedSize()
        }
    }

    private func trainedCount(_ trained: Int) -> some View {
        Text("\(trained) \(trained == 1 ? "day" : "days") trained")
            .font(.subheadline.weight(.medium))
            .accessibilityIdentifier("calendar-trained-days")
    }

    private func calendarKey(trained: Int, hasDraft: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                trainedCount(trained).fixedSize()
                Spacer(minLength: 8)
                legend(hasDraft: hasDraft).fixedSize()
            }
            VStack(alignment: .leading, spacing: 3) {
                trainedCount(trained)
                legend(hasDraft: hasDraft)
            }
        }
    }

    private func monthArrow(in month: TrainingMonth, offset: Int, symbol: String, label: String, identifier: String) -> some View {
        let destination = month.adding(months: offset)
        return Button {
            if let destination {
                pageMotion.reset()
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

    private func calendarGrid(page: MonthCalendarPages.Page, activity: [TrainingDay: MonthDayActivity],
                              select: @escaping (TrainingDay) -> Void) -> some View {
        let month = page.month
        let window = page.window
        let selected = selectedDay
        return VStack(spacing: 0) {
            weekdayLabels
                .fixedSize(horizontal: false, vertical: true)
            GeometryReader { geometry in
                let height = geometry.size.height
                let rowHeight = height / CGFloat(Self.weeks)
                MonthGridPager(month: month, motion: pageMotion,
                    previousTravel: CGFloat(window.previousWeekCount) * rowHeight,
                    nextTravel: CGFloat(window.nextWeekOffset) * rowHeight,
                    onPage: { destination in
                        guard self.month == month else { return false }
                        selectMonth(destination.firstDay)
                        return self.month == destination
                    }) {
                    ZStack(alignment: .top) {
                        ForEach(window.weeks) { week in
                            let isVisible = (0..<Self.weeks).contains(week.offset)
                            MonthGridWeek(week: week, page: page, activity: activity, today: today,
                                          selected: week.dates.contains(selected) ? selected : nil,
                                          isVisible: isVisible, motion: pageMotion, select: select)
                            .frame(height: rowHeight)
                            .allowsHitTesting(isVisible)
                            .accessibilityHidden(!isVisible)
                            .offset(y: CGFloat(week.offset) * rowHeight)
                            .transition(.identity)
                        }
                    }
                    .frame(width: geometry.size.width, height: height, alignment: .top)
                }
            }
            .frame(minHeight: CGFloat(Self.weeks) * max(44, minimumRowHeight),
                   maxHeight: CGFloat(Self.weeks) * max(64, minimumRowHeight))
        }
    }

    private func monthActivity(for window: MonthWeekWindow) -> [TrainingDay: MonthDayActivity] {
        let workouts = model.workspace.days
        var activity: [TrainingDay: MonthDayActivity] = [:]
        for week in window.weeks {
            for case let day? in week.dates {
                if let workout = workouts[day.rawValue] { activity[day] = MonthDayActivity(workout) }
            }
        }
        return activity
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 44), spacing: 0), count: 7)
    }

    private var weekdayLabels: some View {
        let weekdays = model.calendar.shortStandaloneWeekdaySymbols
        let shortWeekdays = model.calendar.veryShortStandaloneWeekdaySymbols
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<7) { index in
                let weekday = (index + 1) % 7
                ViewThatFits(in: .horizontal) {
                    Text(weekdays[weekday]).fixedSize()
                    Text(shortWeekdays[weekday]).fixedSize()
                }
                .textCase(.uppercase).tracking(0.8)
                .font(.caption2.weight(.semibold)).foregroundStyle(NotebookStyle.quiet)
                .padding(.vertical, 5)
                .accessibilityHidden(true)
            }
        }
    }

    private func marker(_ activity: MonthDayActivity, color: Color = NotebookStyle.clay) -> some View {
        MonthActivityMark(activity: activity, color: color)
    }

    private func legend(hasDraft: Bool) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) { marker(.logged); Text("Logged") }
            HStack(spacing: 4) { marker(.planned); Text("Planned") }
            if hasDraft { HStack(spacing: 4) { marker(.inProgress); Text("In progress") } }
        }
        .font(.caption).foregroundStyle(NotebookStyle.quiet)
        .frame(maxWidth: .infinity, alignment: .trailing).accessibilityHidden(true)
    }

    private func listDateButton(_ day: TrainingDay, text: MonthCalendarPages.DayText, page: MonthCalendarPages.Page,
                                activity: MonthDayActivity, select: @escaping () -> Void) -> some View {
        let selected = day == selectedDay
        let isToday = day == today
        return Button(action: select) {
            VStack(alignment: .leading, spacing: 3) {
                Text(text.date, format: page.listDateStyle)
                    .font(.body.weight(selected || isToday ? .semibold : .regular))
                Text((isToday ? "Today · " : "") + activity.description)
                    .font(.caption).foregroundStyle(NotebookStyle.quiet)
            }
            .padding(8).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(selected ? NotebookStyle.dockSelectionFill : .clear, in: NotebookStyle.squircle(8))
            .contentShape(Rectangle())
        }
        .accessibilityLabel((isToday ? "Today, " : "") + (page.spokenDates[day] ?? day.rawValue))
        .accessibilityValue(activity.description)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Shows this date’s workout details")
        .accessibilityIdentifier("calendar-day-\(day.rawValue)")
    }

    private func selectedWorkout(activity: MonthDayActivity, previewLines: Int = 2) -> some View {
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
        let detailLayout = textSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        return VStack(spacing: 0) {
            Button(action: openWorkout) {
                detailLayout {
                    if textSize >= .xxLarge {
                        Text(dateText).font(.subheadline)
                    } else {
                        VStack(spacing: 0) {
                            Text(day == today ? "Today" : TrainingText.date(day, format: "EEE"))
                                .textCase(.uppercase).tracking(0.8)
                                .font(.caption2.weight(.semibold))
                            Text(TrainingText.date(day, format: "d"))
                                .font(NotebookTypography.heading(38, relativeTo: .title))
                                .monospacedDigit()
                        }
                        .foregroundStyle(NotebookStyle.onCover.opacity(0.88))
                        .frame(minWidth: 45)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(dateText)
                    }
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(headline)
                                .font(NotebookTypography.heading(23, relativeTo: .title2))
                                .lineLimit(textSize.isAccessibilitySize ? nil : 2)
                            let detail = Text(preview.isEmpty ? headline : preview)
                                .font(.footnote)
                                .foregroundStyle(NotebookStyle.onCover.opacity(0.86))
                            if textSize.isAccessibilitySize {
                                if !preview.isEmpty { detail }
                            } else {
                                detail.lineLimit(previewLines, reservesSpace: true)
                                    .opacity(preview.isEmpty ? 0 : 1)
                                    .accessibilityHidden(preview.isEmpty)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold)).accessibilityHidden(true)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityFocused($workoutActionFocused)
            .accessibilityIdentifier("calendar-open-workout")
            Rectangle().fill(NotebookStyle.coverRule).frame(height: 0.5).accessibilityHidden(true)
            let footer = textSize >= .xxLarge
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 6))
            footer {
                if !status.isEmpty {
                    Text(status).font(.footnote)
                        .foregroundStyle(NotebookStyle.onCover.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                TrainingWeekMusclesButton(training: weeklyMuscles,
                    hasTargets: !model.profile.details.weeklyMuscleTargets.isEmpty,
                    title: "Weekly muscles", action: { showsMuscles = true })
                    .accessibilityHint("Shows the week containing the selected date")
                    .accessibilityIdentifier("calendar-week-muscles")
            }
            .frame(maxWidth: .infinity, alignment: textSize >= .xxLarge ? .leading : .trailing)
        }
        .foregroundStyle(NotebookStyle.onCover)
        .padding(.horizontal, 15)
        .padding(.bottom, 2)
        .background(NotebookStyle.cover, in: NotebookStyle.squircle(15))
    }
}

private enum MonthGridItem: LayoutValueKey {
    static let defaultValue = false
}

/// Only the weeks stretch. Report their minimum plus the actual text and controls to the scroll view.
private struct MonthPageLayout: Layout {
    let availableHeight: CGFloat
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = sizes(for: proposal.width, subviews: subviews)
        return CGSize(width: proposal.width ?? sizes.map(\.width).max() ?? 0,
                      height: sizes.reduce(gaps(subviews)) { $0 + $1.height })
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var top = bounds.minY
        for (subview, size) in zip(subviews, sizes(for: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: bounds.minX, y: top), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: size.height))
            top += size.height + spacing
        }
    }

    private func sizes(for width: CGFloat?, subviews: Subviews) -> [CGSize] {
        let natural = ProposedViewSize(width: width, height: nil)
        var sizes = subviews.map { $0.sizeThatFits(natural) }
        if let grid = subviews.indices.first(where: { subviews[$0][MonthGridItem.self] }) {
            let used = sizes.reduce(gaps(subviews)) { $0 + $1.height }
            let height = sizes[grid].height + max(0, availableHeight - used)
            sizes[grid] = subviews[grid].sizeThatFits(ProposedViewSize(width: width, height: height))
        }
        return sizes
    }

    private func gaps(_ subviews: Subviews) -> CGFloat {
        CGFloat(max(0, subviews.count - 1)) * spacing
    }
}

private struct MonthGridPager<Content: View>: View {
    let month: TrainingMonth
    let motion: CalendarPageMotion
    let previousTravel: CGFloat
    let nextTravel: CGFloat
    let onPage: (TrainingMonth) -> Bool
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragging = false
    private static var axisRatio: CGFloat { 1.3 }

    var body: some View {
        let grid = content
            .modifier(CalendarStripOffset(motion: motion))
            .clipped()
            .contentShape(Rectangle())
            .onChange(of: reduceMotion) { _, _ in motion.reset() }
            .onDisappear { motion.reset() }
        #if os(iOS)
        if #available(iOS 18.0, *) {
            grid.gesture(CalendarPan(axis: .vertical, axisRatio: Self.axisRatio,
                onChange: move, onEnd: finish, onCancel: motion.cancelDrag))
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
            .onEnded { finish($0.translation, velocity: $0.velocity.height) })
            .onChange(of: dragging) { _, active in
                if !active {
                    Task { @MainActor in
                        // Let the release handler run before resetting a cancelled drag.
                        await Task.yield()
                        if !dragging { motion.cancelDrag() }
                    }
                }
            }
    }

    private func move(_ translation: CGSize) {
        guard !reduceMotion, abs(translation.height) > abs(translation.width) * Self.axisRatio else { return }
        motion.drag(translation.height, within: -nextTravel...previousTravel)
    }

    private func finish(_ translation: CGSize, velocity: CGFloat) {
        let forward = translation.height < 0
        guard abs(translation.height) >= 48, abs(translation.height) > abs(translation.width) * Self.axisRatio,
              let destination = month.adding(months: forward ? 1 : -1) else {
            motion.cancelDrag()
            return
        }
        guard !reduceMotion else {
            _ = onPage(destination)
            return
        }
        motion.release(to: forward ? -nextTravel : previousTravel, velocity: velocity) {
            onPage(destination)
        }
    }
}

#if os(iOS)
@available(iOS 18.0, *)
struct CalendarPan: UIGestureRecognizerRepresentable {
    let axis: Axis?
    let axisRatio: CGFloat
    var onChange: ((CGSize) -> Void)? = nil
    var onEnd: ((CGSize, CGFloat) -> Void)? = nil
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
        case .ended: onEnd?(translation, recognizer.velocity(in: nil).y)
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
