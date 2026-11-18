import SwiftUI
import SendaDomain
import SendaLogger

private enum ProfileSheet: Identifiable {
    case settings
    case goal(StrengthGoal?)
    case weeklyTarget(WeeklyMuscleTarget?)

    var id: String {
        switch self {
        case .settings: "settings"
        case .goal(let goal): goal?.id.uuidString ?? "new-goal"
        case .weeklyTarget(let target): target.map { "weekly-target-\($0.muscle.rawValue)" } ?? "new-weekly-target"
        }
    }
}

struct TrainingProfileView: View {
    @Bindable var model: TrainingNotebookModel
    @State private var sheet: ProfileSheet?
    @Environment(\.dynamicTypeSize) private var textSize

    private var unit: WeightUnit { model.workspace.preferredUnit }

    var body: some View {
        let goals = model.snapshot.strengthGoalProgress(for: model.profile.details.goals,
            through: model.today, calendar: model.calendar)
        let active = goals.filter { !$0.isCompleted }
        let completed = goals.filter(\.isCompleted)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                identity
                VStack(alignment: .leading, spacing: 0) {
                    goalHeading
                    profileRule
                    if active.isEmpty {
                        Text("Choose a lift, weight, and reps to work toward.")
                            .font(.subheadline)
                            .foregroundStyle(NotebookStyle.quiet)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 14)
                        profileRule
                    } else {
                        goalRows(active)
                    }
                }
                if !completed.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Completed goals")
                            .font(NotebookTypography.heading(22, relativeTo: .title2))
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("completed-strength-goals")
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 10)
                        profileRule
                        goalRows(completed)
                    }
                }
                weeklySetTargets
                if let error = model.profile.openingError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Try profile again") { model.profile.reload() }
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                if let error = model.errorMessage {
                    if model.canRetryProgressAction { TrainingSaveError(model: model, message: error) }
                    else { ProfileActionError(model: model, message: error) }
                }
            }
            .padding(24)
            .padding(.bottom, 8)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .clipped()
        .accessibilityIdentifier("profile-scroll")
        .sheet(item: $sheet) { destination in
            switch destination {
            case .settings:
                TrainingProfileSettingsIndex(model: model, close: { sheet = nil })
            case .goal(let goal):
                TrainingStrengthGoalEditor(model: model, goal: goal, close: { sheet = nil })
            case .weeklyTarget(let target):
                TrainingWeeklyMuscleTargetEditor(profile: model.profile, target: target,
                    availableMuscles: untargetedMuscles, close: { sheet = nil })
            }
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Text("Profile")
                    .font(NotebookTypography.heading(31))
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Button { sheet = .settings } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("profile-settings")
            }
            if !model.profile.details.name.isEmpty {
                Text(model.profile.details.name)
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("profile-display-name")
            }
        }
    }

    private var goalHeading: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            Text("Goals")
                .font(NotebookTypography.heading(24, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { sheet = .goal(nil) } label: {
                Text("Add goal")
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(NotebookStyle.clay)
            .disabled(model.profile.openingError != nil)
            .accessibilityIdentifier("add-strength-goal")
        }
        .padding(.bottom, 4)
    }

    private func goalRows(_ goals: [StrengthGoalProgress]) -> some View {
        ForEach(goals) { progress in
            let goal = progress.goal
            let exercise = model.exercise(goal.exerciseID)
            Button { sheet = .goal(goal) } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(exercise.displayName).font(.body.weight(.semibold))
                        Text("Goal · \(ProgressFormatting.set(goal.target, exercise: exercise, unit: unit))")
                            .font(.body.monospacedDigit())
                        goalDetail(progress, exercise: exercise)
                            .font(.subheadline)
                            .foregroundStyle(NotebookStyle.quiet)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if progress.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NotebookStyle.olive)
                            .accessibilityHidden(true)
                    }
                    profileChevron
                }
                .frame(minHeight: 44)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .disabled(model.profile.openingError != nil)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Edit goal")
            .accessibilityIdentifier("strength-goal-\(goal.id.uuidString)")
            profileRule
        }
    }

    private var untargetedMuscles: [MuscleRegion] {
        let mapped = Set(model.exercises.flatMap { $0.muscleMap?.primary ?? [] })
        let targeted = Set(model.profile.details.weeklyMuscleTargets.map(\.muscle))
        return mapped.subtracting(targeted).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var weeklySetTargets: some View {
        let targets = model.profile.details.weeklyMuscleTargets.sorted {
            $0.muscle.name.localizedStandardCompare($1.muscle.name) == .orderedAscending
        }
        let layout = textSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return VStack(alignment: .leading, spacing: 0) {
            layout {
                Text("Weekly set targets")
                    .font(NotebookTypography.heading(24, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { sheet = .weeklyTarget(nil) } label: {
                    Text("Add target")
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .disabled(model.profile.openingError != nil || untargetedMuscles.isEmpty)
                .accessibilityIdentifier("add-weekly-muscle-target")
            }
            .padding(.bottom, 4)
            profileRule
            if targets.isEmpty {
                Text("Set a weekly range for a muscle you want to track.")
                    .font(.subheadline)
                    .foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 14)
                profileRule
            }
            ForEach(targets) { target in
                Button { sheet = .weeklyTarget(target) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(target.muscle.name).font(.body.weight(.semibold))
                            Text("\(target.setRangeText) \(target.maximumSets == 1 ? "set" : "sets") per week")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(NotebookStyle.quiet)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        profileChevron
                    }
                    .frame(minHeight: 44)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .disabled(model.profile.openingError != nil)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Edit target")
                .accessibilityIdentifier("weekly-muscle-target-\(target.muscle.rawValue)")
                profileRule
            }
        }
    }

    @ViewBuilder private func goalDetail(_ progress: StrengthGoalProgress, exercise: Exercise) -> some View {
        if let best = progress.best {
            Text("\(ProgressFormatting.set(best.values, exercise: exercise, unit: unit)) recorded")
                .monospacedDigit()
            if let completedDay = progress.completedDay {
                Text("Reached \(ProgressFormatting.date(completedDay, format: "MMM d, yyyy", calendar: model.calendar))")
            } else {
                let remaining = unit.text(for: progress.goal.target.weight - best.values.weight)
                Text(remaining == "0" ? "Less than 0.01 \(unit.symbol) to go" : "\(remaining) \(unit.symbol) to go")
                    .monospacedDigit()
            }
        } else {
            let reps = progress.goal.target.reps
            Text(reps == 1 ? "No recorded sets yet." : "No set with \(reps) or more reps yet.")
        }
    }
}

private struct TrainingProfileSettingsIndex: View {
    private enum Destination { case details, units, backup }

    @Bindable var model: TrainingNotebookModel
    let close: () -> Void
    @State private var destination: Destination?
    @State private var sampleWorkoutsStatus: String?
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Group {
            switch destination {
            case .details:
                ProfileDetailsView(profile: model.profile, close: { destination = nil })
            case .units:
                TrainingSettingsView(model: model, close: { destination = nil })
            case .backup:
                TrainingSettingsView(model: model, destination: .backup, close: { destination = nil })
            case nil:
                settings
            }
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .scrollIndicators(.never)
    }

    private var settings: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return VStack(spacing: 0) {
            layout {
                Text("Settings")
                    .font(NotebookTypography.heading(31))
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: close) {
                    Text("Done")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("close-profile-settings")
                .frame(maxWidth: textSize.isAccessibilitySize ? .infinity : nil, alignment: .trailing)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            profileRule
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button { destination = .details } label: {
                        destinationRow(title: "Edit profile",
                            detail: model.profile.details.name.isEmpty ? "Display name" : model.profile.details.name)
                    }
                    .disabled(model.profile.openingError != nil)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("profile-details")
                    profileRule
                    Button { destination = .units } label: {
                        destinationRow(title: "Weight units",
                            detail: model.workspace.preferredUnit == .pounds ? "Pounds · lb" : "Kilograms · kg")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("profile-weight-units")
                    profileRule
                    Button { destination = .backup } label: {
                        destinationRow(title: "Workout recovery", detail: "Save or restore a backup file")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("profile-backup")
                    profileRule
                    sampleWorkouts
                    profileRule
                    Text("Your notebook is saved on this device.")
                        .font(.subheadline)
                        .foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                        .accessibilityIdentifier("profile-storage-explanation")
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .clipped()
            .accessibilityIdentifier("profile-settings-scroll")
        }
    }

    private var sampleWorkouts: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: addSampleWorkouts) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Add sample workouts").font(.body.weight(.medium))
                        Text("Up to three workouts a week on empty days in the 30 days before today.")
                            .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "plus").foregroundStyle(NotebookStyle.clay).accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .disabled(model.canRetrySave)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("add-sample-workouts")
            if let sampleWorkoutsStatus {
                Text(sampleWorkoutsStatus).font(.subheadline).foregroundStyle(NotebookStyle.olive)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("sample-workouts-status")
            }
            if let error = model.errorMessage {
                TrainingSaveError(model: model, message: error).padding(.bottom, 12)
            }
        }
    }

    private func addSampleWorkouts() {
        sampleWorkoutsStatus = nil
        guard let count = model.addSampleWorkouts() else { return }
        let message = switch count {
        case 0: "No more sample workouts to add."
        case 1: "Added 1 sample workout."
        default: "Added \(count) sample workouts."
        }
        sampleWorkoutsStatus = message
        TrainingAccessibility.announce(message)
    }

    private func destinationRow(title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            profileChevron
        }
        .frame(minHeight: 44)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private var profileRule: some View {
    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
}

private var profileChevron: some View {
    Image(systemName: "chevron.right")
        .font(.system(size: 12))
        .foregroundStyle(NotebookStyle.quiet)
        .accessibilityHidden(true)
}
