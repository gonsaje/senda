import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingExercisePicker: View {
    @Bindable private var model: TrainingNotebookModel
    private let close: () -> Void
    @State private var search = ""
    @State private var group: MuscleGroup?
    @State private var equipment: ExerciseEquipment?
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

    public init(model: TrainingNotebookModel, close: @escaping () -> Void) {
        self.model = model; self.close = close
    }

    /// Seeds otherwise local presentation state for deterministic native preview captures.
    @_spi(Preview) public init(model: TrainingNotebookModel, search: String, group: MuscleGroup? = nil,
        equipment: ExerciseEquipment? = nil, showsFilters: Bool = false, selectedIDs: [String]? = nil,
        close: @escaping () -> Void) {
        self.model = model; self.close = close
        _search = State(initialValue: search); _group = State(initialValue: group)
        _equipment = State(initialValue: equipment); _filtersExpanded = State(initialValue: showsFilters)
        _selectingSeveral = State(initialValue: selectedIDs != nil)
        _selectedIDs = State(initialValue: selectedIDs ?? [])
    }

    private var filterCount: Int { (group == nil ? 0 : 1) + (equipment == nil ? 0 : 1) }
    private var resultCount: Int { recent.count + matches.count }

    private var recent: [Exercise] {
        ExerciseSelectionFilter.results(in: model.recentExercises(), query: search, group: group, equipment: equipment)
    }
    private var matches: [Exercise] {
        let recentIDs = Set(recent.map(\.id))
        return ExerciseSelectionFilter.results(in: model.exercises, query: search, group: group, equipment: equipment)
            .filter { !recentIDs.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var visibleIDs: [String] { model.workout?.exerciseIDs ?? [] }

    public var body: some View {
        Group {
            if creating {
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
        .onChange(of: model.canRetrySave) { _, _ in completePendingAdd() }
        .onChange(of: model.errorMessage) { _, _ in completePendingAdd() }
        .onChange(of: model.selectedDay) { _, _ in pendingAdd = nil }
        .onDisappear { cancelPendingAdd() }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 470, minHeight: 568, idealHeight: 740)
        #endif
    }

    private var chooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if textSize.isAccessibilitySize {
                    pickerTitle
                    pickerTools
                }
                if !recent.isEmpty { exerciseSection("Recent", exercises: recent) }
                if !matches.isEmpty { exerciseSection(recent.isEmpty ? "Exercises" : "All exercises", exercises: matches) }
                if resultCount == 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No exercises found").font(.body.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        Text(filterCount > 0 ? "Try another name or clear your filters." : "Try another name or create an exercise.")
                            .font(.callout).foregroundStyle(NotebookStyle.quiet)
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            TextField("Find an exercise", text: $search).textFieldStyle(.plain).autocorrectionDisabled()
                .focused($searching).submitLabel(.search).onSubmit { searching = false }
                .accessibilityLabel("Find an exercise").accessibilityIdentifier("exercise-search")
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(NotebookStyle.quiet)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Clear search").accessibilityIdentifier("picker-clear-search")
            }
        }.padding(.leading, 12).padding(.trailing, search.isEmpty ? 12 : 0).frame(minHeight: 48)
            .overlay { RoundedRectangle(cornerRadius: 7).stroke(NotebookStyle.rule, lineWidth: 1) }
    }

    private var filterButton: some View {
        Button {
            cancelPendingAdd(); searching = false; filtersExpanded = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                if textSize.isAccessibilitySize { Text("Filters") }
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
                .background(NotebookStyle.clay.opacity(0.07), in: Capsule())
                .contentShape(Capsule())
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                filterChoices("Muscle group") {
                    chip("All", selected: group == nil) { group = nil }.accessibilityIdentifier("group-All")
                    ForEach(MuscleGroup.allCases, id: \.self) { item in
                        chip(item.rawValue, selected: item == group) { group = item }.accessibilityIdentifier("group-\(item.rawValue)")
                    }
                }
                filterChoices("Equipment") {
                    chip("All", selected: equipment == nil) { equipment = nil }.accessibilityIdentifier("equipment-All")
                    ForEach(ExerciseEquipment.allCases, id: \.self) { item in
                        chip(item.rawValue, selected: item == equipment) { equipment = item }.accessibilityIdentifier("equipment-\(item.rawValue)")
                    }
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("exercise-filters-scroll")
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Text("Filters").font(NotebookTypography.heading(24, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    clearFilters.disabled(filterCount == 0)
                }.padding(.horizontal, 24).padding(.vertical, 8).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory).overlay(alignment: .bottom) { rule }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RecordButton(title: resultCount == 0 ? "Show results" : "Show \(resultCount) \(resultCount == 1 ? "exercise" : "exercises")") {
                    filtersExpanded = false
                }.accessibilityIdentifier("picker-show-results")
                    .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory).overlay(alignment: .top) { rule }
            }
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
            cancelPendingAdd(); group = nil; equipment = nil
        } label: { Text("Clear filters").font(.callout).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
            .foregroundStyle(NotebookStyle.clay).accessibilityHint("Keep your search and show all muscle groups and equipment")
            .accessibilityIdentifier("clear-exercise-filters")
    }

    private func exerciseSection(_ title: String, exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(NotebookTypography.heading(20, relativeTo: .title3)).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
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
        let position = selectedIDs.firstIndex(of: exercise.id)
        let pending = pendingAdd?.ids.contains(exercise.id) == true
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
                        Text(exercise.name).font(.body.weight(position == nil ? .regular : .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("\(exercise.group.rawValue) · \(exercise.equipmentType.rawValue)")
                        .font(.caption).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
                    if pending && !selectingSeveral {
                        Text("Not saved yet").font(.caption).foregroundStyle(NotebookStyle.clay)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if added { Label("Added", systemImage: "checkmark").font(.caption).foregroundStyle(NotebookStyle.clay) }
                else if selectingSeveral {
                    if let position {
                        Text("\(position + 1)").font(.subheadline.monospacedDigit().weight(.semibold))
                            .frame(width: selectionBadgeSize, height: selectionBadgeSize).foregroundStyle(NotebookStyle.ivory)
                            .background(NotebookStyle.clay, in: Circle())
                    } else { Image(systemName: "circle").foregroundStyle(NotebookStyle.quiet) }
                } else { Image(systemName: pending ? "clock" : "plus").foregroundStyle(NotebookStyle.clay) }
            }.padding(.vertical, 10).frame(minHeight: 56).contentShape(Rectangle())
        }
        .disabled(selectingSeveral && added)
        .accessibilityLabel("\(exercise.name), \(exercise.group.rawValue), \(exercise.equipmentType.rawValue)" + (added ? ", added" : position.map { ", selected \($0 + 1)" } ?? "") + (pending ? ", not saved yet" : ""))
        .accessibilityAddTraits(position == nil && !pending ? [] : .isSelected)
        .accessibilityIdentifier("picker-\(exercise.id)")
    }

    private func add(_ ids: [String], several: Bool) {
        cancelPendingAdd()
        guard !ids.isEmpty, let day = model.selectedDay else { return }
        let selection = several ? ids.first(where: { !visibleIDs.contains($0) }) ?? model.exercise?.id : ids.first
        pendingAdd = PendingAdd(day: day, ids: ids, selectedID: selection)
        let saved = several ? model.addExercises(ids) : model.addExercise(ids[0])
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
                .background(selected ? NotebookStyle.clay : .clear, in: RoundedRectangle(cornerRadius: 7))
                .overlay { RoundedRectangle(cornerRadius: 7).stroke(selected ? .clear : NotebookStyle.rule, lineWidth: 0.7) }
        }.accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct CreateTrainingExercise: View {
    @Bindable var model: TrainingNotebookModel
    @State var name: String
    @State var group: MuscleGroup
    @State var equipment: ExerciseEquipment
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
                Picker("Equipment", selection: $equipment) { ForEach(ExerciseEquipment.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                    .frame(minHeight: 44).accessibilityIdentifier("custom-equipment")
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
                if model.createExercise(named: name, group: group, equipment: equipment) { completePending() }
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
        .onChange(of: model.canRetrySave) { _, _ in completePending() }
        .onChange(of: model.errorMessage) { _, _ in completePending() }
        .onDisappear { cancelPending() }
    }
    private func completePending() {
        guard let day = pendingDay, model.selectedDay == day, model.errorMessage == nil, !model.canRetrySave,
              let exercise = model.exercise, ExerciseLibrary.searchKey(exercise.name) == ExerciseLibrary.searchKey(name),
              exercise.group == group, exercise.equipmentType == equipment else { return }
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
