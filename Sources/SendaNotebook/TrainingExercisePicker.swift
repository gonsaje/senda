import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingExercisePicker: View {
    @Bindable private var model: TrainingNotebookModel
    private let close: () -> Void
    private let inlineBrowse: ((String, Bool) -> Void)?
    @State private var recentSuggestions: [Exercise] = []
    @State private var search = ""
    @State private var group: MuscleGroup?
    @State private var equipment: ExerciseEquipment?
    @StoredExerciseGymFilter private var gymFilter
    @State private var draft = FilterDraft()
    @State private var editingGym = false
    @State private var creating = false
    @State private var reusing = false
    @State private var filtersExpanded = false
    @State private var selectingSeveral = false
    @State private var selectedIDs: [String] = []
    @State private var pendingAdd: PendingAdd?
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .subheadline) private var selectionBadgeSize: CGFloat = 30
    @FocusState private var searching: Bool

    private struct PendingAdd {
        let day: TrainingDay
        let ids: [String]
        let selectedID: String?
    }

    private struct FilterDraft {
        var group: MuscleGroup?
        var equipment: ExerciseEquipment?
        var gymFilter = ExerciseGymFilter()

        var count: Int {
            (group == nil ? 0 : 1) + (equipment == nil ? 0 : 1) + gymFilter.activeCount
        }
    }

    public init(model: TrainingNotebookModel, initialSearch: String = "", selectingSeveral: Bool = false, close: @escaping () -> Void) {
        self.model = model; self.close = close; inlineBrowse = nil
        _search = State(initialValue: initialSearch)
        _selectingSeveral = State(initialValue: selectingSeveral)
    }

    init(inline model: TrainingNotebookModel, close: @escaping () -> Void, browse: @escaping (String, Bool) -> Void) {
        self.model = model; self.close = close; inlineBrowse = browse
    }

    /// Seeds otherwise local presentation state for deterministic native preview captures.
    @_spi(Preview) public init(model: TrainingNotebookModel, search: String, group: MuscleGroup? = nil,
        equipment: ExerciseEquipment? = nil, showsFilters: Bool = false, selectedIDs: [String]? = nil,
        close: @escaping () -> Void) {
        self.model = model; self.close = close; inlineBrowse = nil
        _search = State(initialValue: search); _group = State(initialValue: group)
        _equipment = State(initialValue: equipment); _filtersExpanded = State(initialValue: showsFilters)
        _draft = State(initialValue: FilterDraft(group: group, equipment: equipment))
        _selectingSeveral = State(initialValue: selectedIDs != nil)
        _selectedIDs = State(initialValue: selectedIDs ?? [])
    }

    private var currentFilters: FilterDraft { FilterDraft(group: group, equipment: equipment, gymFilter: gymFilter) }
    private var filterCount: Int { currentFilters.count }
    private var recent: [Exercise] {
        ExerciseSelectionFilter.results(in: model.recentExercises(), query: search, group: group, equipment: equipment,
                                        gymFilter: gymFilter)
    }

    private func libraryMatches(excluding recent: [Exercise]) -> [Exercise] {
        let recentIDs = Set(recent.map(\.id))
        let library = ExerciseSelectionFilter.results(in: model.activeExercises, query: search, group: group, equipment: equipment,
                                                     gymFilter: gymFilter)
            .filter { !recentIDs.contains($0.id) }
        if inlineBrowse != nil { return library }
        if !search.isEmpty { return ExerciseSelectionFilter.rankedMatches(library, query: search) }
        return library.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var visibleIDs: [String] { model.workout?.exerciseIDs ?? [] }

    public var body: some View {
        Group {
            if let inlineBrowse {
                inlineChooser(browse: inlineBrowse)
            } else if creating {
                CreateTrainingExercise(model: model, name: search, group: group ?? model.exercise?.group ?? .chest,
                    equipment: equipment ?? .other, back: { creating = false }, close: close)
            } else if reusing {
                TrainingWorkoutReusePicker(model: model, close: close, back: { reusing = false })
            } else if filtersExpanded {
                filterPanel
            } else {
                chooser
            }
        }
        .scrollIndicators(.never)
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
        .onChange(of: search) { _, _ in cancelPendingAdd() }
        .onChange(of: group) { _, _ in cancelPendingAdd() }
        .onChange(of: equipment) { _, _ in cancelPendingAdd() }
        .onChange(of: gymFilter) { _, _ in cancelPendingAdd() }
        .sheet(isPresented: $editingGym) {
            ExerciseGymFilterEditor(filter: $draft.gymFilter, resultCount: resultCount, onApply: applyFilters)
        }
        .onChange(of: model.canRetrySave) { _, _ in completePendingAdd() }
        .onChange(of: model.errorMessage) { _, _ in completePendingAdd() }
        .onChange(of: model.selectedDay) { _, _ in pendingAdd = nil }
        .onDisappear {
            // Inline tab navigation can already have replaced a failed add with a new save.
            if inlineBrowse == nil { cancelPendingAdd() }
        }
        #if os(macOS)
        .frame(minWidth: inlineBrowse == nil ? 320 : nil, idealWidth: inlineBrowse == nil ? 470 : nil,
               minHeight: inlineBrowse == nil ? 568 : nil, idealHeight: inlineBrowse == nil ? 740 : nil)
        #endif
    }

    private func inlineChooser(browse: @escaping (String, Bool) -> Void) -> some View {
        let recent = ExerciseSelectionFilter.results(in: recentSuggestions, query: search, group: nil, equipment: nil,
                                                    gymFilter: gymFilter)
        let suggestions = ExerciseSelectionFilter.inlineSuggestions(from: recent + libraryMatches(excluding: recent), query: search)
        let recovery = searchRecovery(alongside: Array(suggestions))
        let controls = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 8))
        return VStack(alignment: .leading, spacing: 4) {
            controls {
                searchField
                Button {
                    cancelPendingAdd()
                    searching = false
                    close()
                } label: {
                    Text("Cancel").font(.callout).fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityLabel("Cancel adding exercises")
                .accessibilityIdentifier("close-exercise-picker")
            }
            controls {
                Button {
                    cancelPendingAdd()
                    searching = false
                    browse(search, true)
                } label: {
                    Label("Select several", systemImage: "list.bullet")
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("inline-select-several")
                if !textSize.isAccessibilitySize { Spacer(minLength: 0) }
                Button {
                    cancelPendingAdd()
                    searching = false
                    browse(search, false)
                } label: {
                    Text(gymFilter.activeCount > 0 ? "Browse filtered exercises" : "Browse all exercises")
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("browse-all-exercises")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(NotebookStyle.clay)
            GymSetupSwitcher(onSwitch: { cancelPendingAdd(); searching = false }, onBrowseAll: {
                group = nil
                equipment = nil
            })
            if let recovery {
                ExerciseSearchRecoveryView(recovery: recovery, row: exerciseRow)
            }
            if suggestions.isEmpty && recovery == nil {
                Text(gymFilter.activeCount > 0
                     ? "No matches. Browse filtered exercises to change your filters."
                     : "No exercises found")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(suggestions) { exercise in
                        exerciseRow(exercise)
                        rule
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-inline-search")
        .task {
            recentSuggestions = model.recentExercises()
            await Task.yield()
            if !Task.isCancelled { searching = true }
        }
    }

    private func searchRecovery(alongside visible: [Exercise]) -> ExerciseSearchRecovery? {
        guard filterCount > 0, !search.isEmpty else { return nil }
        return ExerciseSearchRecovery.find(query: search, in: model.activeExercises, gymFilter: gymFilter, group: group,
                                           equipment: equipment, includePartialMatch: visible.isEmpty,
                                           excludingAlternatives: Set(visible.map(\.id)))
    }

    private var chooser: some View {
        let recent = self.recent
        let matches = libraryMatches(excluding: recent)
        let recovery = searchRecovery(alongside: recent + matches)
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if textSize.isAccessibilitySize {
                    pickerTitle
                    pickerTools
                }
                if let recovery { ExerciseSearchRecoveryView(recovery: recovery, row: exerciseRow) }
                if !recent.isEmpty { exerciseSection("Recent", exercises: recent) }
                if !matches.isEmpty { exerciseSection(recent.isEmpty ? "Exercises" : "All exercises", exercises: matches) }
                if recent.isEmpty && matches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if recovery == nil {
                            Text("No exercises found").font(.body.weight(.semibold)).accessibilityAddTraits(.isHeader)
                            Text(filterCount > 0 ? "Try another name or clear your filters." : "Try another name or create an exercise.")
                                .font(.callout).foregroundStyle(NotebookStyle.quiet)
                        }
                        if filterCount > 0 { clearFilters }
                        Button { openCreate() } label: {
                            Label("Create exercise", systemImage: "plus").frame(minHeight: 44)
                        }.foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("create-exercise-empty")
                    }.padding(.vertical, 12).accessibilityIdentifier("exercise-picker-empty")
                }
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, textSize.isAccessibilitySize ? 32 : 24)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively).accessibilityIdentifier("exercise-picker-scroll")
        .safeAreaInset(edge: .top, spacing: 0) { chooserHeader }
        .safeAreaInset(edge: .bottom, spacing: 0) { selectionFooter }
    }

    private var chooserHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 4) {
                if textSize.isAccessibilitySize { Spacer(minLength: 0) }
                else { pickerTitle }
                Menu {
                    Button {
                        cancelPendingAdd(); searching = false; selectingSeveral.toggle()
                        if !selectingSeveral { selectedIDs = [] }
                    } label: {
                        Label(selectingSeveral ? "Choose one at a time" : "Select several", systemImage: "checkmark.circle")
                    }.accessibilityIdentifier("picker-select-multiple")
                    if !visibleIDs.isEmpty {
                        Button {
                            cancelPendingAdd(); searching = false; model.dismissError(); reusing = true
                        } label: { Label("Use a previous workout", systemImage: "arrow.clockwise") }
                            .accessibilityIdentifier("reuse-workout")
                    }
                    Button { openCreate() } label: { Label("Create exercise", systemImage: "plus") }
                        .accessibilityIdentifier("create-exercise")
                } label: {
                    Image(systemName: "ellipsis").font(.body.weight(.semibold)).frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 44, height: 44)
                    .accessibilityLabel("More exercise options").accessibilityIdentifier("picker-more")
                Button { cancelPendingAdd(); model.dismissError(); close() } label: {
                    Image(systemName: "xmark").font(.body).frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Cancel adding exercises").accessibilityIdentifier("close-exercise-picker")
            }
            if !textSize.isAccessibilitySize { pickerTools }
        }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
            .frame(maxWidth: 560).frame(maxWidth: .infinity).background(NotebookStyle.ivory)
            .overlay(alignment: .bottom) { rule }
    }

    private var pickerTitle: some View {
        Text(selectingSeveral ? "Select exercises" : "Add exercise")
            .font(NotebookTypography.heading(24, relativeTo: .title2))
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    // Large headings, search and filters scroll together at Larger Text sizes.
    // Only the return controls stay fixed while the keyboard is open.
    private var pickerTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            if textSize.isAccessibilitySize {
                searchField
                filterButton
            } else {
                HStack(spacing: 8) { searchField; filterButton }
            }
            GymSetupSwitcher(onSwitch: { cancelPendingAdd(); searching = false }, onBrowseAll: {
                group = nil
                equipment = nil
            })
            if filterCount > 0 {
                TrainingFlowLayout(spacing: 8) {
                    if let group {
                        activeFilter(group.rawValue, label: "Remove \(group.rawValue) muscle-group filter", identifier: "remove-group-filter") {
                            self.group = nil
                        }
                    }
                    if let equipment {
                        activeFilter(equipment.rawValue, label: "Remove \(equipment.rawValue) equipment filter", identifier: "remove-equipment-filter") {
                            self.equipment = nil
                        }
                    }
                    if let gym = gymFilter.gym {
                        activeFilter(gym.label, label: "Remove \(gym.label) gym filter", identifier: "remove-gym-filter") {
                            gymFilter.gym = nil
                        }
                    }
                    if gymFilter.availableEquipment != nil {
                        activeFilter(gymFilter.equipmentSummary, label: "Remove available equipment filter, \(gymFilter.equipmentSummary)",
                                     identifier: "remove-available-equipment-filter") {
                            gymFilter.availableEquipment = nil
                        }
                    }
                }
            }
            if selectingSeveral {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Tap in workout order").font(.caption).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        cancelPendingAdd(); selectedIDs = []; selectingSeveral = false
                    } label: { Text("Choose one").font(.subheadline).frame(minHeight: 44) }
                        .foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("picker-end-multiple")
                }
            }
        }
    }

    private var searchField: some View {
        ExerciseSearchField(search: $search, focus: $searching,
            identifier: inlineBrowse == nil ? "exercise-search" : "picker-search", clearIdentifier: "picker-clear-search")
    }

    private var filterButton: some View {
        Button {
            cancelPendingAdd(); searching = false; draft = currentFilters; filtersExpanded = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease").accessibilityHidden(true)
                Text("Filters").font(.subheadline.weight(.medium))
                if filterCount > 0 { Text("\(filterCount)").font(.subheadline.weight(.semibold).monospacedDigit()) }
            }.frame(minWidth: 44, minHeight: 48).contentShape(Rectangle())
        }.foregroundStyle(filterCount > 0 ? NotebookStyle.clay : NotebookStyle.ink)
            .accessibilityLabel("Filters").accessibilityValue(filterCount == 0 ? "None applied" : "\(filterCount) applied")
            .accessibilityIdentifier("picker-filter-toggle")
    }

    private func activeFilter(_ title: String, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button { cancelPendingAdd(); action() } label: {
            HStack(spacing: 8) {
                Text(title).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "xmark").font(.caption)
            }.padding(.horizontal, 12).frame(minHeight: 44)
                .background(NotebookStyle.clay.opacity(0.07), in: NotebookStyle.squircle(11))
                .contentShape(NotebookStyle.squircle(11))
        }.foregroundStyle(NotebookStyle.clay).accessibilityLabel(label).accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var selectionFooter: some View {
        if selectingSeveral || model.errorMessage != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let error = model.errorMessage {
                    TrainingSaveError(model: model, message: error, retrySucceeded: completePendingAdd)
                }
                if selectingSeveral {
                    RecordButton(title: selectedIDs.isEmpty ? "Select exercises to add" : "Add \(selectedIDs.count) \(selectedIDs.count == 1 ? "exercise" : "exercises")") {
                        add(selectedIDs, several: true)
                    }.disabled(selectedIDs.isEmpty || pendingAdd != nil).accessibilityIdentifier("picker-add-selected")
                }
            }.padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background(NotebookStyle.ivory).overlay(alignment: .top) { rule }
        }
    }

    private var filterPanel: some View {
        let count = resultCount(draft.gymFilter)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Filters").font(NotebookTypography.heading(24, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                Button { editingGym = true } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Gym & available equipment").font(.body.weight(.semibold))
                            Text([draft.gymFilter.gym?.label ?? "Any gym", draft.gymFilter.equipmentSummary].joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        }.fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(NotebookStyle.clay)
                    }
                    .padding(.bottom, 10).frame(minHeight: 44).contentShape(Rectangle())
                }.overlay(alignment: .bottom) { rule }.accessibilityIdentifier("picker-gym-equipment")
                filterChoices("Muscle group") {
                    chip("All", selected: draft.group == nil) { draft.group = nil }.accessibilityIdentifier("group-All")
                    ForEach(MuscleGroup.allCases, id: \.self) { item in
                        chip(item.rawValue, selected: item == draft.group) { draft.group = item }.accessibilityIdentifier("group-\(item.rawValue)")
                    }
                }
                filterChoices("Main equipment") {
                    chip("All", selected: draft.equipment == nil) { draft.equipment = nil }.accessibilityIdentifier("equipment-All")
                    ForEach(ExerciseEquipment.allCases, id: \.self) { item in
                        chip(item.rawValue, selected: item == draft.equipment) { draft.equipment = item }.accessibilityIdentifier("equipment-\(item.rawValue)")
                    }
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("exercise-filters-scroll")
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 12) {
                    Button { filtersExpanded = false } label: {
                        Text("Cancel").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }.accessibilityIdentifier("picker-filter-cancel")
                    Spacer(minLength: 0)
                    Button { draft = FilterDraft() } label: {
                        Text("Clear filters").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }.disabled(draft.count == 0).accessibilityIdentifier("clear-exercise-filters")
                }.font(.callout).foregroundStyle(NotebookStyle.clay)
                    .padding(.horizontal, 24).padding(.vertical, 4).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory).overlay(alignment: .bottom) { rule }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RecordButton(title: "Show \(count) \(count == 1 ? "exercise" : "exercises")", action: applyFilters)
                    .accessibilityIdentifier("picker-show-results")
                    .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory).overlay(alignment: .top) { rule }
            }
    }

    private func resultCount(_ gym: ExerciseGymFilter) -> Int {
        ExerciseSelectionFilter.results(in: model.activeExercises, query: search, group: draft.group,
                                        equipment: draft.equipment, gymFilter: gym).count
    }

    private func applyFilters() {
        group = draft.group
        equipment = draft.equipment
        gymFilter = draft.gymFilter
        filtersExpanded = false
    }

    private func filterChoices<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.body.weight(.semibold)).accessibilityAddTraits(.isHeader)
            TrainingFlowLayout(spacing: 8) { content() }
        }
    }

    private var rule: some View { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true) }

    private func openCreate() {
        cancelPendingAdd(); searching = false; model.dismissError(); creating = true
    }

    private var clearFilters: some View {
        Button {
            cancelPendingAdd(); group = nil; equipment = nil; gymFilter = ExerciseGymFilter()
        } label: { Text("Clear filters").font(.callout).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
            .foregroundStyle(NotebookStyle.clay).accessibilityHint("Keep your search and reset all exercise filters")
            .accessibilityIdentifier("clear-exercise-filters")
    }

    private func exerciseSection(_ title: String, exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(NotebookTypography.heading(20, relativeTo: .title3)).accessibilityAddTraits(.isHeader)
            LazyVStack(spacing: 0) {
                Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                ForEach(exercises) { exercise in
                    exerciseRow(exercise)
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let added = visibleIDs.contains(exercise.id)
        let isCustom = model.snapshot.customExercises?.contains { $0.id == exercise.id } == true
        var muscles = exercise.matchingMuscleTags(query: search)
        if muscles.isEmpty, let group, group != exercise.group {
            muscles = exercise.taggedMuscles.filter { $0.group == group }
        }
        let classification = muscles.isEmpty ? exercise.group.rawValue : muscles.map(\.name).joined(separator: ", ")
        let details = "\(classification) · \(exercise.equipmentLabel)"
        let current = inlineBrowse != nil && model.exercise?.id == exercise.id
        let position = selectedIDs.firstIndex(of: exercise.id)
        let pending = pendingAdd?.ids.contains(exercise.id) == true
        var accessibilityDetails = [exercise.name, exercise.group.rawValue, exercise.equipmentLabel]
        if !muscles.isEmpty { accessibilityDetails.append(classification) }
        if isCustom { accessibilityDetails.append("custom exercise") }
        if added { accessibilityDetails.append("added") }
        else if let position { accessibilityDetails.append("selected \(position + 1)") }
        if pending { accessibilityDetails.append("not saved yet") }
        return Button {
            if selectingSeveral {
                cancelPendingAdd()
                if let position { selectedIDs.remove(at: position) }
                else if !added { selectedIDs.append(exercise.id) }
            } else if pending {
                if model.canRetrySave, model.retrySave() { completePendingAdd() }
            } else { add([exercise.id], several: false) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if position != nil { Image(systemName: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(NotebookStyle.clay) }
                        Text(exercise.name).font(.body.weight(current || position != nil ? .semibold : .regular))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(isCustom ? "Custom · \(details)" : details)
                        .font(.caption).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
                    if pending && !selectingSeveral {
                        Text("Not saved yet").font(.caption).foregroundStyle(NotebookStyle.clay)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if added { Label("Added", systemImage: "checkmark").font(.caption).foregroundStyle(NotebookStyle.clay) }
                else if selectingSeveral {
                    if let position {
                        Text("\(position + 1)").font(.subheadline.monospacedDigit().weight(.semibold))
                            .frame(width: selectionBadgeSize, height: selectionBadgeSize).foregroundStyle(NotebookStyle.onPrimary)
                            .background(NotebookStyle.primaryFill, in: NotebookStyle.squircle(selectionBadgeSize * 0.26))
                    } else {
                        NotebookStyle.squircle(selectionBadgeSize * 0.26)
                            .strokeBorder(NotebookStyle.quiet, lineWidth: 1)
                            .frame(width: selectionBadgeSize, height: selectionBadgeSize)
                    }
                } else { Image(systemName: pending ? "clock" : "plus").foregroundStyle(NotebookStyle.clay) }
            }.padding(.vertical, 10).frame(minHeight: 56).contentShape(Rectangle())
        }
        .disabled(selectingSeveral && added)
        .accessibilityLabel(accessibilityDetails.joined(separator: ", "))
        .accessibilityAddTraits(current || position != nil || pending ? .isSelected : [])
        .accessibilityIdentifier("picker-\(exercise.id)")
    }

    private func add(_ ids: [String], several: Bool) {
        cancelPendingAdd()
        guard !ids.isEmpty, let day = model.selectedDay else { return }
        let selection = several ? ids.first(where: { !visibleIDs.contains($0) }) ?? model.exercise?.id : ids.first
        pendingAdd = PendingAdd(day: day, ids: ids, selectedID: selection)
        let saved: Bool
        if several {
            saved = model.addExercises(ids)
        } else if inlineBrowse != nil && visibleIDs.contains(ids[0]) {
            saved = model.selectExercise(ids[0])
        } else {
            saved = model.addExercise(ids[0])
        }
        if saved { completePendingAdd() }
        else if !model.canRetrySave { pendingAdd = nil }
    }
    private func completePendingAdd() {
        guard let request = pendingAdd, model.selectedDay == request.day, model.errorMessage == nil, !model.canRetrySave,
              request.ids.allSatisfy({ visibleIDs.contains($0) }), model.exercise?.id == request.selectedID else { return }
        pendingAdd = nil; close()
    }
    private func cancelPendingAdd() {
        guard pendingAdd != nil else { return }
        pendingAdd = nil
        _ = model.cancelPendingAction()
    }
    private func chip(_ name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected { Image(systemName: "checkmark").font(.caption.weight(.semibold)) }
                Text(name).font(.subheadline.weight(selected ? .semibold : .regular)).fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 12).padding(.vertical, 4).frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(selected ? NotebookStyle.ivory : NotebookStyle.ink)
                .background(selected ? NotebookStyle.clay : .clear, in: NotebookStyle.squircle(7))
                .overlay { NotebookStyle.squircle(7).stroke(selected ? .clear : NotebookStyle.rule, lineWidth: 0.7) }
        }.accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct CreateTrainingExercise: View {
    @Bindable var model: TrainingNotebookModel
    @State var name: String
    @State var group: MuscleGroup
    @State var equipment: ExerciseEquipment
    @State private var setup = CustomExerciseSetup()
    @State private var muscleTags: [MuscleRegion] = []
    let back: () -> Void
    let close: () -> Void
    @State private var pendingDay: TrainingDay?
    @FocusState private var typing: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Create exercise").font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                TextField("Exercise name", text: $name).textFieldStyle(.plain).font(NotebookTypography.heading(26, relativeTo: .title2)).focused($typing)
                    .padding(.vertical, 12).overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
                    .accessibilityIdentifier("custom-name")
                Picker("Muscle group", selection: $group) { ForEach(MuscleGroup.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                    .frame(minHeight: 44).accessibilityIdentifier("custom-group")
                CustomExerciseMusclePicker(selection: $muscleTags, mainGroup: group, onOpen: { typing = false })
                Picker("Main equipment", selection: $equipment) { ForEach(ExerciseEquipment.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                    .frame(minHeight: 44).accessibilityIdentifier("custom-equipment")
                CustomExerciseSetupButton(setup: $setup, onOpen: { typing = false })
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("custom-exercise-scroll")
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { cancelPending(); model.dismissError(); back() } label: {
                    Label("Exercises", systemImage: "chevron.left").frame(minHeight: 44)
                }.accessibilityIdentifier("custom-back")
                Spacer(minLength: 0)
            }.padding(.horizontal, 24).padding(.vertical, 4).frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background(NotebookStyle.ivory)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                if let error = model.errorMessage { TrainingSaveError(model: model, message: error, retrySucceeded: completePending) }
            RecordButton(title: "Add exercise") {
                cancelPending(); pendingDay = model.selectedDay
                if model.createExercise(named: name, group: group, equipment: equipment, customSetup: setup, customMuscleTags: muscleTags) { completePending() }
                else if !model.canRetrySave { pendingDay = nil }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingDay != nil)
                .accessibilityIdentifier("save-custom-exercise")
            }.padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background(NotebookStyle.ivory)
        }
        .background(NotebookStyle.ivory).task { typing = true }
        .onChange(of: name) { _, _ in cancelPending() }
        .onChange(of: group) { _, _ in cancelPending() }
        .onChange(of: equipment) { _, _ in cancelPending() }
        .onChange(of: muscleTags) { _, _ in cancelPending() }
        .onChange(of: setup) { _, _ in cancelPending() }
        .onChange(of: model.canRetrySave) { _, _ in completePending() }
        .onChange(of: model.errorMessage) { _, _ in completePending() }
        .onDisappear { cancelPending() }
    }
    private func completePending() {
        guard let day = pendingDay, model.selectedDay == day, model.errorMessage == nil, !model.canRetrySave,
              let exercise = model.exercise, ExerciseLibrary.searchKey(exercise.name) == ExerciseLibrary.searchKey(name),
              exercise.group == group, exercise.equipmentType == equipment, exercise.customSetup == setup, exercise.customMuscleTags == muscleTags else { return }
        pendingDay = nil; close()
    }
    private func cancelPending() {
        guard pendingDay != nil else { return }
        pendingDay = nil; _ = model.cancelPendingAction()
    }
}

private struct TrainingFlowLayout: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(proposal.width ?? 393, subviews).0
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrangement(bounds.width, subviews).1
        for (index, frame) in frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }
    private func arrangement(_ width: CGFloat, _ subviews: Subviews) -> (CGSize, [CGRect]) {
        var x: CGFloat = 0, y: CGFloat = 0, height: CGFloat = 0
        var frames: [CGRect] = []
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let size = view.sizeThatFits(ProposedViewSize(width: min(ideal.width, width), height: nil))
            if x > 0 && x + size.width > width { x = 0; y += height + spacing; height = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing; height = max(height, size.height)
        }
        return (CGSize(width: width, height: y + height), frames)
    }
}
