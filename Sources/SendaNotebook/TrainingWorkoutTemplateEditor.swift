import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingWorkoutTemplateEditor: View {
    @StoredExerciseGymFilter private var gymFilter
    @Environment(\.dynamicTypeSize) private var pickerTextSize
    @Bindable var model: TrainingNotebookModel
    let close: () -> Void
    let saved: (WorkoutTemplate) -> Void
    private let original: Draft
    private let isEditing: Bool
    @State private var templateID: String
    @State private var draft: Draft
    @FocusState private var searchingExercises: Bool
    @State private var choosingExercises = false
    @State private var search = ""
    @State private var editingPlan: Exercise?
    @State private var pending: WorkoutTemplate?
    @State private var validationError: String?

    private struct Draft: Equatable {
        var name: String
        var exerciseIDs: [String]
        var plans: [String: ExercisePlan]
        var supersets: [SupersetPlan]
        var groups: [[String]] { SupersetOrder.groups(exerciseIDs, plans: supersets) }

        mutating func moveGroup(at index: Int, by offset: Int) {
            var reordered = groups
            guard reordered.indices.contains(index + offset) else { return }
            reordered.swapAt(index, index + offset)
            exerciseIDs = reordered.flatMap { $0 }
        }
    }

    init(model: TrainingNotebookModel, template: WorkoutTemplate?, isEditing: Bool, copiesCurrentDay: Bool,
         close: @escaping () -> Void, saved: @escaping (WorkoutTemplate) -> Void) {
        self.model = model
        self.close = close
        self.saved = saved
        self.isEditing = isEditing
        let sourceIDs = template?.exerciseIDs ?? (copiesCurrentDay ? model.tabs.map(\.id) : [])
        // Keep existing template references available to remove in the editor.
        let ids = isEditing ? sourceIDs : sourceIDs.filter { !model.exercise($0).isArchived }
        let planSource = template?.exercisePlans ?? (copiesCurrentDay ? model.workout?.exercisePlans : nil) ?? [:]
        let pairs = template?.supersets ?? (copiesCurrentDay ? model.supersets.map(\.plan) : [])
        let initial = Draft(name: template?.name ?? "", exerciseIDs: ids, plans: planSource.filter { ids.contains($0.key) },
                            supersets: pairs.filter { ids.contains($0.first) && ids.contains($0.second) })
        original = initial
        _draft = State(initialValue: initial)
        _templateID = State(initialValue: template?.id ?? UUID().uuidString.lowercased())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if choosingExercises { exercisePicker }
                else { editor }
            }
            .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .id(choosingExercises)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(choosingExercises ? "workout-template-exercise-picker" : "workout-template-editor")
        .safeAreaInset(edge: .top, spacing: 0) {
            navigation.padding(.horizontal, 24).padding(.vertical, 6)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background(NotebookStyle.ivory)
                .overlay(alignment: .bottom) { WorkoutLibraryRule() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pending != nil, let message = model.errorMessage {
                TrainingSaveError(model: model, message: message, retrySucceeded: completePendingSave)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory)
            }
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .scrollIndicators(.never)
        .interactiveDismissDisabled(draft != original || pending != nil || choosingExercises)
        .sheet(item: $editingPlan) { exercise in
            WorkoutTemplatePlanEditor(exercise: exercise, plan: draft.plans[exercise.id], close: { editingPlan = nil }) { plan in
                draft.plans[exercise.id] = plan
                editingPlan = nil
            }
        }
        .onChange(of: draft) { _, _ in
            validationError = nil
            cancelPendingSave()
        }
        .onChange(of: model.canRetrySave) { _, _ in completePendingSave() }
        .onChange(of: model.errorMessage) { _, _ in completePendingSave() }
        .onDisappear { cancelPendingSave() }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 460, minHeight: 568, idealHeight: 740)
        #endif
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            if choosingExercises {
                Spacer(minLength: 0)
                Button { choosingExercises = false } label: {
                    Text("Done").fontWeight(.semibold).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityIdentifier("finish-workout-template-exercises")
            } else {
                Button {
                    cancelPendingSave()
                    close()
                } label: {
                    Text("Cancel").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("cancel-workout-template")
                Spacer(minLength: 0)
                Button(action: save) {
                    Text("Save").fontWeight(.semibold).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .disabled(pending != nil || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.exerciseIDs.isEmpty)
                .accessibilityIdentifier("save-workout-template")
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading(isEditing ? "Edit workout" : "New workout")
            VStack(alignment: .leading, spacing: 0) {
                TextField("Workout name", text: $draft.name)
                    .textFieldStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("workout-template-name")
                WorkoutLibraryRule()
            }
            if let validationError {
                Text(validationError).font(.callout).foregroundStyle(NotebookStyle.clay)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("workout-template-validation")
            }
            if !draft.exerciseIDs.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Exercises").font(NotebookTypography.heading(22, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 10)
                    WorkoutLibraryRule()
                    ForEach(draft.exerciseIDs, id: \.self) { id in
                        exerciseRow(model.exercise(id))
                        WorkoutLibraryRule()
                    }
                }
            }
            Button {
                search = ""
                choosingExercises = true
            } label: {
                Label("Add exercises", systemImage: "plus")
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(NotebookStyle.clay)
            .accessibilityIdentifier("workout-template-add-exercise")
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let groups = draft.groups
        let groupIndex = groups.firstIndex { $0.contains(exercise.id) } ?? 0
        let paired = groups.filter { $0.count == 2 }
        let pairIndex = paired.firstIndex { $0.contains(exercise.id) }
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let pairIndex {
                        let code = SupersetMembership.letter(at: pairIndex) + (paired[pairIndex].first == exercise.id ? "1" : "2")
                        Text(code).font(.caption.bold()).foregroundStyle(NotebookStyle.clay)
                    }
                    Text(exercise.name).font(.body.weight(.semibold))
                }
                if exercise.isArchived {
                    Text("Removed from library").font(.caption).foregroundStyle(NotebookStyle.quiet)
                } else if model.snapshot.customExercises?.contains(where: { $0.id == exercise.id }) == true {
                    Text("Custom exercise").font(.caption).foregroundStyle(NotebookStyle.quiet)
                }
                if let plan = draft.plans[exercise.id] { WorkoutLibraryPlanLabel(plan: plan) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Menu {
                Button { editingPlan = exercise } label: {
                    Label(draft.plans[exercise.id] == nil ? "Add set target" : "Edit set target", systemImage: "target")
                }
                .accessibilityIdentifier("workout-template-plan-\(exercise.id)")
                if groupIndex > 0 {
                    Button { draft.moveGroup(at: groupIndex, by: -1) } label: {
                        Label(pairIndex == nil ? "Move up" : "Move superset up", systemImage: "arrow.up")
                    }
                    .accessibilityIdentifier("workout-template-move-up-\(exercise.id)")
                }
                if groupIndex < groups.count - 1 {
                    Button { draft.moveGroup(at: groupIndex, by: 1) } label: {
                        Label(pairIndex == nil ? "Move down" : "Move superset down", systemImage: "arrow.down")
                    }
                    .accessibilityIdentifier("workout-template-move-down-\(exercise.id)")
                }
                Button(role: .destructive) {
                    draft.exerciseIDs.removeAll { $0 == exercise.id }
                    draft.plans[exercise.id] = nil
                    draft.supersets.removeAll { $0.exerciseIDs.contains(exercise.id) }
                } label: { Label("Remove exercise", systemImage: "minus.circle") }
                .accessibilityIdentifier("workout-template-remove-\(exercise.id)")
            } label: {
                Image(systemName: "ellipsis").font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .foregroundStyle(NotebookStyle.quiet)
            .accessibilityLabel("\(exercise.displayName) options")
            .accessibilityIdentifier("workout-template-options-\(exercise.id)")
        }
        .padding(.vertical, 6)
    }

    private var exercisePicker: some View {
        let library = model.activeExercises
        let exercises = ExerciseSelectionFilter.results(in: library, query: search, group: nil, equipment: nil, gymFilter: gymFilter)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let customIDs = Set(model.snapshot.customExercises?.map(\.id) ?? [])
        let recovery = ExerciseSearchRecovery.find(query: search, in: library, gymFilter: gymFilter,
            includePartialMatch: exercises.isEmpty, excludingAlternatives: Set(exercises.map(\.id)))
        return VStack(alignment: .leading, spacing: 12) {
            let controls = pickerTextSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(spacing: 12))
            controls {
                heading("Add exercises").frame(maxWidth: .infinity, alignment: .leading)
                LibraryGymFilterButton(filter: $gymFilter, identifier: "workout-template-gym-filters", resultCount: {
                    ExerciseSelectionFilter.results(in: library, query: search, group: nil, equipment: nil, gymFilter: $0).count
                })
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet)
                    .accessibilityHidden(true)
                TextField("Search exercises", text: $search)
                    .focused($searchingExercises).textFieldStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("workout-template-search")
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Label("Clear exercise search", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(NotebookStyle.quiet)
                }
            }
            GymSetupSwitcher(onSwitch: { searchingExercises = false })
            if let recovery {
                ExerciseSearchRecoveryView(recovery: recovery) { exercise in
                    pickerRow(exercise, isCustom: customIDs.contains(exercise.id))
                }
            }
            if exercises.isEmpty {
                if recovery == nil {
                    Text("No matching exercises.").font(.body).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if gymFilter.activeCount > 0 {
                    Button("Clear filters") { gymFilter = .init() }
                        .frame(minHeight: 44).foregroundStyle(NotebookStyle.clay)
                }
            } else {
                LazyVStack(spacing: 0) {
                    WorkoutLibraryRule()
                    ForEach(exercises) { exercise in
                        pickerRow(exercise, isCustom: customIDs.contains(exercise.id))
                        WorkoutLibraryRule()
                    }
                }
            }
        }
    }

    private func pickerRow(_ exercise: Exercise, isCustom: Bool) -> some View {
        let selected = draft.exerciseIDs.contains(exercise.id)
        return Button {
            guard !selected else { return }
            draft.exerciseIDs.append(exercise.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name).font(.body.weight(selected ? .semibold : .regular))
                    if isCustom {
                        Text("Custom exercise").font(.caption).foregroundStyle(NotebookStyle.quiet)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark" : "plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .disabled(selected)
        .accessibilityIdentifier("workout-template-exercise-\(exercise.id)")
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(NotebookTypography.heading(31))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func save() {
        guard pending == nil else { return }
        let workout = WorkoutTemplate(id: templateID, name: draft.name, exerciseIDs: draft.exerciseIDs, exercisePlans: draft.plans,
                                      supersets: draft.supersets.isEmpty ? nil : draft.supersets)
        pending = workout
        if model.saveWorkout(workout) {
            completePendingSave()
        } else if !model.canRetrySave {
            let message = model.errorMessage ?? "Couldn’t save this workout."
            pending = nil
            validationError = message
            model.dismissError()
            TrainingAccessibility.announce(message)
        }
    }

    private func completePendingSave() {
        guard let pending, !model.canRetrySave, model.errorMessage == nil,
              model.savedWorkouts.contains(pending) else { return }
        self.pending = nil
        saved(pending)
    }

    private func cancelPendingSave() {
        guard pending != nil else { return }
        pending = nil
        if model.canRetrySave { _ = model.cancelPendingAction() }
        else { model.dismissError() }
    }
}

private struct WorkoutTemplatePlanEditor: View {
    let exercise: Exercise
    let hasPlan: Bool
    let close: () -> Void
    let save: (ExercisePlan?) -> Void
    @State private var plan: ExercisePlan

    init(exercise: Exercise, plan: ExercisePlan?, close: @escaping () -> Void, save: @escaping (ExercisePlan?) -> Void) {
        self.exercise = exercise
        hasPlan = plan != nil
        self.close = close
        self.save = save
        _plan = State(initialValue: plan ?? ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Button(action: close) {
                        Text("Cancel").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                    Button { save(plan) } label: {
                        Text("Done").fontWeight(.semibold).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .foregroundStyle(NotebookStyle.clay)
                    .disabled(plan.minimumReps > plan.maximumReps)
                    .accessibilityIdentifier("save-workout-template-plan")
                }
                Text("Set target").font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                Text(exercise.displayName).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    WorkoutLibraryRule()
                    planStepper("Working sets", value: $plan.workingSets, range: NumericField.sets.range)
                    planStepper("Minimum reps", value: $plan.minimumReps, range: NumericField.reps.range)
                    planStepper("Maximum reps", value: $plan.maximumReps, range: NumericField.reps.range)
                    if plan.minimumReps > plan.maximumReps {
                        Text("Minimum reps must be at or below maximum reps.")
                            .font(.callout).foregroundStyle(NotebookStyle.clay)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if hasPlan {
                    Button { save(nil) } label: {
                        Text("Remove set target")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityIdentifier("remove-workout-template-plan")
                }
            }
            .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
    }

    private func planStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 0) {
            Stepper(value: value, in: range) {
                Text("\(title) · \(value.wrappedValue)").font(.body.monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44)
            WorkoutLibraryRule()
        }
    }
}
