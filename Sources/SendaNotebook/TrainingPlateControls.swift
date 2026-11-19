import SwiftUI
import SendaDomain

/// The current workout keeps the same plate setup when moving between sets.
struct TrainingWeightEntrySettings {
    var usesPlates = false
    var count = 2
    private var pounds: Decimal = 10
    private var kilograms: Decimal = 5

    subscript(unit: WeightUnit) -> Decimal {
        get { unit == .pounds ? pounds : kilograms }
        set {
            if unit == .pounds { pounds = newValue }
            else { kilograms = newValue }
        }
    }
}

struct TrainingPlateControls: View {
    let unit: WeightUnit
    @Binding var settings: TrainingWeightEntrySettings
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var choosingSize = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if textSize.isAccessibilitySize {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { sizeButton; Spacer(minLength: 0); countMenu }
                        .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 0) { sizeButton; countMenu }
                }
            } else {
                HStack(spacing: 8) {
                    Text("Plate size (\(unit.symbol))")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    Spacer(minLength: 0)
                    countMenu
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 3) { sizeButtons }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 3), count: 4), spacing: 0) {
                        sizeButtons
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $choosingSize) { sizeSheet }
    }

    private var sizeButtons: some View {
        ForEach(unit.plateSizes, id: \.self) { size in
            let selected = settings[unit] == size
            Button { settings[unit] = size } label: {
                Text(size.formatted(.number))
                    .font(.subheadline.weight(selected ? .semibold : .regular).monospacedDigit())
                    .foregroundStyle(selected ? NotebookStyle.ivory : NotebookStyle.ink)
                    .padding(.vertical, 5)
                    .frame(minWidth: 44, maxWidth: .infinity)
                    .background {
                        if selected { RoundedRectangle(cornerRadius: 7).fill(NotebookStyle.ink) }
                        else { RoundedRectangle(cornerRadius: 7).strokeBorder(NotebookStyle.quiet.opacity(0.4)) }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(size.formatted(.number)) \(unit.symbol) plate")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("input-plate-size-\(size)")
        }
    }

    private var sizeButton: some View {
        Button { choosingSize = true } label: {
            menuLabel("Plate \(settings[unit].formatted(.number)) \(unit.symbol)")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Plate size")
        .accessibilityValue("\(settings[unit].formatted(.number)) \(unit.symbol)")
        .accessibilityIdentifier("input-plate-size-picker")
    }

    private var sizeSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(unit.plateSizes, id: \.self) { size in
                        let selected = size == settings[unit]
                        Button {
                            settings[unit] = size
                            choosingSize = false
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(size.formatted(.number)) \(unit.symbol)")
                                    .font(.body.weight(selected ? .semibold : .regular).monospacedDigit())
                                Spacer(minLength: 0)
                                if selected {
                                    Image(systemName: "checkmark").foregroundStyle(NotebookStyle.clay)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.vertical, 8)
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("input-plate-size-\(size)")
                        Divider()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("input-plate-size-list")
            .background(NotebookStyle.ivory)
            .foregroundStyle(NotebookStyle.ink)
            .navigationTitle("Plate size (\(unit.symbol))")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { choosingSize = false }
                        .accessibilityIdentifier("input-plate-size-close")
                }
            }
        }
        .tint(NotebookStyle.clay)
        #if os(iOS)
        .presentationBackground(NotebookStyle.ivory)
        .presentationDetents([.large])
        #endif
    }

    private var countMenu: some View {
        Menu {
            ForEach([2, 1], id: \.self) { count in
                let title = count == 2 ? "One per side" : "One plate"
                Button { settings.count = count } label: {
                    if settings.count == count { Label(title, systemImage: "checkmark") }
                    else { Text(title) }
                }
                .accessibilityAddTraits(settings.count == count ? .isSelected : [])
                .accessibilityIdentifier("input-plate-count-\(count)")
            }
        } label: { menuLabel(settings.count == 2 ? "One per side" : "One plate") }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
        .accessibilityLabel("Plate count")
        .accessibilityValue(settings.count == 2 ? "One per side" : "One plate")
        .accessibilityIdentifier("input-plate-count")
    }

    private func menuLabel(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.down").font(.caption2).accessibilityHidden(true)
        }
        .foregroundStyle(NotebookStyle.clay)
        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct TrainingBarbellMenu: View {
    let unit: WeightUnit
    let weight: Int?
    let canSet: (Int?) -> Bool
    let set: (Int?) -> Void
    @State private var enteringCustomWeight = false
    @State private var customText = ""

    private var sizes: [Int] { unit == .pounds ? [45, 35, 15] : [20, 15, 10] }

    var body: some View {
        Menu {
            Section("Barbell weight (\(unit.symbol))") {
                ForEach(sizes, id: \.self) { size in
                    if let value = unit.canonicalValue(for: Decimal(size)) {
                        Button { set(value) } label: {
                            if weight == value { Label("\(size) \(unit.symbol)", systemImage: "checkmark") }
                            else { Text("\(size) \(unit.symbol)") }
                        }
                        .disabled(!canSet(value))
                        .accessibilityAddTraits(weight == value ? .isSelected : [])
                        .accessibilityIdentifier("input-barbell-\(size)")
                    }
                }
                Button("Custom weight…") {
                    customText = weight.map(unit.text(for:)) ?? ""
                    enteringCustomWeight = true
                }
            }
            if weight != nil {
                Button("Remove barbell") { set(nil) }
                    .disabled(!canSet(nil))
                    .accessibilityIdentifier("input-remove-barbell")
            }
        } label: {
            HStack(spacing: 4) {
                Text(weight.map { "\(unit.text(for: $0)) \(unit.symbol) bar" } ?? "Add barbell")
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down").font(.caption2).accessibilityHidden(true)
            }
            .foregroundStyle(NotebookStyle.clay)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
        .accessibilityLabel(weight == nil ? "Add barbell" : "Change barbell")
        .accessibilityValue(weight.map { "\(unit.text(for: $0)) \(unit.symbol)" } ?? "No barbell")
        .accessibilityHint("Include one bar in this set’s total weight")
        .accessibilityIdentifier("input-barbell")
        .alert("Custom barbell weight", isPresented: $enteringCustomWeight) {
            TextField("Weight (\(unit.symbol))", text: $customText).numericKeyboard(decimal: true)
            Button("Cancel", role: .cancel) {}
            Button("Apply") {
                if let value = unit.parse(customText) { set(value) }
            }
            .disabled(unit.parse(customText).map { !canSet($0) } ?? true)
        } message: {
            Text("Enter the weight of one bar in \(unit.symbol).")
        }
    }
}
