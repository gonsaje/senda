import SwiftUI
import SendaDomain

extension ExerciseGymFilter {
    var activeCount: Int {
        (gym == nil ? 0 : 1) + (availableEquipment == nil ? 0 : 1)
    }

    var equipmentSummary: String {
        guard let availableEquipment else { return "Any equipment" }
        if availableEquipment.isEmpty { return "No equipment" }
        if availableEquipment.count == 1, let item = availableEquipment.first { return item.label }
        return "\(availableEquipment.count) equipment items"
    }
}

/// Edits a working copy. Only showing the results commits the gym and inventory.
@_spi(Preview) public struct ExerciseGymFilterEditor: View {
    @Binding private var filter: ExerciseGymFilter
    @State private var draft: ExerciseGymFilter
    @State private var query = ""
    @StoredGymSetups private var saved
    @State private var editingID: UUID?
    @State private var setupName = ""
    @State private var initialized = false
    @State private var removed: Set<UUID> = []
    @State private var naming = false
    @State private var creating = false
    @State private var proposedName = ""
    @State private var confirmingRemoval = false
    @State private var saveError: String?
    @Environment(\.dismiss) private var dismiss
    private let resultCount: (ExerciseGymFilter) -> Int
    private let onApply: () -> Void

    public init(filter: Binding<ExerciseGymFilter>, resultCount: @escaping (ExerciseGymFilter) -> Int,
                onApply: @escaping () -> Void = {}) {
        _filter = filter
        _draft = State(initialValue: filter.wrappedValue)
        self.resultCount = resultCount
        self.onApply = onApply
    }

    public var body: some View {
        let count = resultCount(draft)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { title; Spacer(minLength: 0); setupMenu }
                    VStack(alignment: .leading, spacing: 0) { title; setupMenu }
                }
                gymMenu
                GymEquipmentChecklist(use: .available, selection: $draft.availableEquipment, query: $query)
            }
            .frame(maxWidth: 512, alignment: .leading).padding(.horizontal, 24).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("gym-filter-scroll")
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("Cancel").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }.accessibilityIdentifier("gym-filter-cancel")
                Spacer(minLength: 0)
                Button { browseAll() } label: {
                    Text("Clear").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }.disabled(draft.activeCount == 0 && query.isEmpty && setupName.isEmpty)
                .accessibilityLabel("Clear gym and equipment filters").accessibilityIdentifier("gym-filter-clear")
            }
            .font(.callout).foregroundStyle(NotebookStyle.clay)
            .frame(maxWidth: 512).padding(.horizontal, 24).frame(maxWidth: .infinity)
            .background(NotebookStyle.ivory).overlay(alignment: .bottom) { rule }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                if let saveError {
                    Text(saveError).font(.callout).foregroundStyle(NotebookStyle.clay)
                        .fixedSize(horizontal: false, vertical: true)
                }
                RecordButton(title: "Show \(count) \(count == 1 ? "exercise" : "exercises")", action: apply)
                    .accessibilityIdentifier("gym-filter-apply")
            }
            .frame(maxWidth: 512).padding(.horizontal, 24).padding(.vertical, 10)
            .frame(maxWidth: .infinity).background(NotebookStyle.ivory).overlay(alignment: .top) { rule }
        }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            if let selected = saved.selected, selected.filter == draft {
                editingID = selected.id
                setupName = selected.name
            }
        }
        .alert(creating ? "New gym setup" : "Rename gym setup", isPresented: $naming) {
            TextField("Setup name", text: $proposedName).accessibilityIdentifier("gym-setup-name")
            Button("Cancel", role: .cancel) {}
            Button("Done") {
                if creating {
                    if editingID != nil || !setupName.isEmpty { draft = .init() }
                    editingID = nil
                    query = ""
                }
                setupName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
                saveError = nil
            }
            .disabled(!remainingSetups.allowsName(proposedName, editing: creating ? nil : editingID))
            .accessibilityIdentifier("gym-setup-confirm-name")
        } message: {
            Text("Use a name like Garage or Travel.")
        }
        .confirmationDialog("Remove \(setupName)?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button("Remove setup", role: .destructive) {
                if let editingID { removed.insert(editingID) }
                browseAll()
            }
            Button("Cancel", role: .cancel) {}
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .buttonStyle(.plain).tint(NotebookStyle.clay)
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 470, minHeight: 400, idealHeight: 640)
        #endif
    }

    private var title: some View {
        Text("Gym & equipment").font(NotebookTypography.heading(26, relativeTo: .title2))
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }

    private var remainingSetups: SavedGymSetups {
        var result = saved
        for id in removed { result.remove(id) }
        return result
    }

    private var setupMenu: some View {
        Menu {
            Button {
                proposedName = ""
                creating = true
                naming = true
            } label: { Label("New setup", systemImage: "plus") }
            .accessibilityIdentifier("gym-setup-new")
            if !setupName.isEmpty {
                Button {
                    proposedName = setupName
                    creating = false
                    naming = true
                } label: { Label("Rename setup", systemImage: "pencil") }
                .accessibilityIdentifier("gym-setup-rename")
                if editingID != nil {
                    Button(role: .destructive) { confirmingRemoval = true } label: {
                        Label("Remove setup", systemImage: "trash")
                    }.accessibilityIdentifier("gym-setup-remove")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(setupName.isEmpty ? "Setups" : "Editing \(setupName)")
                    .font(.subheadline.weight(.medium)).lineLimit(2)
                Image(systemName: "chevron.down").font(.caption2).accessibilityHidden(true)
            }
            .padding(.horizontal, 2)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }
        .fixedSize(horizontal: false, vertical: true)
        .menuStyle(.borderlessButton).menuIndicator(.hidden).foregroundStyle(NotebookStyle.clay)
        .accessibilityLabel("Gym setup options")
        .accessibilityValue(setupName)
        .accessibilityIdentifier("gym-setup-actions")
    }

    private func browseAll() {
        draft = .init()
        editingID = nil
        setupName = ""
        query = ""
        saveError = nil
    }

    private func apply() {
        var next = remainingSetups
        if editingID != nil || !setupName.isEmpty || draft != .init() {
            guard next.save(draft, named: setupName, editing: editingID) else {
                saveError = "This setup changed. Choose a new name to save it."
                return
            }
        } else {
            next.select(nil)
        }
        // The workout picker applies its other staged filters through onApply. Commit the
        // saved identity last so an unrestricted named setup stays selected after that write.
        filter = draft
        onApply()
        saved = next
        dismiss()
    }

    private var gymMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Gym").font(.headline).accessibilityAddTraits(.isHeader)
            Menu {
                gymChoice(nil)
                ForEach(ExerciseGym.allCases, id: \.self) { gym in gymChoice(gym) }
            } label: {
                HStack(spacing: 8) {
                    if draft.gym != nil {
                        Image(systemName: "checkmark").font(.caption.weight(.semibold)).accessibilityHidden(true)
                    }
                    Text(draft.gym?.label ?? "Any gym").font(.body.weight(draft.gym == nil ? .regular : .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    #if os(iOS)
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                        .accessibilityHidden(true)
                    #endif
                }
                .foregroundStyle(NotebookStyle.clay)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            #if os(iOS)
            .menuIndicator(.hidden)
            #else
            .menuIndicator(.visible)
            #endif
            .accessibilityLabel("Gym").accessibilityValue(draft.gym?.label ?? "Any gym")
            .accessibilityIdentifier("gym-filter-menu")
        }
        .frame(maxWidth: .infinity, alignment: .leading).overlay(alignment: .bottom) { rule }
    }

    private func gymChoice(_ gym: ExerciseGym?) -> some View {
        let name = gym?.label ?? "Any gym"
        return Button { draft.gym = gym } label: {
            if draft.gym == gym { Label(name, systemImage: "checkmark") }
            else { Text(name) }
        }
        .accessibilityAddTraits(draft.gym == gym ? .isSelected : [])
        .accessibilityIdentifier("gym-filter-option-\(gym?.label ?? "any")")
    }

    private var rule: some View {
        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
    }
}

struct GymEquipmentChecklist: View {
    enum Use { case available, required }

    let use: Use
    @Binding var selection: Set<GymEquipmentItem>?
    @Binding var query: String
    @FocusState private var searching: Bool

    private var prefix: String {
        use == .available ? "gym-gear" : "custom-setup-gear"
    }

    var body: some View {
        let key = ExerciseLibrary.matchingKey(query)
        let items = GymEquipmentItem.allCases.filter { $0.matchesSearch(key: key) }
        let sections = items.reduce(into: [String]()) { sections, item in
            if !sections.contains(item.section) { sections.append(item.section) }
        }
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(use == .available ? "Available equipment" : "Required equipment").font(.headline).accessibilityAddTraits(.isHeader)
                Text(use == .available ? "Choose what you have. Exercises that need no equipment are included." : "Select every item this exercise needs.")
                    .font(.callout).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                equipmentSearch
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                if key.isEmpty {
                    GymSetupChoice(use == .available ? "Any equipment" : "Unspecified", selected: selection == nil,
                                   id: use == .available ? "gym-gear-any" : "custom-setup-gear-unspecified") {
                        selection = nil
                    }
                    GymSetupChoice("No equipment", selected: selection?.isEmpty == true, id: "\(prefix)-none") {
                        selection = []
                    }
                }
                if items.isEmpty {
                    Text("No equipment found").font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Button { query = "" } label: {
                        Text("Clear search").frame(minHeight: 44).contentShape(Rectangle())
                    }.foregroundStyle(NotebookStyle.clay)
                }
                ForEach(sections, id: \.self) { section in
                    Text(section).font(.subheadline.weight(.semibold))
                        .foregroundStyle(NotebookStyle.quiet).padding(.top, key.isEmpty ? 20 : 8)
                        .padding(.bottom, 4).accessibilityAddTraits(.isHeader)
                    ForEach(items.filter { $0.section == section }, id: \.self) { item in
                        GymSetupChoice(item.label, selected: selection?.contains(item) == true,
                                       id: "\(prefix)-\(item.label)") {
                            var equipment = selection ?? []
                            if equipment.contains(item) { equipment.remove(item) }
                            else { equipment.insert(item) }
                            selection = equipment.isEmpty && use == .required ? nil : equipment
                        }
                    }
                }
            }
        }
    }

    private var equipmentSearch: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            TextField("Find equipment", text: $query)
                .textFieldStyle(.plain).autocorrectionDisabled().focused($searching)
                .submitLabel(.search).onSubmit { searching = false }
                .accessibilityLabel("Find equipment").accessibilityIdentifier("\(prefix)-search")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(NotebookStyle.quiet)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Clear equipment search")
            }
        }
        .padding(.leading, 12).padding(.trailing, query.isEmpty ? 12 : 0).frame(minHeight: 48)
        .overlay { RoundedRectangle(cornerRadius: 7).stroke(NotebookStyle.rule) }
    }
}

struct GymSetupChoice: View {
    let title: String
    let selected: Bool
    let id: String
    let action: () -> Void

    init(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) {
        self.title = title
        self.selected = selected
        self.id = id
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.body.weight(selected ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark").font(.body.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.xLarge).foregroundStyle(NotebookStyle.clay)
                    .opacity(selected ? 1 : 0).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44).padding(.vertical, 2).contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier(id)
        .overlay(alignment: .bottom) {
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true).allowsHitTesting(false)
        }
    }
}
