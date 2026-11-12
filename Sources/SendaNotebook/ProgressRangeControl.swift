import SwiftUI
import SendaDomain

struct ProgressRangeControl: View {
    @Binding var selection: ExerciseProgressRange
    let identifierPrefix: String
    @Environment(\.dynamicTypeSize) private var textSize

    private var columns: [GridItem] {
        let count = textSize.isAccessibilitySize ? 1 : textSize >= .xxLarge ? 2 : 4
        return Array(repeating: GridItem(.flexible(minimum: 44), spacing: 8), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(ExerciseProgressRange.allCases, id: \.self) { range in
                let selected = selection == range
                Button { selection = range } label: {
                    HStack(spacing: 6) {
                        if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
                        Text(textSize.isAccessibilitySize ? range.label : range.rawValue.uppercased())
                    }
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(selected ? NotebookStyle.ivory : NotebookStyle.ink)
                    .background(selected ? NotebookStyle.ink : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? .clear : NotebookStyle.rule, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(range.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("\(identifierPrefix)-\(range.rawValue)")
            }
        }
    }
}

private extension ExerciseProgressRange {
    var label: String {
        switch self {
        case .oneMonth: "1 month"
        case .threeMonths: "3 months"
        case .sixMonths: "6 months"
        case .oneYear: "1 year"
        }
    }
}
