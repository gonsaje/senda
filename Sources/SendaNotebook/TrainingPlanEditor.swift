import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingMetadataContext: Identifiable {
    let id = UUID()
    let day: TrainingDay
    let exerciseID: String
    let rowIDs: [UUID]

    @MainActor func matches(_ model: TrainingNotebookModel) -> Bool {
        model.selectedDay == day && model.exercise?.id == exerciseID &&
            model.workspace.days[day.rawValue]?.rows[exerciseID]?.map(\.id) == rowIDs
    }
}

public struct TrainingPlanEditor: View {
    @Bindable var model: TrainingNotebookModel
    let context: TrainingMetadataContext
    let close: () -> Void
    @State private var workingSets: Int
    @State private var minimumReps: Int
    @State private var maximumReps: Int
    @State private var pending = false
    @State private var pendingPlan: ExercisePlan?
    @State private var beganEditing = false

    public init(model: TrainingNotebookModel, day: TrainingDay, exerciseID: String, close: @escaping () -> Void) {
        let rowIDs = model.workspace.days[day.rawValue]?.rows[exerciseID]?.map(\.id) ?? []
        self.init(model: model, context: TrainingMetadataContext(day: day, exerciseID: exerciseID, rowIDs: rowIDs), close: close)
    }

    init(model: TrainingNotebookModel, context: TrainingMetadataContext, close: @escaping () -> Void) {
        self.model = model; self.context = context; self.close = close
        let plan = model.plan(for: context.exerciseID, on: context.day)
        _workingSets = State(initialValue: plan?.workingSets ?? 3)
        _minimumReps = State(initialValue: plan?.minimumReps ?? 8)
        _maximumReps = State(initialValue: plan?.maximumReps ?? 12)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Button("Cancel", action: cancel).frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("cancel-exercise-plan")
                    Spacer(minLength: 12)
                    Button("Save") { save(ExercisePlan(workingSets: workingSets, minimumReps: minimumReps, maximumReps: maximumReps)) }
                        .font(.body.weight(.medium)).frame(minWidth: 44, minHeight: 44)
                        .disabled(minimumReps > maximumReps || pending)
                        .accessibilityIdentifier("save-exercise-plan")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan \(model.exercise(context.exerciseID).name)")
                        .font(NotebookTypography.heading(32)).accessibilityAddTraits(.isHeader)
                    Text("For this workout · \(ProgressFormatting.date(context.day, format: "MMM d, yyyy", calendar: model.calendar))")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    Text("Working sets count toward this target. Warm-ups and Drop sets do not. Targets do not fill in weight or reps.")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }.fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 12) {
                    planRule
                    Stepper(value: $workingSets, in: 1...30) {
                        Text("\(workingSets) working \(workingSets == 1 ? "set" : "sets")")
                            .font(.body.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
                    }.frame(minHeight: 44).accessibilityIdentifier("plan-working-sets")
                    planRule
                    Stepper(value: $minimumReps, in: 1...999) {
                        Text("Minimum reps: \(minimumReps)")
                            .font(.body.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
                    }.frame(minHeight: 44).accessibilityIdentifier("plan-minimum-reps")
                    planRule
                    Stepper(value: $maximumReps, in: 1...999) {
                        Text("Maximum reps: \(maximumReps)")
                            .font(.body.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
                    }.frame(minHeight: 44).accessibilityIdentifier("plan-maximum-reps")
                    planRule
                    if minimumReps > maximumReps {
                        Text("Minimum reps must be at or below maximum reps.")
                            .font(.callout).foregroundStyle(NotebookStyle.clay)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let error = model.errorMessage {
                    if pending && context.matches(model) {
                        TrainingSaveError(model: model, message: error, retrySucceeded: completePending)
                    } else {
                        Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("save-error-message")
                    }
                }
                if model.plan(for: context.exerciseID, on: context.day) != nil {
                    Button("Remove plan for this workout") { save(nil) }
                        .frame(minHeight: 44).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("remove-exercise-plan")
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay)
        .buttonStyle(.plain).accessibilityIdentifier("exercise-plan-editor")
        .onAppear(perform: beginEditing)
        .onChange(of: workingSets) { _, _ in cancelPending() }
        .onChange(of: minimumReps) { _, _ in cancelPending() }
        .onChange(of: maximumReps) { _, _ in cancelPending() }
        .onChange(of: model.workspace) { _, _ in reconcile() }
        .onChange(of: model.canRetrySave) { _, _ in completePending() }
        .onChange(of: model.errorMessage) { _, _ in completePending() }
        .onDisappear { cancelPending() }
    }

    private var planRule: some View { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true) }
    private func beginEditing() {
        guard !beganEditing else { return }
        guard context.matches(model) else { close(); return }
        beganEditing = true
        _ = model.beginMetadataEditing()
    }
    private func save(_ plan: ExercisePlan?) {
        guard context.matches(model) else { cancel(); return }
        cancelPending(); pendingPlan = plan; pending = true
        if model.setPlan(plan, for: context.exerciseID) { completePending() }
        else if !model.canRetrySave { pending = false }
    }
    private func completePending() {
        guard pending, context.matches(model), !model.canRetrySave, model.errorMessage == nil,
              model.plan(for: context.exerciseID, on: context.day) == pendingPlan else { return }
        pending = false; close()
        TrainingAccessibility.announce(pendingPlan == nil ? "Plan removed for this workout." : "Plan saved for this workout.")
    }
    private func reconcile() {
        if context.matches(model) { completePending() } else { cancel() }
    }
    private func cancelPending() {
        guard pending else { return }
        pending = false; _ = model.cancelPendingAction()
    }
    private func cancel() { cancelPending(); close() }
}
