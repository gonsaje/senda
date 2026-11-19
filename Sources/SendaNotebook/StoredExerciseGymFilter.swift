import SwiftUI
import SendaDomain

@propertyWrapper struct StoredGymSetups: DynamicProperty {
    @AppStorage("senda.gymSetups") private var data = Data()
    @AppStorage("senda.exerciseGymFilter") private var legacy = Data()

    var wrappedValue: SavedGymSetups {
        get { SavedGymSetups(data: data, legacy: legacy) }
        nonmutating set {
            if let encoded = try? JSONEncoder().encode(newValue) { data = encoded }
        }
    }
}

@propertyWrapper struct StoredExerciseGymFilter: DynamicProperty {
    @StoredGymSetups private var setups

    var wrappedValue: ExerciseGymFilter {
        get { setups.filter }
        nonmutating set { setups.applyTemporary(newValue) }
    }

    var projectedValue: Binding<ExerciseGymFilter> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}

/// Place alongside the library search so changing location takes a single tap.
struct GymSetupSwitcher: View {
    @StoredGymSetups private var saved
    var onSwitch: () -> Void = {}
    var onBrowseAll: () -> Void = {}

    var body: some View {
        let state = saved
        if !state.setups.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    choice("Browse all", selected: state.selectedID == nil && state.filter == .init(),
                           id: "gym-setup-browse-all") {
                        saved.select(nil)
                        onBrowseAll()
                    }
                    ForEach(state.setups) { setup in
                        choice(setup.name, selected: state.selectedID == setup.id,
                               id: "gym-setup-switch-\(setup.name)") { saved.select(setup.id) }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Saved gym setups")
        }
    }

    private func choice(_ name: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button {
            onSwitch()
            action()
        } label: {
            Text(name)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(minWidth: 44, minHeight: 44)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 8).fill(NotebookStyle.clay.opacity(0.1))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.ink)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}

struct LibraryGymFilterButton: View {
    @Binding var filter: ExerciseGymFilter
    let identifier: String
    let resultCount: (ExerciseGymFilter) -> Int
    var onOpen: () -> Void = {}
    @State private var showing = false

    var body: some View {
        Button {
            onOpen()
            showing = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                Text(filter.activeCount == 0 ? "Filters" : "Filters (\(filter.activeCount))")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(filter.activeCount > 0 ? NotebookStyle.clay : NotebookStyle.ink)
        .accessibilityLabel("Gym and equipment filters")
        .accessibilityValue([filter.gym?.label, filter.availableEquipment == nil ? nil : filter.equipmentSummary]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier(identifier)
        .sheet(isPresented: $showing) {
            ExerciseGymFilterEditor(filter: $filter, resultCount: resultCount)
        }
    }
}
