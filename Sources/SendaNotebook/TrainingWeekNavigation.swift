import SwiftUI
import SendaLogger

struct TrainingWeekNavigation: View {
    @Bindable var model: TrainingNotebookModel
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        Group {
            if textSize.isAccessibilitySize {
                stackedHeader
            } else {
                ViewThatFits(in: .horizontal) {
                    inlineHeader(abbreviated: false)
                    inlineHeader(abbreviated: true)
                    stackedHeader
                }
            }
        }.foregroundStyle(NotebookStyle.ink)
    }
    private func inlineHeader(abbreviated: Bool) -> some View {
        HStack(spacing: 8) {
            title(abbreviated: abbreviated).fixedSize()
            Spacer(minLength: 0)
            controls
        }
    }
    private var stackedHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            title(abbreviated: false)
            HStack { Spacer(minLength: 0); controls }
        }
    }
    private func title(abbreviated: Bool) -> some View {
        let last = model.weekDays.last ?? model.workspace.visibleWeek
        return Text(TrainingText.weekMonths(first: model.workspace.visibleWeek, last: last, abbreviated: abbreviated))
            .font(NotebookTypography.heading(34)).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue("Week of \(TrainingText.date(model.workspace.visibleWeek, format: "MMM d, yyyy")) through \(TrainingText.date(last, format: "MMM d, yyyy"))")
            .accessibilityIdentifier("week-month")
    }
    private var isCurrentWeek: Bool { model.weekDays.contains(model.today) }
    private var controls: some View {
        HStack(spacing: 0) {
            Button { model.showCurrentWeek() } label: {
                Text("Today").font(.subheadline.weight(isCurrentWeek ? .semibold : .medium))
                    .frame(minWidth: 60, minHeight: 44)
                    .foregroundStyle(isCurrentWeek ? NotebookStyle.ivory : NotebookStyle.clay)
                    .background(isCurrentWeek ? NotebookStyle.clay : .clear, in: RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
            }.padding(.trailing, 4)
                .accessibilityAddTraits(isCurrentWeek ? .isSelected : [])
                .accessibilityValue(isCurrentWeek ? "Current week" : "")
                .accessibilityHint(isCurrentWeek ? "Showing the current week" : "Return to the current week")
                .accessibilityIdentifier("today-week")
            Button { model.changeWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("Previous week").accessibilityIdentifier("previous-week")
            Button { model.changeWeek(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel("Next week").accessibilityIdentifier("next-week")
        }.fixedSize().accessibilityElement(children: .contain).accessibilityIdentifier("week-navigation-controls")
    }
}
