import SwiftUI
import SendaDomain

extension CustomExerciseSetup {
    var summary: String {
        let gymNames = ExerciseGym.allCases.filter(gyms.contains).map(\.label)
        var parts = [String]()
        if !gymNames.isEmpty {
            parts.append(gymNames.count > 2 ? "\(gymNames.count) gym types" : gymNames.joined(separator: ", "))
        }
        if let requiredEquipment {
            let items = GymEquipmentItem.allCases.filter(requiredEquipment.contains).map(\.label)
            switch items.count {
            case 0: parts.append("No equipment")
            case 1, 2: parts.append(items.joined(separator: ", "))
            default: parts.append("\(items.count) equipment items")
            }
        }
        return parts.isEmpty ? "Unspecified" : parts.joined(separator: " · ")
    }
}

struct CustomExerciseSetupButton: View {
    @Binding var setup: CustomExerciseSetup
    var onOpen: () -> Void = {}
    @State private var editing = false

    var body: some View {
        Button {
            onOpen()
            editing = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Gym & equipment").font(.body.weight(.medium))
                    Text(setup.summary).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(NotebookStyle.clay).accessibilityHidden(true)
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gym and equipment").accessibilityValue(setup.summary)
        .accessibilityIdentifier("custom-setup-open")
        .sheet(isPresented: $editing) {
            CustomExerciseSetupEditor(setup: setup, saveTitle: "Done") { draft in
                setup = draft
                return true
            }
        }
    }
}

struct CustomExerciseSetupEditor: View {
    @State private var draft: CustomExerciseSetup
    @State private var query = ""
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss

    private let saveTitle: String
    private let saveError: () -> String?
    private let onCancelPending: () -> Void
    private let onSave: (CustomExerciseSetup) -> Bool

    init(setup: CustomExerciseSetup, saveTitle: String = "Save",
         saveError: @escaping () -> String? = { nil }, onCancelPending: @escaping () -> Void = {},
         onSave: @escaping (CustomExerciseSetup) -> Bool) {
        _draft = State(initialValue: setup)
        self.saveTitle = saveTitle
        self.saveError = saveError
        self.onCancelPending = onCancelPending
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Gym & equipment").font(NotebookTypography.heading(26, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Gym types").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Choose each gym where you can do this exercise.")
                        .font(.callout).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 4).padding(.bottom, 8)
                    ForEach(ExerciseGym.allCases, id: \.self) { gym in
                        GymSetupChoice(gym.label, selected: draft.gyms.contains(gym),
                                       id: "custom-setup-gym-\(gym.rawValue)") {
                            if draft.gyms.contains(gym) { draft.gyms.remove(gym) }
                            else { draft.gyms.insert(gym) }
                        }
                    }
                }
                GymEquipmentChecklist(use: .required, selection: $draft.requiredEquipment, query: $query)
            }
            .frame(maxWidth: 512, alignment: .leading).padding(.horizontal, 24).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("custom-setup-scroll")
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Text("Cancel").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .font(.callout).foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("custom-setup-cancel")
                Spacer()
            }
            .frame(maxWidth: 512).padding(.horizontal, 24).frame(maxWidth: .infinity)
            .background(NotebookStyle.ivory).overlay(alignment: .bottom) { rule }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                if let failure {
                    Text(failure).font(.callout).foregroundStyle(NotebookStyle.clay)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("custom-setup-error")
                }
                RecordButton(title: failure == nil ? saveTitle : "Try again", action: save)
                    .accessibilityIdentifier("custom-setup-save")
            }
            .frame(maxWidth: 512).padding(.horizontal, 24).padding(.vertical, 10)
            .frame(maxWidth: .infinity).background(NotebookStyle.ivory).overlay(alignment: .top) { rule }
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .buttonStyle(.plain).tint(NotebookStyle.clay)
        .onChange(of: draft) { _, _ in discardFailedSave() }
        .onDisappear { discardFailedSave() }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 470, minHeight: 400, idealHeight: 640)
        #endif
    }

    private var rule: some View {
        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
    }

    private func save() {
        discardFailedSave()
        if onSave(draft) {
            dismiss()
        } else {
            let message = saveError() ?? "Couldn’t save the gym and equipment."
            failure = message
            TrainingAccessibility.announce(message)
        }
    }

    private func discardFailedSave() {
        guard failure != nil else { return }
        onCancelPending()
        failure = nil
    }
}
