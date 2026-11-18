import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingLearnView: View {
    @Bindable var model: TrainingNotebookModel
    @FocusState private var searchFocused: Bool
    @State private var presentedGuideID: String?
    @State private var editingSetup: Exercise?
    @StoredExerciseGymFilter private var gymFilter
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

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
        .sheet(item: $editingSetup) { exercise in
            CustomExerciseSetupEditor(setup: exercise.customSetup, saveError: { model.errorMessage },
                onCancelPending: { if model.canRetrySave { _ = model.cancelPendingAction() } },
                onSave: { model.updateCustomExerciseSetup($0, for: exercise.id) })
        }
    }

    private var exerciseList: some View {
        let exercises = model.exercises
        let results = model.learningResults(in: exercises, gymFilter: gymFilter)
        let byGroup = Dictionary(grouping: results, by: \.group)
        let groups = MuscleGroup.allCases.filter { byGroup[$0] != nil }
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let controls = textSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                        : AnyLayout(HStackLayout(spacing: 12))
                    controls {
                        Text("Learn").font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if model.learningScope == .library {
                            LibraryGymFilterButton(filter: $gymFilter, identifier: "learn-gym-filters", resultCount: {
                                ExerciseFormGuide.search(model.learningQuery, in: exercises, gymFilter: $0).count
                            }, onOpen: { searchFocused = false })
                        }
                    }
                    search
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
                               let custom = model.snapshot.customExercises?.first(where: { $0.id == recovery.exercise.id }) {
                                Button { searchFocused = false; editingSetup = custom } label: {
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
                // When Learn remounts from another tab, return near the open guide's row.
                guard let id = presentedGuideID, id == model.learningExerciseID else { return }
                await Task.yield()
                guard !Task.isCancelled, id == model.learningExerciseID else { return }
                proxy.scrollTo("learn-exercise-\(id)", anchor: .center)
            }
        }
    }

    private var scopeControls: some View {
        let layout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                                                  : AnyLayout(HStackLayout(spacing: 20))
        return layout {
            scopeButton("All exercises", personal: false, identifier: "learn-all-exercises")
            scopeButton("My exercises", personal: true, identifier: "learn-my-exercises")
        }
    }

    private func scopeButton(_ title: String, personal: Bool, identifier: String) -> some View {
        let selected = personal == (model.learningScope != .library)
        return Button {
            guard !selected else { return }
            searchFocused = false
            model.learningScope = personal ? .personal : .library
        } label: {
            HStack(spacing: 5) {
                if selected { Image(systemName: "checkmark").font(.caption.bold()).accessibilityHidden(true) }
                Text(title).font(.subheadline.weight(selected ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.ink)
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
            } else if model.snapshot.customExercises?.isEmpty != false {
                Text("No custom exercises yet").font(.headline).accessibilityAddTraits(.isHeader)
                Text("To create one, open Add exercise in a workout.").foregroundStyle(NotebookStyle.quiet)
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
        let custom = model.snapshot.customExercises?.first { $0.id == id }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ExerciseLearningDetail(exercise: model.exercise(id))
                if let custom {
                    Divider().overlay(NotebookStyle.rule)
                    Button { editingSetup = custom } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Edit gym & equipment").font(.body.weight(.semibold)).foregroundStyle(NotebookStyle.clay)
                            Text(custom.customSetup.summary).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("edit-custom-setup")
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
            if model.learningScope == .needsDetails { editingSetup = exercise }
            else { model.learningExerciseID = exercise.id }
        } label: {
            HStack(spacing: 12) {
                if model.learningScope == .library {
                    Group {
                        if let visual = exercise.presetID.flatMap(ExerciseFormVisual.guide(for:)), let frame = visual.frames.first {
                            ExerciseArtworkImage(name: frame.resourceName, maximumPixelSize: 192)
                                .scaledToFit().blendMode(.multiply)
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
                searchFocused = false
                model.learningExerciseID = nil
            } label: {
                Label("Learn", systemImage: "chevron.left").frame(minHeight: 44)
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
}
