import SwiftUI
import SendaDomain

struct ExerciseSearchRecoveryView<Row: View>: View {
    let recovery: ExerciseSearchRecovery
    @ViewBuilder let row: (Exercise) -> Row

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recovery.exercise.displayName)
                .font(.headline).accessibilityAddTraits(.isHeader)
            Text(explanation).font(.callout).foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("exercise-unavailable-reason")
            if !recovery.alternatives.isEmpty {
                Text("Available alternatives").font(.subheadline.weight(.semibold))
                    .padding(.top, 8).accessibilityAddTraits(.isHeader)
                ForEach(recovery.alternatives) { exercise in row(exercise) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var explanation: String {
        switch recovery.reason {
        case .missingEquipment(let groups):
            if groups == [[.flatBench, .adjustableBench, .anchoredBench]] {
                return "Also requires a bench (flat, adjustable, or anchored)."
            }
            let equipment = groups.map { $0.map(\.label).formatted(.list(type: .or)) }
            return (["Equipment needed"] + equipment).joined(separator: "\n")
        case .differentGym(let gym):
            return "This exercise is outside your selected gym type (\(gym.label))."
        case .gymsUnspecified:
            return "Gym types haven’t been listed for this exercise."
        case .equipmentUnspecified:
            return "Equipment requirements haven’t been listed for this exercise."
        case .differentMuscleGroup(let group):
            return "This exercise is listed under \(group.rawValue)."
        case .differentMainEquipment(let equipment):
            return "Its main equipment is listed as \(equipment.rawValue)."
        }
    }
}
