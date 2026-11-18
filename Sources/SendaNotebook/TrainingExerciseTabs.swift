import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingWorkoutExerciseList: View {
    let exercises: [Exercise]
    let selectedID: String?
    let select: (String) -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var visibleID: String?
    @State private var viewportWidth: CGFloat = .infinity

    init(exercises: [Exercise], selectedID: String?, select: @escaping (String) -> Void) {
        self.exercises = exercises
        self.selectedID = selectedID
        self.select = select
        _visibleID = State(initialValue: selectedID)
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(exercises) { exercise in
                    tab(exercise).id(exercise.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.visible, axes: .horizontal)
        .scrollIndicatorsFlash(onAppear: true)
        .scrollPosition(id: $visibleID, anchor: .center)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
            if width > 0 { viewportWidth = width }
        }
        .onChange(of: selectedID) { _, id in visibleID = id }
        .accessibilityIdentifier("workout-exercises")
    }

    private func tab(_ exercise: Exercise) -> some View {
        let selected = exercise.id == selectedID
        let labelLayout = textSize >= .accessibility3
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 5))
        return Button { select(exercise.id) } label: {
            ExerciseTabWidth(limit: viewportWidth) {
                labelLayout {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NotebookStyle.clay)
                        .opacity(selected ? 1 : 0)
                        .accessibilityHidden(true)
                    // Reserve the selected label's wrapped height so switching keeps the editor in place.
                    Text(exercise.displayName)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .overlay(alignment: .topLeading) {
                            Text(exercise.displayName)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .frame(minWidth: 44, minHeight: 44)
            }
            .foregroundStyle(selected ? NotebookStyle.ink : NotebookStyle.quiet)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(exercise.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("exercise-\(exercise.id)")
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
