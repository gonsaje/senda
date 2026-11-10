import SwiftUI
import SendaDomain

struct ProgressRangeControl: View {
    @Binding var selection: ExerciseProgressRange
    let identifierPrefix: String
    @Environment(\.dynamicTypeSize) private var textSize

    private var layout: AnyLayout {
        textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    var body: some View {
        layout {
            ForEach(ExerciseProgressRange.allCases, id: \.self) { range in
                let selected = selection == range
                Button { selection = range } label: {
                    HStack(spacing: 6) {
                        if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
                        Text("\(range.rawValue) weeks")
                    }
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .padding(.horizontal, 8)
                        .foregroundStyle(selected ? NotebookStyle.ivory : NotebookStyle.ink)
                        .background(selected ? NotebookStyle.ink : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? .clear : NotebookStyle.rule, lineWidth: 1))
                }
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("\(identifierPrefix)-\(range.rawValue)")
            }
        }
    }
}
