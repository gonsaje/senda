import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingNextWorkoutFeedback: View {
    @Bindable var model: TrainingNotebookModel
    let day: TrainingDay
    let exercise: Exercise

    var body: some View {
        let guidance = model.nextWorkoutGuidance(for: exercise.id, on: day)
        if guidance.status != .noPlan {
            VStack(alignment: .leading, spacing: 6) {
                Text("Next workout").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text(TrainingNextWorkoutText.make(guidance, exercise: exercise, unit: model.unit))
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                if let referenceDay = guidance.referenceDay {
                    Text("Based on \(ProgressFormatting.date(referenceDay, format: "MMM d, yyyy", calendar: model.calendar)) · Saved working sets")
                        .font(.caption).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                .accessibilityElement(children: .combine).accessibilityIdentifier("next-workout-feedback")
        }
    }
}

enum TrainingNextWorkoutText {
    static func make(_ guidance: NextWorkoutGuidance, exercise: Exercise, unit: WeightUnit) -> String {
        let load = guidance.referenceWeight.map { Self.load($0, exercise: exercise, unit: unit) }
        let range = guidance.plan.map { "\(TrainingPlanText.repRange($0)) reps" } ?? "your rep range"
        let repeatTarget = load.map { "Repeat \($0) within \(range)." } ?? "Repeat the recorded load within \(range)."
        switch guidance.reason {
        case .noPlan:
            return "Add a working-set target and rep range for this workout."
        case .noWorkingHistory:
            return "Add working sets to compare with this plan."
        case .unclassifiedSets:
            return "Choose a set type for the unclassified sets before reviewing the next workout."
        case .incompleteWorkingSets:
            if let plan = guidance.plan {
                return "The latest workout has \(guidance.workingSetCount) of \(plan.workingSets) working sets. Complete or review it before the next workout."
            }
            return "Complete or review the latest workout's working sets before the next workout."
        case .planChanged:
            return "The latest workout used a different plan. Review its working sets and rep range before the next workout."
        case .extraWorkingSets:
            return "The latest workout has more working sets than this plan. Review the set target before the next workout."
        case .dropSets:
            return "The latest workout includes drop sets. Review those sets and choose the next load manually."
        case .mixedLoads:
            return "Working-set loads varied in the latest workout. Review those sets before choosing the next load."
        case .missingEffort:
            return "\(repeatTarget) Reps left are missing for one or more working sets."
        case .lowReserve:
            return "\(repeatTarget) At least one working set had fewer than 2 reps left."
        case .belowRange:
            return "At least one working set fell below the rep range. Review the load, rest, or rep target before the next workout."
        case .moreReps:
            let target = guidance.plan.map { "\($0.maximumReps) reps" } ?? "the top of the rep range"
            return load.map { "Build toward \(target) in each working set at \($0)." }
                ?? "Build toward \(target) in each working set at the recorded load."
        case .oneQualifyingSession:
            return "\(repeatTarget) One comparable workout met the top rep target with at least 2 reps left on every working set."
        case .twoQualifyingSessions:
            return "Review a small load increase. Two comparable workouts\(load.map { " at \($0)" } ?? "") met the top rep target with at least 2 reps left on every working set."
        }
    }

    private static func load(_ weight: Int, exercise: Exercise, unit: WeightUnit) -> String {
        if !exercise.requiresWeight { return weight == 0 ? "BW" : "BW + \(unit.text(for: weight)) \(unit.symbol)" }
        return "\(unit.text(for: weight)) \(unit.symbol)"
    }
}
