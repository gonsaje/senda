import SwiftUI
import SendaLogger

struct TrainingWeekNavigation: View {
    @Bindable var model: TrainingNotebookModel
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        Group {
            if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    title(abbreviated: false)
                    HStack { Spacer(minLength: 0); controls }
                }
            } else {
                HStack(spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        title(abbreviated: false).fixedSize()
                        title(abbreviated: true).fixedSize()
                        title(abbreviated: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    controls
                }
            }
        }.foregroundStyle(NotebookStyle.ink).accessibilityIdentifier("week-navigation")
    }
    private func title(abbreviated: Bool) -> some View {
        let last = model.weekDays.last ?? model.workspace.visibleWeek
        return Text(TrainingText.weekMonths(first: model.workspace.visibleWeek, last: last, today: model.today, abbreviated: abbreviated))
            .font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            .accessibilityValue("Week of \(TrainingText.date(model.workspace.visibleWeek, format: "MMM d, yyyy")) through \(TrainingText.date(last, format: "MMM d, yyyy"))")
            .accessibilityIdentifier("week-month")
    }
    private var controls: some View {
        HStack(spacing: 0) {
            Button { model.showCurrentWeek() } label: {
                Text("Today").font(.subheadline.weight(.medium))
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }.foregroundStyle(NotebookStyle.clay).padding(.trailing, 4)
                .accessibilityHint("Return to the current week").accessibilityIdentifier("today-week")
            Button { model.changeWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("Previous week").accessibilityIdentifier("previous-week")
            Button { model.changeWeek(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel("Next week").accessibilityIdentifier("next-week")
        }.fixedSize().accessibilityElement(children: .contain).accessibilityIdentifier("week-navigation-controls")
    }
}
