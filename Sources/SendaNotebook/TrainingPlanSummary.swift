import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingPlanSummary: View {
    @Bindable var model: TrainingNotebookModel
    let edit: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Group {
            if plan == nil {
                editButton
            } else if textSize >= .xxxLarge {
                VStack(alignment: .leading, spacing: 0) { details; editButton }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    details.frame(maxWidth: .infinity, alignment: .leading)
                    editButton
                }
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("exercise-plan-summary")
    }

    private var plan: ExercisePlan? { model.exercise.flatMap { model.plan(for: $0.id) } }
    private var completedWorkingSets: Int {
        model.rows.filter { $0.kind?.countsTowardWorkingPlan == true && model.recordedValues(for: $0) != nil }.count
    }
    @ViewBuilder private var details: some View {
        if let plan {
            Text("\(completedWorkingSets) of \(plan.workingSets) working · \(TrainingPlanText.repRange(plan)) reps")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(completedWorkingSets) of \(plan.workingSets) working sets, \(TrainingPlanText.repRange(plan)) reps")
                .accessibilityIdentifier("working-set-completion")
        }
    }
    private var editButton: some View {
        Button(action: edit) {
            Text(plan == nil ? "Add plan" : "Plan")
                .font((plan == nil ? Font.subheadline : .footnote).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
            .foregroundStyle(plan == nil ? NotebookStyle.clay : NotebookStyle.quiet)
            .accessibilityHint("Change this workout's set target and rep range")
            .accessibilityIdentifier("edit-exercise-plan")
    }
}

enum TrainingPlanText {
    static func repRange(_ plan: ExercisePlan) -> String {
        plan.minimumReps == plan.maximumReps ? "\(plan.minimumReps)" : "\(plan.minimumReps)–\(plan.maximumReps)"
    }
}
