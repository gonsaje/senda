import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingWorkoutLibrary: View {
    @Bindable var model: TrainingNotebookModel
    let close: () -> Void
    @State private var search = ""
    @State private var selection: Selection?
    @State private var editor: EditorRequest?
    @State private var confirmsDeletion = false
    @State private var pending: PendingAction?
    @Environment(\.dynamicTypeSize) private var textSize

    private struct Selection {
        let workout: WorkoutTemplate
        let isPersonal: Bool
    }

    private enum EditorRequest: Identifiable {
        case new, currentDay, edit(WorkoutTemplate), copy(WorkoutTemplate)

        var id: String {
            switch self {
            case .new: "new"
            case .currentDay: "current-day"
            case .edit(let workout): "edit-\(workout.id)"
            case .copy(let workout): "copy-\(workout.id)"
            }
        }

        var original: WorkoutTemplate? {
            switch self {
            case .edit(let workout): workout
            case .copy(let workout): WorkoutTemplate(name: workout.name, exerciseIDs: workout.exerciseIDs,
                exercisePlans: workout.exercisePlans)
            case .new, .currentDay: nil
            }
        }

        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }

        var copiesCurrentDay: Bool {
            if case .currentDay = self { return true }
            return false
        }
    }

    private enum PendingAction {
        case apply(day: TrainingDay, exerciseIDs: [String])
        case delete(id: String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let selection { detail(selection) }
                else { catalogue }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .id(selection?.workout.id)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(selection == nil ? "workout-library" : "workout-template-detail")
        .safeAreaInset(edge: .top, spacing: 0) {
            navigation
                .padding(.horizontal, 24).padding(.vertical, 6)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background(NotebookStyle.ivory)
                .overlay(alignment: .bottom) { WorkoutLibraryRule() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .scrollIndicators(.never)
        .interactiveDismissDisabled(pending != nil)
        .confirmationDialog("Delete this workout template?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete template", role: .destructive, action: deleteSelectedWorkout)
                .accessibilityIdentifier("confirm-delete-workout-template")
        } message: {
            Text("Workouts you’ve logged will stay in your journal.")
        }
        .sheet(item: $editor) { request in
            TrainingWorkoutTemplateEditor(model: model, template: request.original,
                isEditing: request.isEditing, copiesCurrentDay: request.copiesCurrentDay, close: { editor = nil }, saved: { workout in
                    if request.isEditing { selection = Selection(workout: workout, isPersonal: true) }
                    else { search = ""; selection = nil }
                    editor = nil
                })
        }
        .onChange(of: model.canRetrySave) { _, _ in completePendingAction() }
        .onChange(of: model.errorMessage) { _, _ in completePendingAction() }
        .onChange(of: model.selectedDay) { _, _ in cancelPendingAction() }
        .onDisappear { cancelPendingAction() }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 460, minHeight: 568, idealHeight: 740)
        #endif
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            if selection != nil {
                Button {
                    cancelPendingAction()
                    selection = nil
                } label: {
                    Label("Workouts", systemImage: "chevron.left")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("back-to-workout-library")
            }
            Spacer(minLength: 0)
            Button {
                cancelPendingAction()
                close()
            } label: {
                Text("Done").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityIdentifier("close-workout-library")
        }
    }

    private var catalogue: some View {
        let saved = matching(model.savedWorkouts)
        let starters = matching(model.starterWorkouts)
        return VStack(alignment: .leading, spacing: 22) {
            heading("Workout library")
            searchField
            VStack(alignment: .leading, spacing: 4) {
                let layout = textSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                    : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    Text("My workouts").font(NotebookTypography.heading(22, relativeTo: .title2))
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { editor = .new } label: {
                        Label("Create workout", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityIdentifier("create-workout-template")
                }
                if !saved.isEmpty { templateRows(saved, isPersonal: true) }
                if model.savedWorkouts.isEmpty {
                    Text("Create a workout to use again on another day.")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !model.tabs.isEmpty {
                    Button { editor = .currentDay } label: {
                        Text("Save this workout as a template")
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityIdentifier("save-day-as-workout-template")
                }
            }
            if !starters.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Starter workouts").font(NotebookTypography.heading(22, relativeTo: .title2))
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    templateRows(starters, isPersonal: false)
                }
            }
            if saved.isEmpty && starters.isEmpty {
                Text("No matching workouts.").font(.body)
                    .foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var searchField: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet)
                    .accessibilityHidden(true)
                TextField("Search workouts", text: $search)
                    .textFieldStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("workout-library-search")
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Label("Clear workout search", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }.foregroundStyle(NotebookStyle.quiet)
                }
            }
            WorkoutLibraryRule()
        }
    }

    private func matching(_ workouts: [WorkoutTemplate]) -> [WorkoutTemplate] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return workouts }
        return workouts.filter { workout in
            workout.name.localizedStandardContains(query) || workout.exerciseIDs.contains {
                model.exercise($0).displayName.localizedStandardContains(query)
            }
        }
    }

    private func templateRows(_ workouts: [WorkoutTemplate], isPersonal: Bool) -> some View {
        VStack(spacing: 0) {
            WorkoutLibraryRule()
            ForEach(workouts) { workout in
                Button { selection = Selection(workout: workout, isPersonal: isPersonal) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name).font(.body.weight(.semibold))
                            Text(exerciseCount(workout.exerciseIDs.count))
                                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").font(.caption.weight(.medium))
                            .foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
                    }
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("workout-template-\(workout.id)")
                WorkoutLibraryRule()
            }
        }
    }

    private func detail(_ selection: Selection) -> some View {
        let workout = selection.workout
        let current = Set(model.workout?.exerciseIDs ?? [])
        let customIDs = Set(model.snapshot.customExercises?.map(\.id) ?? [])
        return VStack(alignment: .leading, spacing: 18) {
            heading(workout.name)
            if workout.exerciseIDs.allSatisfy(current.contains) {
                Text("These exercises are already in this workout.")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 0) {
                WorkoutLibraryRule()
                ForEach(workout.exerciseIDs, id: \.self) { id in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.exercise(id).displayName).font(.body.weight(.semibold))
                        if customIDs.contains(id) {
                            Text("Custom exercise").font(.caption).foregroundStyle(NotebookStyle.quiet)
                        }
                        if let plan = workout.exercisePlans[id] { WorkoutLibraryPlanLabel(plan: plan) }
                        if current.contains(id) {
                            Text("Already added").font(.caption).foregroundStyle(NotebookStyle.quiet)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    WorkoutLibraryRule()
                }
            }
            if selection.isPersonal {
                VStack(alignment: .leading, spacing: 0) {
                    Button { editor = .edit(workout) } label: {
                        Text("Edit template").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("edit-workout-template")
                    Button(role: .destructive) { confirmsDeletion = true } label: {
                        Text("Delete template").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("delete-workout-template")
                }
                .foregroundStyle(NotebookStyle.clay)
                .disabled(pending != nil)
            } else {
                Button { editor = .copy(workout) } label: {
                    Text("Save a copy").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .disabled(pending != nil)
                .accessibilityIdentifier("copy-workout-template")
            }
        }
    }

    @ViewBuilder private var footer: some View {
        let current = Set(model.workout?.exerciseIDs ?? [])
        let missing = selection?.workout.exerciseIDs.filter { !current.contains($0) } ?? []
        if (model.errorMessage != nil && pending != nil) || (model.selectedDay != nil && !missing.isEmpty) {
            VStack(spacing: 0) {
                WorkoutLibraryRule()
                Group {
                    if let error = model.errorMessage, pending != nil {
                        TrainingSaveError(model: model, message: error, retrySucceeded: completePendingAction)
                    } else if let selection {
                        Button { apply(selection.workout, missing: missing) } label: {
                            Text(current.isEmpty ? "Use workout" : "Add \(exerciseCount(missing.count))")
                                .font(.body.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .padding(.horizontal, 10)
                                .foregroundStyle(NotebookStyle.ivory)
                                .background(NotebookStyle.clay, in: RoundedRectangle(cornerRadius: 7))
                                .contentShape(Rectangle())
                        }
                        .disabled(pending != nil)
                        .accessibilityIdentifier("apply-workout-template")
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(NotebookStyle.ivory)
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(NotebookTypography.heading(31))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func exerciseCount(_ count: Int) -> String {
        "\(count) \(count == 1 ? "exercise" : "exercises")"
    }

    private func apply(_ workout: WorkoutTemplate, missing: [String]) {
        guard pending == nil, let day = model.selectedDay else { return }
        pending = .apply(day: day, exerciseIDs: missing)
        if model.applyWorkout(workout) { completePendingAction() }
        else if !model.canRetrySave, model.errorMessage == nil { pending = nil }
    }

    private func deleteSelectedWorkout() {
        guard pending == nil, let selection, selection.isPersonal else { return }
        pending = .delete(id: selection.workout.id)
        if model.deleteWorkout(id: selection.workout.id) { completePendingAction() }
        else if !model.canRetrySave, model.errorMessage == nil { pending = nil }
    }

    private func completePendingAction() {
        guard let pending, !model.canRetrySave, model.errorMessage == nil else { return }
        switch pending {
        case .apply(let day, let exerciseIDs):
            guard model.selectedDay == day, exerciseIDs.allSatisfy({ model.workout?.exerciseIDs.contains($0) == true }) else { return }
            self.pending = nil
            close()
        case .delete(let id):
            guard !model.savedWorkouts.contains(where: { $0.id == id }) else { return }
            self.pending = nil
            selection = nil
        }
    }

    private func cancelPendingAction() {
        guard pending != nil else { return }
        pending = nil
        if model.canRetrySave { _ = model.cancelPendingAction() }
        else { model.dismissError() }
    }
}

struct WorkoutLibraryRule: View {
    var body: some View {
        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
    }
}

struct WorkoutLibraryPlanLabel: View {
    let plan: ExercisePlan

    var body: some View {
        let reps = plan.minimumReps == plan.maximumReps ? "\(plan.minimumReps)" : "\(plan.minimumReps)–\(plan.maximumReps)"
        Text("\(plan.workingSets) \(plan.workingSets == 1 ? "working set" : "working sets") · \(reps) \(plan.maximumReps == 1 ? "rep" : "reps")")
            .font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
            .fixedSize(horizontal: false, vertical: true)
    }
}
