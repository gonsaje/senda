import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingWeekNavigation: View {
    @Bindable var model: TrainingNotebookModel
    let today: TrainingDay
    let first: TrainingDay
    let week: [TrainingDay]
    let changeWeek: (Int) -> Void
    let showMuscles: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            monthAndYear
            dateAndControls
            Rectangle().fill(NotebookStyle.coverRule)
                .frame(height: 0.5).accessibilityHidden(true)
                .padding(.top, 4)
            overview
        }
        .padding(.horizontal, 16)
        .padding(.top, 13).padding(.bottom, 5)
        .foregroundStyle(NotebookStyle.onCover)
        .background(NotebookStyle.cover, in: NotebookStyle.squircle(17))
    }

    private var last: TrainingDay { week.last ?? first }

    private var monthAndYear: some View {
        let startYear = TrainingText.date(first, format: "yyyy")
        let endYear = TrainingText.date(last, format: "yyyy")
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(TrainingText.weekMonths(first: first, last: last, abbreviated: false))
                .font(NotebookTypography.heading(22, italic: true, relativeTo: .title2))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue("Week of \(TrainingText.date(first, format: "MMM d, yyyy")) through \(TrainingText.date(last, format: "MMM d, yyyy"))")
                .accessibilityIdentifier("week-month")
            Text(startYear == endYear ? startYear : "\(startYear)–\(endYear)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(NotebookStyle.onCover.opacity(0.78))
                .accessibilityHidden(true)
        }
    }

    private var dateAndControls: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return layout {
            Text("\(TrainingText.date(first, format: "d"))–\(TrainingText.date(last, format: "d"))")
                .font(NotebookTypography.heading(54, relativeTo: .largeTitle))
                .tracking(-2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            controls
        }
    }

    private var overview: some View {
        let setCounts = week.map { model.summary(for: $0).setCount }
        let days = setCounts.filter { $0 > 0 }.count
        let sets = setCounts.reduce(0, +)
        let training = model.snapshot.weeklyMuscleTraining(days: week, through: today, calendar: model.calendar)
        let summary = "\(days) \(days == 1 ? "workout" : "workouts") · \(sets) \(sets == 1 ? "set" : "sets")"
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return layout {
            Text(days == 0 ? "No workouts logged" : summary)
                .font(.footnote)
                .foregroundStyle(NotebookStyle.onCover.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(days == 0 ? "No workouts logged, 0 sets" : summary)
                .accessibilityIdentifier("week-summary")
            TrainingWeekMusclesButton(training: training,
                hasTargets: !model.profile.details.weeklyMuscleTargets.isEmpty,
                title: "Muscles", action: showMuscles)
                .accessibilityIdentifier("week-muscles")
        }
    }

    private var controls: some View {
        HStack(alignment: .trainingTodayIconCenter, spacing: 2) {
            TrainingTodayButton(day: today, isVisible: !week.contains(today)) {
                model.showWeek(containing: model.today)
            }
            .accessibilityIdentifier("today-week")
            VStack(spacing: 0) {
                arrow("chevron.up", label: "Previous week", identifier: "previous-week", direction: -1)
                arrow("chevron.down", label: "Next week", identifier: "next-week", direction: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("week-navigation-controls")
        }
        .fixedSize()
    }

    private func arrow(_ symbol: String, label: String, identifier: String, direction: Int) -> some View {
        Button { changeWeek(direction) } label: {
            Image(systemName: symbol).font(.subheadline.weight(.medium))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(label).accessibilityIdentifier(identifier)
    }
}

extension VerticalAlignment {
    private enum TrainingTodayIconCenter: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat { dimensions[VerticalAlignment.center] }
    }

    static let trainingTodayIconCenter = VerticalAlignment(TrainingTodayIconCenter.self)
}

struct TrainingTodayButton: View {
    let day: TrainingDay
    let isVisible: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .footnote) private var tileSize: CGFloat = 22

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(TrainingText.date(day, format: "d"))
                    .font(.system(size: tileSize * 0.48, weight: .semibold).monospacedDigit())
                    .frame(width: tileSize, height: tileSize)
                    .overlay {
                        NotebookStyle.squircle(tileSize * 0.23).strokeBorder(lineWidth: 1.25)
                    }
                    .alignmentGuide(.trainingTodayIconCenter) { $0[VerticalAlignment.center] }
                    .accessibilityHidden(true)
                Text("Today")
                    .font(.footnote.weight(.semibold))
            }
            .fixedSize()
            .frame(minWidth: 48, minHeight: 48)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Go to today")
        .opacity(isVisible ? 1 : 0)
        .disabled(!isVisible)
        .accessibilityHidden(!isVisible)
    }
}

struct TrainingCalendarMasthead: View {
    let showsMonth: Bool
    let toggle: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { brand; Spacer(minLength: 8); toggleButtons.fixedSize() }
            VStack(alignment: .leading, spacing: 8) { brand; toggleButtons }
        }
    }

    private var brand: some View {
        TrainingWordmark(width: 110)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Senda")
    }

    private var toggleButtons: some View {
        HStack(spacing: 2) {
            option(.week, selected: !showsMonth)
            option(.month, selected: showsMonth)
        }
        .padding(3)
        .background(NotebookStyle.todayFill, in: NotebookStyle.squircle(12))
        .accessibilityElement(children: .contain)
    }

    private func option(_ layout: TrainingCalendarLayout, selected: Bool) -> some View {
        Button { if !selected { toggle() } } label: {
            Text(layout == .week ? "Week" : "Month")
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? NotebookStyle.ink : NotebookStyle.quiet)
                .padding(.horizontal, 9)
                .frame(minWidth: 44, minHeight: 44)
                .background {
                    if selected { NotebookStyle.squircle(9).fill(NotebookStyle.ivory) }
                }
                .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(layout == .month ? "week-calendar" : "month-toggle-week")
    }
}
