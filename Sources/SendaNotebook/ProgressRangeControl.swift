import SwiftUI
import SendaDomain

struct ProgressRangeControl: View {
    @Binding var selection: ExerciseProgressRange
    let identifierPrefix: String
    var showsSelection = true
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        ViewThatFits(in: .horizontal) {
            rangeRow
            ScrollViewReader { proxy in
                ScrollView(.horizontal) { rangeRow }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        if showsSelection { proxy.scrollTo(selection, anchor: .center) }
                    }
            }
        }
        .padding(2)
        .background(NotebookStyle.inputSurface, in: NotebookStyle.squircle(10))
    }

    private var rangeRow: some View {
        HStack(spacing: 0) {
            ForEach(ExerciseProgressRange.allCases, id: \.self) { range in
                let selected = showsSelection && selection == range
                Button { selection = range } label: {
                    Text(textSize.isAccessibilitySize ? range.label : range.rawValue.uppercased())
                        .font(.subheadline.weight(selected ? .bold : .regular))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 4)
                        .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(selected ? NotebookStyle.ivory : NotebookStyle.ink)
                        .background(selected ? NotebookStyle.ink : .clear, in: NotebookStyle.squircle(8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(range.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("\(identifierPrefix)-\(range.rawValue)")
                .id(range)
            }
        }
    }
}

private extension ExerciseProgressRange {
    var label: String {
        switch self {
        case .oneDay: "1 day"
        case .oneWeek: "1 week"
        case .oneMonth: "1 month"
        case .threeMonths: "3 months"
        case .sixMonths: "6 months"
        case .oneYear: "1 year"
        case .yearToDate: "Year to date"
        }
    }
}
