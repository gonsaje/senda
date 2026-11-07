import SwiftUI
import SendaLogger

struct WorkoutExerciseTabs: View {
    @Bindable var model: LoggerModel
    var add: () -> Void
    @State private var visibleTabID: String?

    init(model: LoggerModel, add: @escaping () -> Void) {
        self.model = model; self.add = add
        _visibleTabID = State(initialValue: model.selectedExerciseID)
    }
    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 25) {
                    ForEach(model.workoutExercises) { exercise in
                        Button { model.selectExercise(exercise.id) } label: {
                            VStack(spacing: 4) {
                                Text(exercise.shortName)
                                    .font(.body.weight(exercise.id == model.selectedExerciseID ? .semibold : .regular))
                                    .foregroundStyle(exercise.id == model.selectedExerciseID ? NotebookStyle.ink : NotebookStyle.quiet)
                                    .lineLimit(1).frame(maxWidth: 180)
                                Rectangle().fill(exercise.id == model.selectedExerciseID ? NotebookStyle.clay : .clear).frame(height: 2)
                            }.frame(minHeight: 44)
                        }
                        .accessibilityLabel(exercise.name)
                        .accessibilityAddTraits(exercise.id == model.selectedExerciseID ? .isSelected : [])
                        .accessibilityIdentifier("lift-\(exercise.id)")
                        .contextMenu {
                            Button("Remove from workout", role: .destructive) { model.removeExercise(exercise.id) }
                                .disabled(model.workoutExercises.count == 1)
                                .accessibilityIdentifier("remove-workout-\(exercise.id)")
                        }
                        .id(exercise.id)
                    }
                }.scrollTargetLayout()
            }
            .scrollIndicators(.hidden).scrollPosition(id: $visibleTabID, anchor: .center)
            .accessibilityIdentifier("workout-exercises")
            Button(action: add) {
                Image(systemName: "plus").font(.system(size: 20, weight: .regular)).frame(width: 44, height: 44)
            }
            .foregroundStyle(NotebookStyle.clay)
            .accessibilityLabel("Add exercise").accessibilityIdentifier("add-exercise")
        }
        .onChange(of: model.selectedExerciseID) { _, id in visibleTabID = id }
    }
}
