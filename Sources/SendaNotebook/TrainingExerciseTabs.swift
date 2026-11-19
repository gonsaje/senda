import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingWorkoutExerciseList<Add: View>: View {
    let exercises: [Exercise]
    let selectedID: String?
    let select: (String) -> Bool
    @ViewBuilder let add: () -> Add
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @FocusState private var keyboardExercise: String?
    @Namespace private var underline
    @State private var viewportWidth: CGFloat = .infinity
    @State private var overflowEdges: Edge.Set = []

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.22)
    }

    var body: some View {
        let leftToRight = layoutDirection == .leftToRight
        HStack(spacing: 4) {
            ScrollViewReader { reader in
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 16) {
                        ForEach(exercises) { exercise in
                            ExerciseTabWidth(limit: viewportWidth) {
                                tab(exercise)
                            }.id(exercise.id)
                        }
                    }
                    .animation(selectionAnimation, value: selectedID)
                    .onGeometryChange(for: Edge.Set.self) { geometry in
                        guard let visible = geometry.bounds(of: .scrollView(axis: .horizontal)),
                              geometry.size.width > visible.width + 1 else { return [] }
                        var edges: Edge.Set = []
                        if visible.minX > 1 { edges.insert(leftToRight ? .leading : .trailing) }
                        if visible.maxX < geometry.size.width - 1 { edges.insert(leftToRight ? .trailing : .leading) }
                        return edges
                    } action: { overflowEdges = $0 }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.never)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
                    if width > 0 { viewportWidth = width }
                }
                .onChange(of: selectedID, initial: true) { old, id in
                    guard let id else { return }
                    // Browsing the scroll view never writes back to the selected exercise.
                    withAnimation(old == nil || old == id ? nil : selectionAnimation) {
                        reader.scrollTo(id)
                    }
                }
                .overlay(alignment: .leading) { if overflowEdges.contains(.leading) { overflowLip(at: .leading) } }
                .overlay(alignment: .trailing) { if overflowEdges.contains(.trailing) { overflowLip(at: .trailing) } }
                .accessibilityIdentifier("workout-exercises")
            }
            add().fixedSize()
        }
        .background(alignment: .bottom) {
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
        }
    }

    private func overflowLip(at edge: HorizontalEdge) -> some View {
        let leading = edge == .leading
        let fromLeft = leading == (layoutDirection == .leftToRight)
        let surface = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return LinearGradient(colors: [NotebookStyle.ivory, NotebookStyle.ivory.opacity(0)],
                              startPoint: fromLeft ? .leading : .trailing, endPoint: fromLeft ? .trailing : .leading)
            .frame(width: 16)
            .overlay(alignment: leading ? .leading : .trailing) {
                // Only the inner four points of the stationary surface meet the scrolling labels.
                surface.fill(NotebookStyle.ivory)
                    .overlay { surface.strokeBorder(NotebookStyle.tabEdgeHighlight, lineWidth: 0.5) }
                    .shadow(color: NotebookStyle.tabEdgeShadow, radius: 3.5)
                    .frame(width: 22)
                    .padding(leading ? .leading : .trailing, -18)
                    .padding(.vertical, 4)
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func tab(_ exercise: Exercise) -> some View {
        let selected = exercise.id == selectedID
        let font = NotebookTypography.heading(18, relativeTo: .headline)
        return Button { _ = select(exercise.id) } label: {
            // Reserve both label widths so changing weight never moves another tab.
            ZStack(alignment: .leading) {
                Text(exercise.displayName).font(font.weight(.regular)).opacity(selected ? 0 : 1)
                Text(exercise.displayName).font(font).opacity(selected ? 1 : 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 2).padding(.vertical, 7)
            .frame(minWidth: 44, minHeight: 46, alignment: .leading)
            .foregroundStyle(selected ? NotebookStyle.ink : NotebookStyle.quiet)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if selected {
                    Capsule().fill(NotebookStyle.clay).frame(height: 3)
                        .matchedGeometryEffect(id: "selection", in: underline)
                        .transition(.identity)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(exercise.displayName)
        .accessibilityAddTraits(selected ? [.isSelected, .isHeader] : [])
        .accessibilityIdentifier("exercise-\(exercise.id)")
        .focused($keyboardExercise, equals: exercise.id)
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { key in
            guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return .ignored }
            let forward = (key.key == .rightArrow) == (layoutDirection == .leftToRight)
            let next = index + (forward ? 1 : -1)
            if exercises.indices.contains(next), select(exercises[next].id) { keyboardExercise = exercises[next].id }
            return .handled
        }
    }
}


/// A horizontal scroll view proposes unlimited width. Give long names a finite
/// text layout proposal while letting shorter tabs keep their natural widths.
private struct ExerciseTabWidth: Layout {
    let limit: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let label = subviews.first else { return .zero }
        let width = min(label.sizeThatFits(.unspecified).width, limit)
        return label.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                              proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

struct TrainingWorkoutOptions: View {
    let model: TrainingNotebookModel
    let day: TrainingDay
    let showAll: () -> Void
    let chooseWorkout: () -> Void
    let saveTemplate: () -> Void
    let beginNavigation: () -> Void

    var body: some View {
        Menu {
            Button(action: showAll) {
                Label("All \(model.indexedExercises(on: day).count) exercises", systemImage: "list.bullet")
            }
            .accessibilityIdentifier("all-exercises")
            if !model.tabs.isEmpty {
                Button(action: chooseWorkout) {
                    Label("Choose workout", systemImage: "list.bullet.rectangle")
                }
                .accessibilityIdentifier("choose-workout")
                Button(action: saveTemplate) {
                    Label("Save as template", systemImage: "bookmark")
                }
                .accessibilityIdentifier("day-save-template")
                Menu("Hide an exercise") {
                    ForEach(model.tabs) { exercise in
                        Button(exercise.displayName) { beginNavigation(); model.removeExercise(exercise.id) }
                            .accessibilityHint("Keep recorded sets and unfinished input in all exercises")
                            .accessibilityIdentifier("hide-exercise-\(exercise.id)")
                    }
                }
                .accessibilityIdentifier("hide-exercise-menu")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.medium))
                .frame(width: 46, height: 46)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
        .foregroundStyle(NotebookStyle.quiet)
        .accessibilityLabel("Workout options")
        .accessibilityIdentifier("workout-options")
    }
}
