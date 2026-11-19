import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingWeekNavigation: View {
    @Bindable var model: TrainingNotebookModel
    let week: [TrainingDay]
    let training: WeeklyMuscleTraining
    let showCalendar: () -> Void
    let showMuscles: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { TrainingWordmark(); Spacer(); dateShortcuts }
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
            .background(NotebookStyle.cover, in: RoundedRectangle(cornerRadius: 17))
        }
    }

    private var dateShortcuts: some View {
        HStack(spacing: 4) {
            today
            Button(action: showCalendar) {
                Image(systemName: "calendar")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(NotebookStyle.clay)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Calendar")
            .accessibilityHint("Browse workout dates by month")
            .accessibilityIdentifier("week-calendar")
        }
    }

    private var first: TrainingDay { model.workspace.visibleWeek }
    private var last: TrainingDay { week.last ?? first }
    private var isCurrentWeek: Bool { week.contains(model.today) }
    private var dateTransition: ContentTransition { reduceMotion ? .identity : .opacity }
    private var dateAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.18) }

    private var monthAndYear: some View {
        let startYear = TrainingText.date(first, format: "yyyy")
        let endYear = TrainingText.date(last, format: "yyyy")
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(TrainingText.weekMonths(first: first, last: last, abbreviated: false))
                .font(NotebookTypography.heading(22, italic: true, relativeTo: .title2))
                .contentTransition(dateTransition)
                .animation(dateAnimation, value: first)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue("Week of \(TrainingText.date(first, format: "MMM d, yyyy")) through \(TrainingText.date(last, format: "MMM d, yyyy"))")
                .accessibilityIdentifier("week-month")
            Text(startYear == endYear ? startYear : "\(startYear)–\(endYear)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(NotebookStyle.onCover.opacity(0.78))
                .contentTransition(dateTransition)
                .animation(dateAnimation, value: first)
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
                .contentTransition(dateTransition)
                .animation(dateAnimation, value: first)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            controls
        }
    }

    private var overview: some View {
        let days = model.trainingDayCount
        let sets = model.weekSetCount
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
            Button(action: showMuscles) {
                HStack(spacing: 6) {
                    TrainingWeekMuscleThumbnail(counts: training.counts)
                        .accessibilityHidden(true)
                    Text("Muscles").font(.footnote.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Muscles trained")
            .accessibilityValue(muscleSummary)
            .accessibilityIdentifier("week-muscles")
        }
    }

    private var muscleSummary: String {
        let count = training.regions.count
        if count == 0 {
            return model.profile.details.weeklyMuscleTargets.isEmpty ? "No muscles to show" : "No sets logged"
        }
        return "\(count) \(count == 1 ? "area" : "areas")"
    }

    private var today: some View {
        Button { model.showCurrentWeek() } label: {
            Text("Today").font(.subheadline.weight(isCurrentWeek ? .semibold : .medium))
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(NotebookStyle.clay)
                .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isCurrentWeek ? .isSelected : [])
        .accessibilityValue(isCurrentWeek ? "Current week" : "")
        .accessibilityHint(isCurrentWeek ? "Showing the current week" : "Return to the current week")
        .accessibilityIdentifier("today-week")
    }

    private var controls: some View {
        HStack(spacing: 0) {
            arrow("chevron.left", label: "Previous week", identifier: "previous-week", direction: -1)
            arrow("chevron.right", label: "Next week", identifier: "next-week", direction: 1)
        }.fixedSize().accessibilityElement(children: .contain).accessibilityIdentifier("week-navigation-controls")
    }

    private func arrow(_ symbol: String, label: String, identifier: String, direction: Int) -> some View {
        Button { model.changeWeek(direction) } label: {
            Image(systemName: symbol).font(.subheadline.weight(.medium))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(label).accessibilityIdentifier(identifier)
    }
}
