import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingDayExerciseList: View {
    @Bindable private var model: TrainingNotebookModel
    private let day: TrainingDay
    private let close: () -> Void
    private let add: () -> Void
    @State private var pendingExerciseID: String?

    public init(model: TrainingNotebookModel, day: TrainingDay, close: @escaping () -> Void, add: @escaping () -> Void) {
        self.model = model; self.day = day; self.close = close; self.add = add
    }

    private var exercises: [Exercise] { model.indexedExercises(on: day) }
    private var visibleIDs: [String] { model.workspace.days[day.rawValue]?.exerciseIDs ?? [] }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button { cancelPendingSelection(); close() } label: { Label("Day", systemImage: "chevron.left").frame(minHeight: 44) }
                    .accessibilityIdentifier("close-day-exercises")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your exercises").font(NotebookTypography.heading(32))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("day-exercises-title")
                    Text("\(TrainingText.date(day, format: "EEEE, MMM d")) · \(exercises.count) exercises")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    if exercises.contains(where: { !visibleIDs.contains($0.id) }) {
                        Text("Hidden tabs keep their sets and input. Choose one to show its tab again.")
                            .font(.callout).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(exercises) { exercise in
                        let count = model.loggedSetCount(for: exercise.id, on: day)
                        let selected = model.exercise?.id == exercise.id
                        let hidden = !visibleIDs.contains(exercise.id)
                        Button {
                            cancelPendingSelection()
                            guard model.selectedDay == day else { return }
                            pendingExerciseID = exercise.id
                            let saved = hidden ? model.addExercise(exercise.id) : model.selectExercise(exercise.id)
                            if saved { completePendingSelection() }
                            else if !model.canRetrySave { pendingExerciseID = nil }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name).font(.body.weight(selected ? .semibold : .regular))
                                        .foregroundStyle(NotebookStyle.ink).fixedSize(horizontal: false, vertical: true)
                                    Text(countLabel(count)).font(.caption.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                                    if hidden {
                                        Text(count == 0 ? "Hidden tab · Input retained" : "Hidden tab · Sets retained")
                                            .font(.caption).foregroundStyle(NotebookStyle.clay).fixedSize(horizontal: false, vertical: true)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: selected ? "checkmark" : hidden ? "eye" : "chevron.right")
                                    .font(.body.weight(selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.quiet)
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 14).frame(minHeight: 70)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("\(exercise.name), \(countLabel(count))\(hidden ? ", Hidden tab, retained work" : "")")
                        .accessibilityHint(hidden ? "Restore its tab and open retained sets and input" : "Open exercise")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("day-exercise-\(exercise.id)")
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    }
                    if exercises.isEmpty {
                        Text("No exercises yet").font(.callout).foregroundStyle(NotebookStyle.quiet).padding(.vertical, 20)
                    }
                }
                Button {
                    if model.selectedDay == day { cancelPendingSelection(); add() }
                } label: {
                    Label("Add exercise", systemImage: "plus").frame(minHeight: 48)
                }.foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("day-list-add-exercise")
            }
            .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if let error = model.errorMessage {
                TrainingSaveError(model: model, message: error, retrySucceeded: completePendingSelection)
                    .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory)
            }
        }
        .scrollIndicators(.never)
        .accessibilityIdentifier("day-exercises-scroll")
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
        .onChange(of: model.canRetrySave) { _, _ in completePendingSelection() }
        .onChange(of: model.errorMessage) { _, _ in completePendingSelection() }
        .onChange(of: model.selectedDay) { _, _ in pendingExerciseID = nil }
        .onDisappear { cancelPendingSelection() }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 393, minHeight: 568, idealHeight: 740)
        #endif
    }

    private func completePendingSelection() {
        guard let id = pendingExerciseID, model.selectedDay == day, model.errorMessage == nil, !model.canRetrySave,
              visibleIDs.contains(id), model.exercise?.id == id else { return }
        pendingExerciseID = nil; close()
    }
    private func cancelPendingSelection() {
        guard pendingExerciseID != nil else { return }
        pendingExerciseID = nil; _ = model.cancelPendingAction()
    }

    private func countLabel(_ count: Int) -> String {
        count == 0 ? "No sets yet" : "\(count) \(count == 1 ? "set" : "sets")"
    }
}
