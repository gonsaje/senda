import SwiftUI
import SendaDomain

struct TrainingExerciseMarkerRail: View {
    let exercises: [Exercise]
    let selectedID: String
    let isExpanded: Bool
    let select: (String) -> Void
    let add: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tapTarget: CGFloat = 44
    private let visibleLimit = 5

    private var dotPitch: CGFloat { isExpanded ? 17 : 12 }

    private var selectedIndex: Int { exercises.firstIndex { $0.id == selectedID } ?? 0 }

    private var visibleIndices: Range<Int> {
        let count = min(visibleLimit, exercises.count)
        let first = min(max(0, selectedIndex - count / 2), exercises.count - count)
        return first..<(first + count)
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(width: tapTarget, height: tapTarget)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            if !exercises.isEmpty { pages }
            Button(action: add) {
                Image(systemName: "plus.circle")
                    .font(.system(size: isExpanded ? 18 : 13, weight: .medium))
                    .foregroundStyle(isExpanded ? NotebookStyle.clay : NotebookStyle.quiet)
                    .background(NotebookStyle.ivory, in: Circle())
                    .frame(width: 20)
                    .padding(.trailing, 2)
                    .frame(width: tapTarget, height: tapTarget, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add exercise")
            .accessibilityIdentifier("add-exercise")
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: isExpanded ? 0.15 : 0.26), value: isExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-exercises")
    }

    private var pages: some View {
        let indices = visibleIndices
        // Keep the touch area and add button anchored as the visible dots settle.
        let height = max(tapTarget, CGFloat(indices.count) * 17 + 10)
        return VStack(spacing: 0) {
            ForEach(indices, id: \.self) { index in
                let active = index == selectedIndex
                let continues = (index == indices.first && index > 0)
                    || (index == indices.last && index + 1 < exercises.count)
                let width: CGFloat = active ? (isExpanded ? 7 : 4) : (continues ? 3 : (isExpanded ? 5 : 4))
                Capsule()
                    .fill(active ? NotebookStyle.clay : NotebookStyle.quiet.opacity(isExpanded ? 0.85 : 0.65))
                    .frame(width: width, height: active ? (isExpanded ? 14 : 8) : width)
                    .frame(height: dotPitch)
            }
        }
        .padding(.vertical, isExpanded ? 5 : 3)
        .frame(width: isExpanded ? 19 : 12)
        .background(NotebookStyle.ivory, in: Capsule())
        .overlay { Capsule().strokeBorder(NotebookStyle.rule.opacity(isExpanded ? 1 : 0.65)) }
        .frame(width: 20)
        .padding(.trailing, 2)
        .frame(width: tapTarget, height: height, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { point in
            let top = (height - CGFloat(indices.count) * dotPitch) / 2
            let offset = Int(floor((point.y - top) / dotPitch))
            let index = indices.lowerBound + min(max(0, offset), indices.count - 1)
            select(exercises[index].id)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selectedID)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Workout exercises")
        .accessibilityValue("\(exercises[selectedIndex].displayName), exercise \(selectedIndex + 1) of \(exercises.count)")
        .accessibilityAdjustableAction { direction in
            let index: Int
            switch direction {
            case .increment: index = selectedIndex + 1
            case .decrement: index = selectedIndex - 1
            @unknown default: return
            }
            if exercises.indices.contains(index) { select(exercises[index].id) }
        }
        .accessibilityIdentifier("workout-exercise-pages")
    }
}
