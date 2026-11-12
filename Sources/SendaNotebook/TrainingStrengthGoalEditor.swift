import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingStrengthGoalEditor: View {
    @Bindable var model: TrainingNotebookModel
    let close: () -> Void
    private let goal: StrengthGoal?
    private let unit: WeightUnit
    private let initialWeight: String
    private let initialReps: String
    @State private var goalID: UUID
    @State private var exerciseID: String?
    @State private var weight: String
    @State private var reps: String
    @State private var errorMessage: String?
    @State private var confirmsRemoval = false
    @Environment(\.dynamicTypeSize) private var textSize

    init(model: TrainingNotebookModel, goal: StrengthGoal?, close: @escaping () -> Void) {
        self.model = model
        self.goal = goal
        self.close = close
        let unit = model.workspace.preferredUnit
        self.unit = unit
        let initialWeight = goal.map { unit.text(for: $0.target.weight) } ?? ""
        let initialReps = goal.map { String($0.target.reps) } ?? ""
        self.initialWeight = initialWeight
        self.initialReps = initialReps
        _goalID = State(initialValue: goal?.id ?? UUID())
        _exerciseID = State(initialValue: goal?.exerciseID)
        _weight = State(initialValue: initialWeight)
        _reps = State(initialValue: initialReps)
    }

    private var exercise: Exercise? { exerciseID.map { model.exercise($0) } }

    private var exercises: [Exercise] {
        var exercises = model.exercises
        if let exercise, !exercises.contains(where: { $0.id == exercise.id }) {
            exercises.append(exercise)
        }
        return exercises.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var hasDraft: Bool {
        exerciseID != goal?.exerciseID || weight != initialWeight || reps != initialReps
    }

    var body: some View {
        VStack(spacing: 0) {
            actions
                .padding(.horizontal, 24).padding(.vertical, 8)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            rule
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(goal == nil ? "New goal" : "Edit goal")
                        .font(NotebookTypography.heading(31))
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    exercisePicker
                    targets
                    if exercise?.requiresWeight == false {
                        Text("Leave added weight blank for body weight.")
                            .font(.subheadline)
                            .foregroundStyle(NotebookStyle.quiet)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(NotebookStyle.clay)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("strength-goal-save-error")
                    }
                    if goal != nil {
                        Button(role: .destructive) { confirmsRemoval = true } label: {
                            Text("Remove goal")
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .foregroundStyle(NotebookStyle.clay)
                        .accessibilityIdentifier("remove-strength-goal")
                    }
                }
                .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .clipped()
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("strength-goal-editor-scroll")
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .textFieldStyle(.plain)
        .scrollIndicators(.never)
        .interactiveDismissDisabled(hasDraft || errorMessage != nil)
        .confirmationDialog("Remove this goal?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button("Remove goal", role: .destructive, action: remove)
                .accessibilityIdentifier("confirm-remove-strength-goal")
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button(action: close) {
                Text("Cancel")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("cancel-strength-goal")
            Spacer(minLength: 0)
            Button(action: save) {
                Text("Save")
                    .fontWeight(.semibold)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(NotebookStyle.clay)
            .accessibilityIdentifier("save-strength-goal")
        }
    }

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Exercise").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            Menu {
                ForEach(exercises) { option in
                    Button {
                        exerciseID = option.id
                        errorMessage = nil
                    } label: {
                        if exerciseID == option.id { Label(option.name, systemImage: "checkmark") }
                        else { Text(option.name) }
                    }
                    .accessibilityAddTraits(exerciseID == option.id ? .isSelected : [])
                    .accessibilityIdentifier("strength-goal-exercise-\(option.id)")
                }
            } label: {
                HStack(spacing: 8) {
                    Text(exercise?.name ?? "Choose exercise")
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.caption)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(NotebookStyle.clay)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Exercise")
            .accessibilityValue(exercise?.name ?? "Choose exercise")
            .accessibilityIdentifier("strength-goal-exercise")
            rule
        }
    }

    private var targets: some View {
        let layout = textSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        let weightTitle = exercise?.requiresWeight == false ? "Added weight" : "Target weight"
        return layout {
            targetField("\(weightTitle) (\(unit.symbol))", text: $weight,
                decimal: true, identifier: "strength-goal-weight")
            targetField("Target reps", text: $reps, decimal: false, identifier: "strength-goal-reps")
        }
    }

    private func targetField(_ title: String, text: Binding<String>, decimal: Bool, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
            TextField(title, text: text, prompt: Text("—"))
                .numericKeyboard(decimal: decimal)
                .font(.title3.monospacedDigit())
                .frame(minHeight: 44)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
                .onChange(of: text.wrappedValue) { _, _ in errorMessage = nil }
            rule
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rule: some View {
        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
    }

    private func save() {
        guard let exercise else { return report("Choose an exercise.") }
        let targetWeight: Int?
        if let goal, weight == initialWeight {
            targetWeight = goal.target.weight
        } else if weight.isEmpty && !exercise.requiresWeight {
            targetWeight = 0
        } else {
            targetWeight = unit.parse(weight)
        }
        guard let targetWeight, targetWeight > 0 || !exercise.requiresWeight else {
            return report(exercise.requiresWeight
                ? "Enter a target weight greater than zero."
                : "Enter a valid added weight or leave it blank.")
        }
        guard let targetReps = NumericField.reps.parse(reps) else {
            return report("Enter 1 to 999 reps.")
        }
        let updated = StrengthGoal(id: goalID, exerciseID: exercise.id,
            target: SetValues(weight: targetWeight, reps: targetReps))
        if model.profile.saveGoal(updated) { close() }
        else { report(model.profile.errorMessage ?? "Couldn’t save the goal. Try again.") }
    }

    private func remove() {
        guard let goal else { return }
        if model.profile.removeGoal(goal.id) { close() }
        else { report(model.profile.errorMessage ?? "Couldn’t remove the goal. Try again.") }
    }

    private func report(_ message: String) {
        errorMessage = message
        TrainingAccessibility.announce(message)
    }
}
