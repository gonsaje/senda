import SwiftUI
import SendaDomain
import SendaLogger

struct LiftReferencesView: View {
    @Bindable var model: LoggerModel

    var body: some View {
        let history = model.exerciseHistory
        VStack(alignment: .leading, spacing: 9) {
            if let best = history.personalBest {
                Button { model.beginEditingSets(batchID: best.batchID) } label: {
                    row("PR", value: EntryText.set(best.values))
                }
                .disabled(model.isEditingRecorded && model.recorded?.id == best.batchID)
                .accessibilityLabel("PR, \(EntryText.set(best.values)), heaviest recorded set")
                .accessibilityHint("Edit the recorded entry")
                .accessibilityIdentifier("personal-best-reference")
            }
            if let common = history.commonWorkingSet {
                row("Common", value: EntryText.working(common))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Common working set, \(EntryText.working(common)), based on \(common.occurrenceCount) performed sets")
                    .accessibilityIdentifier("common-working-reference")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NotebookStyle.clay.opacity(0.055))
    }

    private func row(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(NotebookStyle.clay)
                .fixedSize().frame(width: 58, alignment: .leading)
            Text(value).font(.system(size: 15).monospacedDigit()).foregroundStyle(NotebookStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        .contentShape(Rectangle())
    }
}
