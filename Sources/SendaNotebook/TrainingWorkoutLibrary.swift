import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingWorkoutLibrary: View {
    @Bindable var model: TrainingNotebookModel
    let destinationDay: TrainingDay?
    let close: () -> Void
    private let back: (() -> Void)?
    private let embedded: Bool
    @State private var tab: Tab
    @State private var search = ""
    @State private var selection: Selection?
    @State private var chosenDay: TrainingDay?
    @State private var editor: EditorRequest?
    @State private var showsPrograms = false
    @State private var confirmsDeletion = false
    @State private var pending: PendingAction?
    @Environment(\.dynamicTypeSize) private var textSize

    enum Tab: String, CaseIterable {
        case starters = "Starters", personal = "My templates", recent = "Recent"
        var identifier: String {
            switch self {
            case .starters: "starters"
            case .personal: "personal"
            case .recent: "recent"
            }
        }
    }

    init(model: TrainingNotebookModel, destinationDay: TrainingDay? = nil, initialTab: Tab = .starters,
         back: (() -> Void)? = nil, embedded: Bool = false, close: @escaping () -> Void) {
        self.model = model
        self.destinationDay = destinationDay
        self.back = back
        self.embedded = embedded
        self.close = close
        _tab = State(initialValue: initialTab)
    }

    private var destination: TrainingDay {
        if let chosenDay { return chosenDay }
        let initial = destinationDay ?? model.selectedDay ?? model.today
        if case .recent(let source) = selection, let earliest = try? source.day.adding(days: 1) {
            return max(initial, earliest)
        }
        return initial
    }

    private enum Selection {
        case template(WorkoutTemplate, personal: Bool)
        case recent(TrainingWorkoutStructure)

        var id: String {
            switch self {
            case .template(let workout, _): "template-" + workout.id
            case .recent(let workout): "recent-" + workout.day.rawValue
            }
        }
        var exerciseIDs: [String] {
            switch self {
            case .template(let workout, _): workout.exerciseIDs
            case .recent(let workout): workout.exerciseIDs
            }
        }
        var isRecent: Bool {
            if case .recent = self { return true }
            return false
        }
    }

    private var deleteTitle: String {
        if case .template(let workout, personal: true) = selection { return "Delete “\(workout.name)”?" }
        return "Delete template?"
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
                exercisePlans: workout.exercisePlans, supersets: workout.supersets)
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
                switch selection {
                case .template(let workout, let personal): detail(workout, personal: personal)
                case .recent(let workout): WorkoutHistoryPreview(model: model, workout: workout)
                case nil: catalogue
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .id(selection?.id)
        .onChange(of: selection?.id) { _, _ in chosenDay = nil }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(selection == nil ? "workout-library" :
            (selection?.isRecent == true ? "recent-workout-detail" : "workout-template-detail"))
        .safeAreaInset(edge: .top, spacing: 0) {
            if !embedded || selection != nil {
                navigation
                    .padding(.horizontal, 24).padding(.vertical, 6)
                    .frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory)
                    .overlay(alignment: .bottom) { WorkoutLibraryRule() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .scrollIndicators(.never)
        .interactiveDismissDisabled(pending != nil)
        .confirmationDialog(deleteTitle, isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete template", role: .destructive, action: deleteSelectedWorkout)
                .accessibilityIdentifier("confirm-delete-workout-template")
        } message: {
            Text("Workouts you’ve logged will stay in your journal.")
        }
        .sheet(isPresented: $showsPrograms) {
            TrainingProgramLibrary(model: model)
        }
        .sheet(item: $editor) { request in
            TrainingWorkoutTemplateEditor(model: model, template: request.original,
                isEditing: request.isEditing, copiesCurrentDay: request.copiesCurrentDay, close: { editor = nil }, saved: { workout in
                    if request.isEditing { selection = .template(workout, personal: true) }
                    else { tab = .personal; search = ""; selection = nil }
                    editor = nil
                })
        }
        .onChange(of: model.canRetrySave) { _, _ in completePendingAction() }
        .onChange(of: model.errorMessage) { _, _ in completePendingAction() }
        .onChange(of: model.selectedDay) { _, day in
            if case .apply(let expected, _) = pending, day == expected { completePendingAction() }
            else { cancelPendingAction() }
        }
        .onDisappear { cancelPendingAction() }
        #if os(macOS)
        .frame(minWidth: embedded ? nil : 320, idealWidth: embedded ? nil : 460,
               minHeight: embedded ? nil : 568, idealHeight: embedded ? nil : 740)
        #endif
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            if selection != nil {
                Button {
                    cancelPendingAction()
                    selection = nil
                } label: {
                    Label(embedded ? "Workouts" : "Workout library", systemImage: "chevron.left")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("back-to-workout-library")
            } else if let back {
                Button(action: back) {
                    Label("Exercises", systemImage: "chevron.left").frame(minWidth: 44, minHeight: 44)
                }.accessibilityIdentifier("close-workout-reuse")
            }
            Spacer(minLength: 0)
            if !embedded {
                Button {
                    cancelPendingAction()
                    close()
                } label: {
                    Text("Done").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("close-workout-library")
            }
        }
    }

    private var catalogue: some View {
        VStack(alignment: .leading, spacing: 16) {
            if embedded {
                TrainingLibraryHeader(model: model)
                Button { showsPrograms = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                        Text("Programs").font(.body.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityHint("Browse, create, or schedule a training program")
                .accessibilityIdentifier("library-programs")
            } else {
                HStack(alignment: .center, spacing: 12) {
                    heading("Workout library").frame(maxWidth: .infinity, alignment: .leading)
                    if showsCreateButton { createButton }
                }
            }
            sourceTabs
            if embedded && showsCreateButton && textSize.isAccessibilitySize { createButton }
            searchField
            switch tab {
            case .starters:
                let all = model.starterWorkouts
                let lead = ["push", "pull", "legs"]
                let ordered = lead.compactMap { id in all.first { $0.id == id } } + all.filter { !lead.contains($0.id) }
                let workouts = model.matchingWorkouts(ordered, query: search)
                if workouts.isEmpty { noMatches } else { templateRows(workouts, isPersonal: false) }
            case .personal:
                let workouts = model.matchingWorkouts(model.savedWorkouts, query: search)
                if model.savedWorkouts.isEmpty {
                    Text("No saved templates").font(.body.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    Button("Create template") { editor = .new }
                        .foregroundStyle(NotebookStyle.clay).frame(minHeight: 44)
                        .accessibilityIdentifier("create-workout-template")
                } else if workouts.isEmpty { noMatches } else { templateRows(workouts, isPersonal: true) }
                if destination == model.selectedDay, !model.tabs.isEmpty {
                    Button { editor = .currentDay } label: {
                        Text("Save this workout as a template")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityIdentifier("save-day-as-workout-template")
                }
            case .recent:
                let available = model.reusableWorkouts(before: embedded ? nil : destination)
                let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
                let workouts = available.filter { workout in
                    query.isEmpty || TrainingText.date(workout.day, format: "EEEE, MMMM d, yyyy").localizedStandardContains(query)
                        || workout.day.rawValue.contains(query)
                        || workout.exerciseIDs.contains { model.exercise($0).displayName.localizedStandardContains(query) }
                }
                if available.isEmpty {
                    emptyState("No recent workouts", hint: embedded ? "Workouts with logged sets appear here."
                        : "Workouts with logged sets before \(TrainingText.date(destination, format: "MMM d")) appear here.")
                    Button("Browse starters") { tab = .starters; search = "" }
                        .foregroundStyle(NotebookStyle.clay).frame(minHeight: 44)
                } else if workouts.isEmpty { noMatches } else {
                    VStack(spacing: 0) {
                        ForEach(workouts) { workout in
                            let date = TrainingText.date(workout.day, format: "EEEE, MMM d, yyyy")
                            libraryRow(date, subtitle: exercisePreview(workout.exerciseIDs)) {
                                selection = .recent(workout)
                            }
                            .accessibilityLabel(date)
                            .accessibilityValue("\(exerciseCount(workout.exerciseIDs.count)), \(setCount(workout.recordedSetCount))")
                            .accessibilityHint("Review exercises and logged sets")
                            .accessibilityIdentifier("reuse-workout-day-\(workout.day.rawValue)")
                            WorkoutLibraryRule()
                        }
                    }
                }
            }
        }
    }

    private var showsCreateButton: Bool {
        tab == .starters || (tab == .personal && !model.savedWorkouts.isEmpty)
    }

    private var createButton: some View {
        Button { editor = .new } label: {
            Label("New template", systemImage: "plus")
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: true, vertical: true)
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.clay)
        .accessibilityLabel("Create template")
        .accessibilityIdentifier("create-workout-template")
    }

    private var sourceTabs: some View {
        LibrarySegments(stacked: textSize.isAccessibilitySize) {
            ForEach(Tab.allCases, id: \.self) { source in
                Button {
                    tab = source
                    search = ""
                } label: {
                    LibrarySegmentLabel(title: source.rawValue, selected: tab == source, expands: true)
                }
                .accessibilityLabel(source.rawValue)
                .accessibilityAddTraits(tab == source ? .isSelected : [])
                .accessibilityIdentifier("workout-library-tab-\(source.identifier)")
            }
        }
    }

    private func emptyState(_ title: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.body.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text(hint).font(.callout).foregroundStyle(NotebookStyle.quiet)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private var noMatches: some View {
        Text("No matching workouts.").font(.body).foregroundStyle(NotebookStyle.quiet)
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
                if embedded && showsCreateButton && !textSize.isAccessibilitySize { createButton }
            }
            WorkoutLibraryRule()
        }
    }

    private func templateRows(_ workouts: [WorkoutTemplate], isPersonal: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(workouts) { workout in
                libraryRow(workout.name, subtitle: exercisePreview(workout.exerciseIDs)) {
                    selection = .template(workout, personal: isPersonal)
                }.accessibilityIdentifier("workout-template-\(workout.id)")
                WorkoutLibraryRule()
            }
        }
    }

    private func exercisePreview(_ ids: [String]) -> String {
        let names = ids.prefix(2).map { model.exercise($0).displayName }.joined(separator: ", ")
        return ids.count > 2 ? "\(names) +\(ids.count - 2)" : names
    }

    private func libraryRow(_ title: String, subtitle: String, select: @escaping () -> Void) -> some View {
        Button(action: select) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.semibold))
                    Text(subtitle).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.medium))
                    .foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            }
            .padding(.vertical, 12).frame(minHeight: 44).contentShape(Rectangle())
        }
    }

    private func detail(_ workout: WorkoutTemplate, personal: Bool) -> some View {
        let current = Set(model.workspace.days[destination.rawValue]?.exerciseIDs ?? [])
        let customIDs = Set(model.snapshot.customExercises?.map(\.id) ?? [])
        return VStack(alignment: .leading, spacing: 18) {
            heading(workout.name)
            let plans = workout.exercisePlans.values
            let count = exerciseCount(workout.exerciseIDs.count)
            Text(plans.count == workout.exerciseIDs.count
                 ? "\(count) · \(setCount(plans.reduce(0) { $0 + $1.workingSets }))" : count)
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            managementActions(workout, personal: personal)
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
                        if model.exercise(id).isArchived {
                            Text("Removed from library").font(.caption).foregroundStyle(NotebookStyle.quiet)
                        } else if customIDs.contains(id) {
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

        }
    }

    @ViewBuilder private func managementActions(_ workout: WorkoutTemplate, personal: Bool) -> some View {
        if personal {
            let layout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(spacing: 24))
            layout {
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

    @ViewBuilder private var footer: some View {
        if selection != nil || pending != nil {
            VStack(spacing: 0) {
                WorkoutLibraryRule()
                Group {
                    if let error = model.errorMessage, pending != nil {
                        TrainingSaveError(model: model, message: error, retrySucceeded: completePendingAction)
                    } else if let selection {
                        let available = model.availableWorkoutExerciseIDs(selection.exerciseIDs, on: destination)
                        let skipped = selection.exerciseIDs.count - available.count
                        VStack(spacing: 4) {
                            if skipped > 0 {
                                Text(available.isEmpty ? "All exercises in this workout were removed from your library."
                                     : (skipped == 1 ? "One removed exercise will be skipped." : "\(skipped) removed exercises will be skipped."))
                                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            destinationPicker(for: selection)
                            RecordButton(title: applyTitle(for: selection, exerciseIDs: available)) { apply(selection, exerciseIDs: available) }
                                .disabled(pending != nil || available.isEmpty)
                                .accessibilityHint("Add exercises to \(TrainingText.date(destination, format: "EEEE, MMM d, yyyy")) with existing entries preserved.")
                                .accessibilityIdentifier(selection.isRecent ? "apply-recent-workout" : "apply-workout-template")
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(NotebookStyle.ivory)
        }
    }

    private func destinationPicker(for selection: Selection) -> some View {
        let date = Binding(get: { destination.date(in: model.calendar) }, set: {
            chosenDay = TrainingDay($0, calendar: model.calendar)
        })
        // Reusing a logged workout always copies its structure forward in time.
        let earliest: Date = if case .recent(let workout) = selection,
                                let followingDay = try? workout.day.adding(days: 1) {
            model.calendar.startOfDay(for: followingDay.date(in: model.calendar))
        } else { .distantPast }
        return DatePicker("Workout date", selection: date, in: earliest..., displayedComponents: .date)
            .datePickerStyle(.compact)
            .environment(\.calendar, model.calendar)
            .environment(\.timeZone, model.calendar.timeZone)
            .frame(minHeight: 44)
            .disabled(pending != nil)
            .accessibilityIdentifier("workout-destination-date")
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(NotebookTypography.heading(31))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func exerciseCount(_ count: Int) -> String {
        "\(count) \(count == 1 ? "exercise" : "exercises")"
    }

    private func setCount(_ count: Int) -> String {
        "\(count) \(count == 1 ? "set" : "sets")"
    }

    private func applyTitle(for selection: Selection, exerciseIDs: [String]) -> String {
        if selection.isRecent { return "Use this workout" }
        let existing = Set(model.workspace.days[destination.rawValue]?.exerciseIDs ?? [])
        let missing = exerciseIDs.filter { !existing.contains($0) }
        if existing.isEmpty || missing.isEmpty { return "Use template" }
        return "Add \(exerciseCount(missing.count))"
    }

    private func apply(_ selection: Selection, exerciseIDs: [String]) {
        guard pending == nil, !exerciseIDs.isEmpty else { return }
        let day = destination
        pending = .apply(day: day, exerciseIDs: exerciseIDs)
        let succeeded: Bool
        switch selection {
        case .template(let workout, _): succeeded = model.applyWorkout(workout, on: day)
        case .recent(let workout): succeeded = model.reuseWorkout(from: workout.day, on: day)
        }
        if succeeded { completePendingAction() }
        else if !model.canRetrySave, model.errorMessage == nil { pending = nil }
    }

    private func deleteSelectedWorkout() {
        guard pending == nil, case .template(let workout, personal: true) = selection else { return }
        pending = .delete(id: workout.id)
        if model.deleteWorkout(id: workout.id) { completePendingAction() }
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

extension TrainingNotebookModel {
    func matchingWorkouts(_ workouts: [WorkoutTemplate], query search: String) -> [WorkoutTemplate] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return workouts }
        return workouts.filter { workout in
            workout.name.localizedStandardContains(query) || workout.exerciseIDs.contains {
                exercise($0).displayName.localizedStandardContains(query)
            }
        }
    }
}
