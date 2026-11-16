import SwiftUI
import SendaDomain
import SendaLogger

extension WeeklyMuscleTarget {
    var setRangeText: String {
        let minimum = minimumSets.formatted()
        return minimumSets == maximumSets ? minimum : "\(minimum)–\(maximumSets.formatted())"
    }
}

struct TrainingWeeklyMuscleTargetEditor: View {
    private let profile: ProfileModel
    private let target: WeeklyMuscleTarget?
    private let availableMuscles: [MuscleRegion]
    private let close: () -> Void
    @State private var muscle: MuscleRegion?
    @State private var minimum: String
    @State private var maximum: String
    @State private var errorMessage: String?
    @State private var confirmsRemoval = false
    @Environment(\.dynamicTypeSize) private var textSize

    init(profile: ProfileModel, target: WeeklyMuscleTarget?, availableMuscles: [MuscleRegion],
         close: @escaping () -> Void) {
        self.profile = profile
        self.target = target
        self.availableMuscles = availableMuscles
        self.close = close
        _muscle = State(initialValue: target?.muscle)
        _minimum = State(initialValue: target.map { String($0.minimumSets) } ?? "")
        _maximum = State(initialValue: target.map { String($0.maximumSets) } ?? "")
    }

    private var hasDraft: Bool {
        muscle != target?.muscle
            || minimum != (target.map { String($0.minimumSets) } ?? "")
            || maximum != (target.map { String($0.maximumSets) } ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            actions
                .padding(.horizontal, 24).padding(.vertical, 8)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            rule
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(target == nil ? "New weekly target" : "Edit weekly target")
                        .font(NotebookTypography.heading(31))
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    muscleField
                    setFields
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(NotebookStyle.clay)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("weekly-muscle-target-error")
                    }
                    if target != nil {
                        Button(role: .destructive) { confirmsRemoval = true } label: {
                            Text("Remove target")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .foregroundStyle(NotebookStyle.clay)
                        .accessibilityIdentifier("remove-weekly-muscle-target")
                    }
                }
                .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .clipped()
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("weekly-muscle-target-editor")
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .textFieldStyle(.plain)
        .scrollIndicators(.never)
        .interactiveDismissDisabled(hasDraft)
        .confirmationDialog("Remove this weekly target?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button("Remove target", role: .destructive, action: remove)
                .accessibilityIdentifier("confirm-remove-weekly-muscle-target")
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button(action: close) {
                Text("Cancel")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("cancel-weekly-muscle-target")
            Spacer(minLength: 0)
            Button(action: save) {
                Text("Save")
                    .fontWeight(.semibold)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(NotebookStyle.clay)
            .accessibilityIdentifier("save-weekly-muscle-target")
        }
    }

    private var muscleField: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Muscle").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            if let target {
                Text(target.muscle.name)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("weekly-muscle-target-muscle")
            } else {
                Menu {
                    ForEach(availableMuscles, id: \.self) { option in
                        Button {
                            muscle = option
                            errorMessage = nil
                        } label: {
                            if muscle == option { Label(option.name, systemImage: "checkmark") }
                            else { Text(option.name) }
                        }
                        .accessibilityAddTraits(muscle == option ? .isSelected : [])
                        .accessibilityIdentifier("weekly-muscle-target-option-\(option.rawValue)")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(muscle?.name ?? "Choose muscle")
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
                    }
                    .foregroundStyle(NotebookStyle.clay)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Muscle")
                .accessibilityValue(muscle?.name ?? "Choose muscle")
                .accessibilityIdentifier("weekly-muscle-target-muscle")
            }
            rule
        }
    }

    private var setFields: some View {
        let layout = textSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        return layout {
            setField("Minimum sets", text: $minimum, identifier: "weekly-muscle-target-minimum")
            setField("Maximum sets", text: $maximum, identifier: "weekly-muscle-target-maximum")
        }
    }

    private func setField(_ title: String, text: Binding<String>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
            TextField(title, text: text, prompt: Text("—"))
                .numericKeyboard(decimal: false)
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
        guard let muscle else { return report("Choose a muscle.") }
        guard let minimumSets = Int(minimum.trimmingCharacters(in: .whitespacesAndNewlines)),
              let maximumSets = Int(maximum.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return report("Enter whole numbers for minimum and maximum sets.")
        }
        if target == nil && profile.details.weeklyMuscleTargets.contains(where: { $0.muscle == muscle }) {
            return report("This muscle already has a weekly target.")
        }
        let updated = WeeklyMuscleTarget(muscle: muscle, minimumSets: minimumSets, maximumSets: maximumSets)
        if profile.saveWeeklyMuscleTarget(updated) { close() }
        else { report(profile.errorMessage ?? "Couldn’t save the target. Try again.") }
    }

    private func remove() {
        guard let target else { return }
        if profile.removeWeeklyMuscleTarget(target.muscle) { close() }
        else { report(profile.errorMessage ?? "Couldn’t remove the target. Try again.") }
    }

    private func report(_ message: String) {
        errorMessage = message
        TrainingAccessibility.announce(message)
    }
}
