import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingExerciseMenu: View {
    @Bindable var model: TrainingNotebookModel
    let day: TrainingDay
    var addExercise: () -> Void
    var showAll: () -> Void
    var beginNavigation: () -> Void = {}

    var body: some View {
        Menu {
            ForEach(model.tabs) { exercise in
                let selected = model.exercise?.id == exercise.id
                Button { beginNavigation(); model.selectExercise(exercise.id) } label: {
                    if selected { Label(exercise.name, systemImage: "checkmark") }
                    else { Text(exercise.name) }
                }
                .font(.body.weight(selected ? .semibold : .regular))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("exercise-\(exercise.id)")
            }
            if !model.tabs.isEmpty { Divider() }
            Button(action: addExercise) {
                Label("Add exercise", systemImage: "plus")
            }.accessibilityIdentifier("add-exercise")
            Button(action: showAll) {
                Label("All \(model.indexedExercises(on: day).count) exercises", systemImage: "list.bullet")
            }.accessibilityIdentifier("all-exercises")
            if !model.tabs.isEmpty {
                Menu("Hide an exercise") {
                    ForEach(model.tabs) { exercise in
                        Button(exercise.name) { beginNavigation(); model.removeExercise(exercise.id) }
                            .accessibilityHint("Keep recorded sets and unfinished input in all exercises")
                            .accessibilityIdentifier("hide-exercise-\(exercise.id)")
                    }
                }.accessibilityIdentifier("hide-exercise-menu")
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.exercise?.name ?? "Exercises")
                    .font(NotebookTypography.heading(32, italic: true, relativeTo: .largeTitle))
                    .foregroundStyle(NotebookStyle.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(NotebookStyle.quiet)
                    .accessibilityHidden(true)
            }
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
        .foregroundStyle(NotebookStyle.ink)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(model.exercise?.name ?? "Exercises")
        .accessibilityHint("Switch, add, view, or hide exercises")
        .accessibilityIdentifier("entry-exercise")
    }
}
