import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingDayExerciseList: View {
    @Bindable private var model: TrainingNotebookModel
    private let day: TrainingDay
    private let close: () -> Void
    private let add: () -> Void

    public init(model: TrainingNotebookModel, day: TrainingDay, close: @escaping () -> Void, add: @escaping () -> Void) {
        self.model = model; self.day = day; self.close = close; self.add = add
    }

    private var exercises: [Exercise] { model.selectedDay == day ? model.tabs : [] }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button(action: close) { Label("Day", systemImage: "chevron.left").frame(minHeight: 44) }
                    .accessibilityIdentifier("close-day-exercises")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your exercises").font(NotebookTypography.heading(32))
                        .accessibilityIdentifier("day-exercises-title")
                    Text("\(TrainingText.date(day, format: "EEEE, MMM d")) · \(exercises.count) exercises")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }
                VStack(spacing: 0) {
                    ForEach(exercises) { exercise in
                        let count = model.loggedSetCount(for: exercise.id, on: day)
                        let selected = model.exercise?.id == exercise.id
                        Button {
                            if model.selectedDay == day && model.selectExercise(exercise.id) { close() }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name).font(.body.weight(selected ? .semibold : .regular))
                                        .foregroundStyle(NotebookStyle.ink).fixedSize(horizontal: false, vertical: true)
                                    Text(countLabel(count)).font(.caption.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(NotebookStyle.quiet)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 14).frame(minHeight: 70)
                            .background(selected ? NotebookStyle.clay.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(alignment: .leading) {
                                if selected { Capsule().fill(NotebookStyle.clay).frame(width: 2).padding(.vertical, 10) }
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("\(exercise.name), \(countLabel(count))")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("day-exercise-\(exercise.id)")
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    }
                    if exercises.isEmpty {
                        Text("No exercises yet").font(.callout).foregroundStyle(NotebookStyle.quiet).padding(.vertical, 20)
                    }
                }
                Button {
                    if model.selectedDay == day { add() }
                } label: {
                    Label("Add exercise", systemImage: "plus").frame(minHeight: 48)
                }.foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("day-list-add-exercise")
                if let error = model.errorMessage { Text(error).font(.callout).foregroundStyle(NotebookStyle.clay) }
            }
            .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("day-exercises-scroll")
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 393, minHeight: 568, idealHeight: 740)
        #endif
    }

    private func countLabel(_ count: Int) -> String {
        count == 0 ? "No sets yet" : "\(count) \(count == 1 ? "set" : "sets")"
    }
}
