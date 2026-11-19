import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingExerciseLibrary: View {
    @Bindable var model: TrainingNotebookModel
    @FocusState private var searchFocused: Bool
    @State private var presentedGuideID: String?
    @State private var editor: Editor?
    @State private var confirmsDelete = false
    @State private var pendingDeleteID: String?
    @StoredExerciseGymFilter private var gymFilter
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    private enum Editor: Identifiable {
        case create, edit(Exercise), setup(Exercise)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let exercise): "edit-" + exercise.id
            case .setup(let exercise): "setup-" + exercise.id
            }
        }
    }

    init(model: TrainingNotebookModel) {
        self.model = model
        _presentedGuideID = State(initialValue: model.learningExerciseID)
    }

    private var motion: TrainingPageMotion { TrainingPageMotion(reduceMotion: reduceMotion) }
    private var guideOffset: CGFloat {
        layoutDirection == .rightToLeft ? -TrainingPageMotion.detailOffset : TrainingPageMotion.detailOffset
    }

    var body: some View {
        let showingGuide = presentedGuideID != nil
        let listIsActive = !showingGuide && model.learningExerciseID == nil
        ZStack {
            // Keep the list mounted so returning keeps its exact scroll offset.
            exerciseList
                .id(model.landingResetID)
                .animation(motion.opacityAnimation(appearing: !showingGuide)) { view in
                    view.opacity(showingGuide ? 0 : 1)
                }
                .offset(x: showingGuide && !reduceMotion ? -guideOffset : 0)
                .allowsHitTesting(listIsActive)
                .accessibilityHidden(!listIsActive)
            if let id = presentedGuideID {
                guide(id)
                    .allowsHitTesting(model.learningExerciseID == id)
                    .accessibilityHidden(model.learningExerciseID != id)
                    .id(id)
                    .transition(motion.transition(entryOffset: guideOffset))
                    .zIndex(1)
            }
        }
        .clipped()
        .onChange(of: model.learningExerciseID) { _, next in
            withAnimation(motion.animation) { presentedGuideID = next }
        }
        .onChange(of: model.landingResetID) { _, _ in searchFocused = false }
        .sheet(item: $editor) { request in
            switch request {
            case .create:
                LibraryCustomExerciseEditor(model: model, exercise: nil, saved: showSavedExercise)
            case .edit(let exercise):
                LibraryCustomExerciseEditor(model: model, exercise: exercise, saved: showSavedExercise)
            case .setup(let exercise):
                CustomExerciseSetupEditor(setup: exercise.customSetup, saveError: { model.errorMessage },
                    onCancelPending: { if model.canRetrySave { _ = model.cancelPendingAction() } },
                    onSave: { model.updateCustomExerciseSetup($0, for: exercise.id) })
            }
        }
        .confirmationDialog(deleteTitle, isPresented: $confirmsDelete, titleVisibility: .visible,
                            presenting: model.learningExerciseID) { id in
            Button("Delete exercise", role: .destructive) { deleteExercise(id) }
                .accessibilityIdentifier("confirm-delete-library-exercise")
        } message: { _ in
            Text("This removes the exercise from your library. Your workouts and logged sets stay in your notebook.")
        }
        .onChange(of: model.canRetrySave) { _, _ in finishDelete() }
        .onChange(of: model.errorMessage) { _, _ in finishDelete() }
        .onDisappear { cancelDelete() }
    }

    private var exerciseList: some View {
        let exercises = model.activeExercises
        let results = model.learningResults(in: exercises, gymFilter: gymFilter)
        let byGroup = Dictionary(grouping: results, by: \.group)
        let groups = MuscleGroup.allCases.filter { byGroup[$0] != nil }
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TrainingLibraryHeader(model: model)
                    let controls = textSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                        : AnyLayout(HStackLayout(spacing: 12))
                    controls {
                        search
                        if model.learningScope == .library {
                            LibraryGymFilterButton(filter: $gymFilter, identifier: "learn-gym-filters", resultCount: {
                                ExerciseFormGuide.search(model.learningQuery, in: exercises, gymFilter: $0).count
                            }, onOpen: { searchFocused = false })
                        }
                    }
                    scopeControls
                    if model.learningScope == .library {
                        GymSetupSwitcher(onSwitch: { searchFocused = false })
                        let recovery = gymFilter.activeCount > 0 && !model.learningQuery.isEmpty
                            ? ExerciseSearchRecovery.find(query: model.learningQuery, in: exercises, gymFilter: gymFilter,
                                includePartialMatch: results.isEmpty, excludingAlternatives: Set(results.map(\.id)))
                            : nil
                        if let recovery {
                            ExerciseSearchRecoveryView(recovery: recovery, row: exerciseRow)
                            if recovery.reason == .gymsUnspecified || recovery.reason == .equipmentUnspecified,
                               model.canManageCustomExercise(recovery.exercise.id) {
                                Button { searchFocused = false; editor = .setup(recovery.exercise) } label: {
                                    Text("Edit gym & equipment").frame(minHeight: 44).contentShape(Rectangle())
                                }.accessibilityIdentifier("learn-edit-missing-setup")
                            }
                        }
                        if results.isEmpty { emptyState(explained: recovery != nil) }
                    } else {
                        personalFilters
                        if results.isEmpty { personalEmptyState }
                    }
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups, id: \.self) { group in
                            Section {
                                ForEach(byGroup[group] ?? []) { exercise in
                                    VStack(spacing: 0) {
                                        exerciseRow(exercise)
                                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
                                    }
                                    .id("learn-exercise-\(exercise.id)")
                                }
                            } header: {
                                Text(group.rawValue)
                                    .font(NotebookTypography.heading(22, relativeTo: .title2))
                                    .accessibilityAddTraits(.isHeader)
                                    .padding(.bottom, 8)
                                    .padding(.top, group == groups.first ? 0 : 16)
                            }
                        }
                    }
                    // A gym switch can replace hundreds of rows. Reset their layout while keeping the search field mounted.
                    .id(model.learningScope == .library ? gymFilter : .init())
                }
                .padding(24).padding(.bottom, 8)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .clipped()
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("learn-scroll")
            .task { [presentedGuideID] in
                // When Exercises reopens from another tab, return near the open guide's row.
                guard let id = presentedGuideID, id == model.learningExerciseID else { return }
                await Task.yield()
                guard !Task.isCancelled, id == model.learningExerciseID else { return }
                proxy.scrollTo("learn-exercise-\(id)", anchor: .center)
            }
        }
    }

    private var scopeControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                LibrarySegments(stacked: false) { exerciseScopes }
                Spacer(minLength: 0)
                addExercise
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 0) {
                addExercise
                LibrarySegments(stacked: false) { exerciseScopes }
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 0) {
                addExercise
                LibrarySegments(stacked: true) { exerciseScopes }
            }
        }
    }

    @ViewBuilder private var exerciseScopes: some View {
        scopeButton("All exercises", personal: false, identifier: "learn-all-exercises")
        scopeButton("My exercises", personal: true, identifier: "learn-my-exercises")
    }

    private var addExercise: some View {
        Button {
            searchFocused = false
            editor = .create
        } label: {
            Label("Add exercise", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.clay)
        .accessibilityIdentifier("library-add-exercise")
    }

    private func scopeButton(_ title: String, personal: Bool, identifier: String) -> some View {
        let selected = personal == (model.learningScope != .library)
        return Button {
            guard !selected else { return }
            searchFocused = false
            model.learningScope = personal ? .personal : .library
        } label: {
            LibrarySegmentLabel(title: title, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier(identifier)
    }

    private var personalFilters: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Needs details", isOn: Binding(get: { model.learningScope == .needsDetails }, set: {
                searchFocused = false
                model.learningScope = $0 ? .needsDetails : .personal
            }))
            .frame(minHeight: 44).tint(NotebookStyle.clay).accessibilityIdentifier("learn-needs-details")
            if gymFilter.activeCount > 0 {
                Text("Includes exercises from all gyms.").font(.caption).foregroundStyle(NotebookStyle.quiet)
            }
        }
    }

    @ViewBuilder private var personalEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.learningQuery.isEmpty {
                Text("No matching custom exercises").font(.headline).accessibilityAddTraits(.isHeader)
                Button { model.learningQuery = ""; searchFocused = false } label: {
                    Text("Clear search").frame(minHeight: 44).contentShape(Rectangle())
                }
            } else if !(model.snapshot.customExercises ?? []).contains(where: { model.canManageCustomExercise($0.id) }) {
                Text("No custom exercises yet").font(.headline).accessibilityAddTraits(.isHeader)
            } else {
                Text("All your exercises have gym and equipment details.").font(.headline).accessibilityAddTraits(.isHeader)
                Button { model.learningScope = .personal } label: {
                    Text("Show all my exercises").frame(minHeight: 44).contentShape(Rectangle())
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("learn-personal-empty")
    }

    private func guide(_ id: String) -> some View {
        let exercise = model.exercise(id)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if model.canManageCustomExercise(id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.displayName).font(NotebookTypography.heading(31))
                            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("form-guide-\(id)")
                        Text("\(exercise.group.rawValue) · \(exercise.equipmentLabel)")
                            .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    }
                    Button { editor = .edit(exercise) } label: {
                        Label("Edit exercise", systemImage: "pencil")
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .foregroundStyle(NotebookStyle.clay).disabled(pendingDeleteID != nil)
                    .accessibilityIdentifier("library-edit-exercise")
                    WorkoutLibraryRule()
                    Button { editor = .setup(exercise) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Edit gym & equipment").font(.body.weight(.semibold)).foregroundStyle(NotebookStyle.clay)
                            Text(exercise.customSetup.summary).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(pendingDeleteID != nil).accessibilityIdentifier("edit-custom-setup")
                    WorkoutLibraryRule()
                    Button(role: .destructive) { confirmsDelete = true } label: {
                        Text("Delete exercise").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .disabled(pendingDeleteID != nil)
                    .accessibilityIdentifier("library-delete-exercise")
                    if pendingDeleteID != nil, let error = model.errorMessage {
                        TrainingSaveError(model: model, message: error, retrySucceeded: finishDelete)
                    }
                } else {
                    ExerciseLearningDetail(exercise: exercise)
                }
            }
            .padding(24).padding(.bottom, 8)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .clipped()
        .accessibilityIdentifier("learn-guide-scroll")
        .safeAreaInset(edge: .top, spacing: 0) { navigation }
        .background(NotebookStyle.ivory)
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            TextField(model.learningScope == .library ? "Find an exercise" : "Find a custom exercise", text: $model.learningQuery)
                .textFieldStyle(.plain).autocorrectionDisabled()
                .focused($searchFocused).submitLabel(.search)
                .onSubmit { searchFocused = false }
                .accessibilityIdentifier("learn-search")
            if !model.learningQuery.isEmpty {
                Button { model.learningQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16)).foregroundStyle(NotebookStyle.quiet)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("learn-search-clear")
            }
        }
        .padding(.leading, 12).padding(.trailing, 4).frame(minHeight: 48)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(NotebookStyle.rule, lineWidth: 1))
    }

    private func emptyState(explained: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !explained {
                Text("No exercises found")
                    .font(NotebookTypography.heading(22, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                Text(gymFilter.activeCount > 0 ? "Try another search or clear your gym and equipment filters." : "Try a different exercise name, muscle group, or equipment.")
                    .foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if gymFilter.activeCount > 0 {
                Button {
                    searchFocused = false
                    gymFilter = .init()
                } label: {
                    Text("Clear filters").frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("learn-clear-gym-filters")
            }
            if !model.learningQuery.isEmpty {
                Button {
                    searchFocused = false
                    model.learningQuery = ""
                } label: {
                    Text("Clear search").frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("learn-empty-clear")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("learn-empty-state")
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            searchFocused = false
            if model.learningScope == .needsDetails && model.canManageCustomExercise(exercise.id) { editor = .setup(exercise) }
            else { model.learningExerciseID = exercise.id }
        } label: {
            HStack(spacing: 12) {
                if model.learningScope == .library && !textSize.isAccessibilitySize {
                    Group {
                        if let visual = exercise.presetID.flatMap(ExerciseFormVisual.guide(for:)), let frame = visual.frames.first {
                            ExerciseArtworkImage(name: frame.resourceName, maximumPixelSize: 192)
                                .scaledToFit()
                        } else if let muscles = exercise.muscleMap {
                            ExerciseMuscleThumbnail(map: muscles)
                        } else {
                            Color.clear
                        }
                    }.frame(width: 58, height: 58).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.displayName).font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(exerciseSubtitle(exercise))
                        .font(.caption).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 12))
                    .foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            }.padding(.vertical, 8).frame(minHeight: 76).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("learn-exercise-\(exercise.id)")
    }

    private var navigation: some View {
        HStack {
            Button {
                cancelDelete()
                searchFocused = false
                model.learningExerciseID = nil
            } label: {
                Label("Exercises", systemImage: "chevron.left").frame(minHeight: 44)
            }.accessibilityIdentifier("back-to-learn")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24).padding(.vertical, 4)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory)
        .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("learn-navigation")
    }

    private func exerciseSubtitle(_ exercise: Exercise) -> String {
        if model.learningScope != .library {
            let setup = exercise.customSetup
            if setup.isEmpty { return "Add gym type and equipment" }
            if setup.gyms.isEmpty { return "Add gym type" }
            if setup.requiredEquipment == nil { return "Add required equipment" }
            return setup.summary
        }
        guard let muscles = exercise.muscleMap else {
            return exercise.presetID == nil ? "Guide not added yet" : exercise.equipmentLabel
        }
        return muscles.primary.map(\.name).joined(separator: ", ") + " · " + exercise.equipmentLabel
    }

    private func showSavedExercise(_ exercise: Exercise) {
        if case .create = editor {
            model.learningScope = .personal
            model.learningQuery = ""
        }
        editor = nil
        model.learningExerciseID = exercise.id
    }

    private var deleteTitle: String {
        guard let id = model.learningExerciseID else { return "Delete this exercise?" }
        return "Delete \(model.exercise(id).displayName)?"
    }

    private func deleteExercise(_ id: String) {
        guard model.canManageCustomExercise(id) else { return }
        pendingDeleteID = id
        if model.archiveCustomExercise(id) { finishDelete() }
    }

    private func finishDelete() {
        guard let id = pendingDeleteID, !model.canRetrySave, model.errorMessage == nil,
              !model.canManageCustomExercise(id) else { return }
        pendingDeleteID = nil
        model.learningExerciseID = nil
    }

    private func cancelDelete() {
        guard pendingDeleteID != nil else { return }
        pendingDeleteID = nil
        if model.canRetrySave { _ = model.cancelPendingAction() }
        else { model.dismissError() }
    }
}

struct TrainingGuideLibrary: View {
    @Bindable var model: TrainingNotebookModel
    @FocusState private var searching: Bool
    @Environment(\.dynamicTypeSize) private var textSize

    // Guides describe the published movement, even when an imported custom exercise shares its ID.
    private static let formExercises = Exercise.catalog.filter { ExerciseFormGuide.guide(for: $0.id) != nil }
    private static let mappedExercises = Exercise.catalog.filter { $0.muscleMap != nil }

    var body: some View {
        if let topic = model.guideTopic {
            let exercises = topic == .form ? Self.formExercises : Self.mappedExercises
            let selected = exercises.first { $0.id == model.guideExerciseID }
            ZStack {
                guideList(topic, exercises: exercises)
                    .opacity(selected == nil ? 1 : 0)
                    .allowsHitTesting(selected == nil)
                    .accessibilityHidden(selected != nil)
                if let selected {
                    guideDetail(topic, exercise: selected)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Button {
                    searching = false
                    if selected != nil {
                        model.guideExerciseID = nil
                    } else {
                        model.guideQuery = ""
                        model.guideTopic = nil
                    }
                } label: {
                    Label(selected == nil ? "Learn" : topic.rawValue, systemImage: "chevron.left")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier(selected == nil ? "back-to-learn-topics" : "back-to-guides")
                .padding(.horizontal, 24).padding(.vertical, 4)
                .frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
                .background(NotebookStyle.ivory)
                .overlay(alignment: .bottom) { WorkoutLibraryRule() }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TrainingLibraryHeader(model: model)
                    VStack(spacing: 0) {
                        ForEach(TrainingGuideTopic.allCases, id: \.self) { topic in
                            topicRow(topic)
                            WorkoutLibraryRule()
                        }
                    }
                }
                .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("learn-topics")
        }
    }

    private func topicRow(_ topic: TrainingGuideTopic) -> some View {
        Button {
            model.guideExerciseID = nil
            model.guideQuery = ""
            model.guideTopic = topic
        } label: {
            HStack(spacing: 16) {
                if !textSize.isAccessibilitySize {
                    if topic == .form, let frame = ExerciseFormVisual.guide(for: "bench")?.frames.last {
                        ExerciseArtworkImage(name: frame.resourceName, maximumPixelSize: 220)
                            .scaledToFit()
                            .frame(width: 64, height: 64).accessibilityHidden(true)
                    } else if let map = ExerciseMuscleMap.map(for: "bench") {
                        ExerciseMuscleThumbnail(map: map).frame(width: 64, height: 64)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.rawValue).font(NotebookTypography.heading(22, relativeTo: .title2))
                    Text(topic == .form ? "Setup, movement, and form cues" : "Primary and supporting muscles")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            }
            .padding(.vertical, 12).contentShape(Rectangle())
        }
        .accessibilityIdentifier(topic == .form ? "learn-topic-form" : "learn-topic-muscles")
    }

    private func guideList(_ topic: TrainingGuideTopic, exercises: [Exercise]) -> some View {
        let results = ExerciseFormGuide.search(model.guideQuery, in: exercises)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(topic.rawValue).font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
                    TextField(topic == .form ? "Find a form guide" : "Find an exercise or muscle", text: $model.guideQuery)
                        .textFieldStyle(.plain).autocorrectionDisabled().submitLabel(.search)
                        .focused($searching).onSubmit { searching = false }
                        .frame(minHeight: 44).accessibilityIdentifier("guide-search")
                    if !model.guideQuery.isEmpty {
                        Button { model.guideQuery = "" } label: {
                            Label("Clear search", systemImage: "xmark.circle.fill").labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityIdentifier("guide-clear-search")
                    }
                }
                .padding(.horizontal, 10)
                .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(NotebookStyle.rule) }
                if results.isEmpty {
                    Text("No matching guides").font(.callout).foregroundStyle(NotebookStyle.quiet)
                }
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(results) { exercise in
                        Button {
                            searching = false
                            model.guideExerciseID = exercise.id
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name).font(.body.weight(.medium))
                                    let muscles = exercise.muscleMap?.primary.map(\.name).joined(separator: ", ")
                                    Text(topic == .muscles ? (muscles ?? exercise.group.rawValue) : exercise.equipmentLabel)
                                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").font(.caption)
                                    .foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
                            }
                            .frame(minHeight: 44).padding(.vertical, 8).contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("guide-exercise-\(exercise.id)")
                        WorkoutLibraryRule()
                    }
                }
            }
            .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("guide-list")
    }

    private func guideDetail(_ topic: TrainingGuideTopic, exercise: Exercise) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if topic == .form {
                    ExerciseLearningDetail(exercise: exercise)
                } else if let map = exercise.muscleMap {
                    Text(exercise.name).font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                    Text(map.variation).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    ExerciseMuscleMapView(map: map).accessibilityIdentifier("exercise-muscles-\(exercise.id)")
                }
            }
            .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(NotebookStyle.ivory)
        .accessibilityIdentifier("guide-detail")
    }
}
