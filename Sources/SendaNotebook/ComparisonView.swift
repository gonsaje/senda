import SwiftUI
import SendaDomain

struct ComparisonView: View {
    let comparison: EntryComparison

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                row(comparison.previous)
                row(comparison.current)
                if let difference = comparison.repDifferenceAtSameWeight {
                    Text(difference == 0 ? "Same reps at the same weight" :
                        "\(abs(difference)) \(difference < 0 ? "fewer" : "more") \(abs(difference) == 1 ? "rep" : "reps") at the same weight")
                        .font(.subheadline).foregroundStyle(NotebookStyle.ink)
                } else {
                    Text("Compare load and reps by set.").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }
            }.padding(.top, 13)
        } label: {
            Text("Compare last entry").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
        }
        .accessibilityIdentifier("compare-entries")
    }

    private func row(_ batch: RecordedBatch) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(EntryText.date(batch.recordedAt)).font(.caption).foregroundStyle(NotebookStyle.quiet)
            Text(EntryText.summary(batch.values)).font(.system(.caption, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
