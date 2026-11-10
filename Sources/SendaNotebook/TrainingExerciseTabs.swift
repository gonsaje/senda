import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingExerciseMenu: View {
    @Bindable var model: TrainingNotebookModel
    let day: TrainingDay
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
            Divider()
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
                    .font(NotebookTypography.heading(27, italic: true))
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
        .foregroundStyle(NotebookStyle.ink)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(model.exercise?.name ?? "Exercises")
        .accessibilityHint("Switch exercise, view all exercises, or hide an exercise from this menu")
        .accessibilityIdentifier("entry-exercise")
    }
}
