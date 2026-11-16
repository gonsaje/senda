import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingMonthCalendar: View {
    let model: TrainingNotebookModel
    @State private var month: TrainingMonth
    @State private var showsJumpError = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize

    init(model: TrainingNotebookModel, initialDay: TrainingDay) {
        self.model = model
        _month = State(initialValue: TrainingMonth(containing: initialDay))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                .accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if showsJumpError, let message = model.errorMessage {
                        TrainingSaveError(model: model, message: message, retrySucceeded: { dismiss() })
                            .padding(.horizontal, 12)
                    }
                    if textSize.isAccessibilitySize {
                        dateList
                    } else {
                        ViewThatFits(in: .horizontal) {
                            monthGrid
                            dateList
                        }
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 12)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("month-calendar")
            .id(month.firstDay)
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .buttonStyle(.plain)
        #if os(iOS)
        .presentationDetents(textSize >= .xxLarge ? [.large] : [.height(420), .large])
        .presentationDragIndicator(.visible)
        #else
        .frame(minWidth: 340, idealWidth: 420, minHeight: 420)
        #endif
    }

    private var header: some View {
        let title = TrainingText.date(month.firstDay, format: "LLLL yyyy")
        let layout = textSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 4))
        return HStack(alignment: .top, spacing: 0) {
            layout {
                Group {
                    if textSize >= .xxLarge {
                        Text(title).fixedSize(horizontal: false, vertical: true)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            Text(title).fixedSize()
                            Text(TrainingText.date(month.firstDay, format: "LLL yyyy")).fixedSize()
                        }
                    }
                }
                .font(NotebookTypography.heading(25, relativeTo: .title2))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("calendar-month-title")
                HStack(spacing: 0) {
                    monthArrow(-1, symbol: "chevron.left", label: "Previous month", identifier: "calendar-previous-month")
                    monthArrow(1, symbol: "chevron.right", label: "Next month", identifier: "calendar-next-month")
                }
                .fixedSize()
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close calendar")
            .accessibilityIdentifier("calendar-close")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 16)
        .padding(.bottom, 6)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
    }

    private func monthArrow(_ offset: Int, symbol: String, label: String, identifier: String) -> some View {
        let destination = month.adding(months: offset)
        return Button {
            if let destination { month = destination }
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NotebookStyle.clay)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(destination == nil)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var monthGrid: some View {
        let days = month.days
        let leading = month.leadingEmptyDays
        let weekdays = model.calendar.veryShortStandaloneWeekdaySymbols
        let columns = Array(repeating: GridItem(.flexible(minimum: 44), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<7) { index in
                Text(weekdays[(index + 1) % 7])
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NotebookStyle.quiet)
                    .frame(height: 24)
                    .accessibilityHidden(true)
            }
            ForEach(0..<42) { slot in
                let index = slot - leading
                if days.indices.contains(index) {
                    let day = days[index]
                    dateButton(day, title: TrainingText.date(day, format: "d"), grid: true)
                } else {
                    Color.clear.frame(height: 46).accessibilityHidden(true)
                }
            }
        }
        .frame(minWidth: 308)
    }

    private var dateList: some View {
        VStack(spacing: 0) {
            ForEach(month.days, id: \.self) { day in
                dateButton(day, title: TrainingText.date(day, format: "EEE, MMM d"), grid: false)
                Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 15)
    }

    private func dateButton(_ day: TrainingDay, title: String, grid: Bool) -> some View {
        let hasWorkout = model.summary(for: day).setCount > 0
        let isToday = day == model.today
        let label = TrainingText.date(day, format: "EEEE, MMMM d, yyyy")
        let layout = grid
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        return Button {
            if model.showWeek(containing: day) { dismiss() }
            else { showsJumpError = true }
        } label: {
            layout {
                Text(title)
                    .font(.body.weight(isToday ? .semibold : .regular).monospacedDigit())
                    .foregroundStyle(isToday ? NotebookStyle.clay : NotebookStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Circle()
                    .fill(hasWorkout ? NotebookStyle.clay : .clear)
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: grid ? .center : .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(isToday ? "Today, \(label)" : label)
        .accessibilityValue(hasWorkout ? "Workout logged" : "No workout logged")
        .accessibilityHint("Opens the week containing this date")
        .accessibilityIdentifier("calendar-day-\(day.rawValue)")
    }
}
