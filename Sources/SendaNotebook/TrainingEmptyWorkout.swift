import SwiftUI

struct TrainingEmptyWorkout: View {
    let addExercise: (() -> Void)?
    let chooseTemplate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            VStack(spacing: 4) {
                if let addExercise {
                    Button(action: addExercise) {
                        actionLabel("Add exercise", symbol: "plus")
                            .foregroundStyle(NotebookStyle.onPrimary)
                            .background(NotebookStyle.primaryFill, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .accessibilityIdentifier("add-exercise")
                }
                Button(action: chooseTemplate) {
                    Text("Choose a template").font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityIdentifier("choose-workout")
            }
        }
        .padding(.top, 6)
    }

    private func actionLabel(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
    }
}
