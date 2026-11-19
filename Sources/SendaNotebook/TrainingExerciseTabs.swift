import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingWorkoutExerciseList<Add: View>: View {
    let exercises: [Exercise]
    let selectedID: String?
    let select: (String) -> Void
    @ViewBuilder let add: () -> Add
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var visibleID: String?
    @State private var viewportWidth: CGFloat = .infinity

    init(exercises: [Exercise], selectedID: String?, select: @escaping (String) -> Void,
         @ViewBuilder add: @escaping () -> Add) {
        self.exercises = exercises
        self.selectedID = selectedID
        self.select = select
        self.add = add
        _visibleID = State(initialValue: selectedID)
    }

    var body: some View {
        if exercises.count <= 6 && !textSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Exercises").font(NotebookTypography.heading(17, relativeTo: .headline)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    add()
                }
                Divider()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: min(2, exercises.count)),
                          alignment: .leading, spacing: 0) {
                    ForEach(exercises) { exercise in
                        tab(exercise, fillsColumn: true)
                            .overlay(alignment: .bottom) { exerciseRule }
                    }
                }.accessibilityIdentifier("workout-exercises")
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                scrollingTabs
                add().fixedSize()
            }
            .overlay(alignment: .bottom) { exerciseRule }
        }
    }

    private var exerciseRule: some View {
        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
    }

    private var scrollingTabs: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(exercises) { exercise in
                    ExerciseTabWidth(limit: viewportWidth) {
                        tab(exercise, fillsColumn: false)
                    }.id(exercise.id)
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

    private func tab(_ exercise: Exercise, fillsColumn: Bool) -> some View {
        let selected = exercise.id == selectedID
        return Button { select(exercise.id) } label: {
            // Both weights size the tab so a selection change cannot shift its neighbors.
            ZStack(alignment: .topLeading) {
                Text(exercise.displayName).font(.subheadline)
                    .opacity(selected ? 0 : 1)
                Text(exercise.displayName).font(.subheadline.bold())
                    .opacity(selected ? 1 : 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .foregroundStyle(selected ? NotebookStyle.ivory : NotebookStyle.quiet)
            .background(selected ? NotebookStyle.ink : .clear, in: RoundedRectangle(cornerRadius: 8))
            .frame(minWidth: 44, maxWidth: fillsColumn ? .infinity : nil, minHeight: 44, alignment: .leading)
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
