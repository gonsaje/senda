import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingWorkoutReusePicker: View {
    @Bindable private var model: TrainingNotebookModel
    private let close: () -> Void
    private let back: (() -> Void)?
    public init(model: TrainingNotebookModel, close: @escaping () -> Void) {
        self.model = model; self.close = close; self.back = nil
    }
    init(model: TrainingNotebookModel, close: @escaping () -> Void, back: @escaping () -> Void) {
        self.model = model; self.close = close; self.back = back
    }

    public var body: some View {
        TrainingWorkoutLibrary(model: model, initialTab: .recent, back: back, close: close)
    }
}

struct WorkoutHistoryPreview: View {
    let model: TrainingNotebookModel
    let workout: TrainingWorkoutStructure

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TrainingText.date(workout.day, format: "EEEE, MMM d, yyyy"))
                .font(NotebookTypography.heading(31)).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("\(workout.recordedSetCount) logged \(workout.recordedSetCount == 1 ? "set" : "sets")")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            VStack(alignment: .leading, spacing: 0) {
                WorkoutLibraryRule()
                ForEach(workout.exerciseIDs, id: \.self) { id in
                    recordedExercise(model.exercise(id))
                    WorkoutLibraryRule()
                }
            }
        }
    }

    private func recordedExercise(_ exercise: Exercise) -> some View {
        let rows = model.workspace.days[workout.day.rawValue]?.rows[exercise.id] ?? []
        let entries = TrainingSetEntry.grouping(rows).filter { $0.rows.contains { $0.performedSetID != nil } }
        return VStack(alignment: .leading, spacing: 6) {
            Text(exercise.displayName).font(NotebookTypography.heading(17, relativeTo: .body)).accessibilityAddTraits(.isHeader)
            if exercise.isArchived {
                Text("Removed from library").font(.caption).foregroundStyle(NotebookStyle.quiet)
            }
            if entries.isEmpty {
                Text("No logged sets").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            }
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if entry.isDropSet {
                    Text("Set \(index + 1) · Drop set").font(.subheadline.weight(.medium))
                }
                ForEach(Array(entry.rows.enumerated()), id: \.element.id) { stage, row in
                    if let values = model.recordedValues(for: row) {
                        let label = entry.isDropSet ? (stage == 0 ? "Start" : "Drop \(stage)") : "Set \(index + 1)"
                        let result = ProgressFormatting.set(values, exercise: exercise, unit: row.unit)
                        let kind = row.kind == .warmup ? " · Warm-up" : ""
                        Text("\(label) · \(result)\(kind)")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}
