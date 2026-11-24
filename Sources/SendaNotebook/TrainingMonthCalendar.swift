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
    @State private var showsMuscles = false

    @ScaledMetric(relativeTo: .body) private var minimumRowHeight: CGFloat = 44
    private static let weeks = 6
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
            let minimumGridWidth: CGFloat = 7 * 44
            let useList = textSize >= .xxxLarge || viewport.size.width < minimumGridWidth
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
                        monthHeader
                            .trainingCalendarColumn()
                        if let message = model.errorMessage {
                            TrainingSaveError(model: model, message: message).trainingCalendarColumn()
                        }
                        if useList {
                            trainedCount(trained).trainingCalendarColumn()
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
                                proxy.scrollTo("month-workout")
                            }
                            .padding(.horizontal, gutter)
                            .frame(maxWidth: 560)
                            .frame(maxWidth: .infinity)
                            .layoutValue(key: MonthGridItem.self, value: true)
                            calendarKey(trained: trained, hasDraft: activity.values.contains(.inProgress))
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

    private var monthHeader: some View {
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
        VStack(spacing: 0) {
            weekdayLabels
                .fixedSize(horizontal: false, vertical: true)
            GeometryReader { geometry in
                let height = geometry.size.height
                MonthGridPager(month: month, height: height, onPage: { selectMonth($0.firstDay) }) { pages, dragOffset in
                    ZStack(alignment: .top) {
                        ForEach(pages, id: \.month.firstDay) { page in
                            let isCurrent = page.offset == 0
                            let pageDates = isCurrent ? dates : page.month.calendarSlots
                            monthGrid(month: page.month, dates: pageDates,
                                activity: isCurrent ? activity : monthActivity(for: pageDates),
                                rowHeight: height / CGFloat(Self.weeks), select: select)
                                .offset(y: CGFloat(page.offset) * height + dragOffset)
                                .allowsHitTesting(isCurrent)
                                .accessibilityHidden(!isCurrent)
                                .transition(.identity)
                        }
                    }
                    .frame(height: height, alignment: .top)
                    .clipped()
                }
            }
            .frame(minHeight: CGFloat(Self.weeks) * max(44, minimumRowHeight),
                   maxHeight: CGFloat(Self.weeks) * max(64, minimumRowHeight))
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

    private func monthGrid(month: TrainingMonth, dates: [TrainingDay?], activity: [TrainingDay: Activity],
                           rowHeight: CGFloat, select: @escaping (TrainingDay) -> Void) -> some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(dates.indices, id: \.self) { index in
                Group {
                    if let day = dates[index] {
                        dateButton(day, in: month, activity: activity[day] ?? .empty, asRow: false) { select(day) }
                    } else {
                        Color.clear.accessibilityHidden(true)
                    }
                }
                .frame(height: rowHeight)
            }
        }
    }

    private func marker(_ activity: Activity, onSelection: Bool = false) -> some View {
        let color = onSelection ? NotebookStyle.onPrimary : NotebookStyle.clay
        return Capsule()
            .fill(activity == .logged ? color : .clear)
            .overlay(alignment: .leading) {
                if activity == .inProgress { Rectangle().fill(color).frame(width: 4) }
            }
            .clipShape(Capsule())
            .overlay { Capsule().strokeBorder(color, lineWidth: 1) }
            .frame(width: activity == .logged ? 12 : 9, height: 4)
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
        .frame(maxWidth: .infinity, alignment: .trailing).accessibilityHidden(true)
    }

    private func dateButton(_ day: TrainingDay, in page: TrainingMonth, activity: Activity, asRow: Bool,
                            select: @escaping () -> Void) -> some View {
        let isToday = day == today
        let outsideMonth = day.rawValue.prefix(7) != page.firstDay.rawValue.prefix(7)
        let isSelected = day == selectedDay && !outsideMonth
        let ink = outsideMonth ? NotebookStyle.quiet : (isToday || isSelected ? NotebookStyle.clay : NotebookStyle.ink)
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
                VStack(spacing: 2) {
                    Text(date.formatted(Self.dateStyle.day()))
                        .font(.body.weight(isSelected || isToday ? .bold : .regular).monospacedDigit())
                        .underline(isToday && !isSelected)
                        .foregroundStyle(isSelected ? NotebookStyle.onPrimary : ink)
                    marker(activity, onSelection: isSelected)
                }
                .frame(minWidth: 37, minHeight: 37)
                .background {
                    if isSelected {
                        Circle().fill(NotebookStyle.primaryFill)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
            }
        }
        .accessibilityLabel(isToday ? "Today, \(label)" : label)
        .accessibilityValue(activity.description)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Shows this date’s workout details")
        .accessibilityIdentifier("calendar-day-\(day.rawValue)")
    }

    private func selectedWorkout(activity: Activity, previewLines: Int = 2) -> some View {
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
        .background(NotebookStyle.cover, in: RoundedRectangle(cornerRadius: 15))
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
