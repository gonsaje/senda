import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingPlateCalculator: View {
    let model: TrainingNotebookModel
    let focus: TrainingFocus
    let close: () -> Void
    private let unit: WeightUnit
    @State private var total: String
    @State private var bar: Int?
    @State private var failedToApply = false
    @FocusState private var enteringTotal: Bool
    @Environment(\.dynamicTypeSize) private var textSize

    init(model: TrainingNotebookModel, focus: TrainingFocus, close: @escaping () -> Void) {
        self.model = model
        self.focus = focus
        self.close = close
        unit = model.focusedRow?.unit ?? model.unit
        _total = State(initialValue: model.inputText(for: focus))
        _bar = State(initialValue: model.focusedRow?.barbellWeight)
    }

    private var calculation: PlateLoading? {
        guard let target = unit.parse(total), let bar else { return nil }
        return PlateLoading.calculate(totalWeight: target, barbellWeight: bar, unit: unit)
    }

    var body: some View {
        let load = calculation
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    totalField
                    HStack(spacing: 12) {
                        Text("Barbell").foregroundStyle(NotebookStyle.quiet)
                        Spacer()
                        TrainingBarbellMenu(unit: unit, weight: bar, identifier: "plate-target-bar",
                            canSet: { $0 != bar && ($0 ?? 1) > 0 }, set: { bar = $0 })
                    }
                    Divider()
                    result(load)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .disabled(failedToApply)
            }
            .accessibilityIdentifier("plate-target-scroll")
            .scrollDismissesKeyboard(.immediately)
            .background(NotebookStyle.ivory)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if failedToApply || !textSize.isAccessibilitySize {
                    footer(load)
                        .frame(maxWidth: 500).padding(.horizontal, 24).padding(.vertical, 8)
                        .frame(maxWidth: .infinity).background(NotebookStyle.ivory)
                }
            }
            .navigationTitle("Plate math")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if textSize.isAccessibilitySize && !failedToApply {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use") { apply(load) }
                            .disabled(!canApply(load))
                            .accessibilityLabel("Use this weight for the set")
                            .accessibilityIdentifier("plate-target-apply")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if failedToApply && model.canRetrySave { _ = model.cancelPendingAction() }
                        close()
                    }
                    .accessibilityIdentifier("plate-target-cancel")
                }
            }
        }
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .interactiveDismissDisabled(failedToApply)
        #if os(iOS)
        .presentationBackground(NotebookStyle.ivory)
        .presentationDetents(textSize >= .xxLarge ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private var totalField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total weight").font(.subheadline.weight(.medium)).foregroundStyle(NotebookStyle.quiet)
            HStack(spacing: 8) {
                TextField("0", text: $total)
                    .textFieldStyle(.plain).numericKeyboard(decimal: true)
                    .font(.title.monospacedDigit().weight(.medium))
                    .focused($enteringTotal).submitLabel(.done).onSubmit { enteringTotal = false }
                    .accessibilityLabel("Total weight in \(unit.symbol)")
                    .accessibilityIdentifier("plate-target-total")
                Text(unit.symbol).foregroundStyle(NotebookStyle.quiet)
                if !total.isEmpty {
                    Button {
                        total = ""
                        enteringTotal = true
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(NotebookStyle.quiet)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Clear total weight")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .background(NotebookStyle.inputSurface, in: NotebookStyle.squircle(10))
        }
    }

    @ViewBuilder private func result(_ load: PlateLoading?) -> some View {
        switch load {
        case .exact(_, let plates):
            let description = plates.map { plate in
                let size = "\(plate.size.formatted(.number)) \(unit.symbol)"
                return plate.count == 1 ? size : "\(plate.count) × \(size)"
            }.joined(separator: " + ")
            VStack(alignment: .leading, spacing: 5) {
                Text("Load on each side").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                Text(plates.isEmpty ? "Bar only" : description)
                    .font(NotebookTypography.heading(23, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("plate-target-result")
        case .belowBar:
            if let bar {
                Text("The bar alone weighs \(weightText(bar)).")
                    .accessibilityIdentifier("plate-target-result")
                suggested(bar, identifier: "plate-target-lower")
            }
        case .between(let lower, let upper):
            Text("Closest loadable totals")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                .accessibilityIdentifier("plate-target-result")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { suggestions(lower: lower, upper: upper) }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 6) { suggestions(lower: lower, upper: upper) }
            }
        case nil:
            Text(bar == nil ? "Choose a barbell to see the plates for each side."
                 : total.isEmpty ? "Enter a total weight including the bar."
                 : "Enter a weight up to \(weightText(NumericField.weight.range.upperBound)) with up to two decimal places.")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                .accessibilityIdentifier("plate-target-result")
        }
    }

    @ViewBuilder private func suggestions(lower: Int, upper: Int?) -> some View {
        suggested(lower, identifier: "plate-target-lower")
        if let upper { suggested(upper, identifier: "plate-target-upper") }
    }

    private func suggested(_ weight: Int, identifier: String) -> some View {
        Button {
            total = unit.text(for: weight)
            enteringTotal = false
        } label: {
            Text(weightText(weight))
                .padding(.horizontal, 12).frame(minWidth: 44, minHeight: 44)
                .background(NotebookStyle.inputSurface, in: NotebookStyle.squircle(8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(NotebookStyle.clay)
        .accessibilityHint("Use this total to preview the plates")
        .accessibilityIdentifier(identifier)
    }

    private func weightText(_ weight: Int) -> String { "\(unit.text(for: weight)) \(unit.symbol)" }

    @ViewBuilder private func footer(_ load: PlateLoading?) -> some View {
        if failedToApply {
            TrainingSaveError(model: model, message: model.errorMessage ?? "Couldn’t update this set.", retrySucceeded: close)
        } else {
            let exact: Int? = if case .exact(let weight, _) = load { weight } else { nil }
            RecordButton(title: exact.map { "Use \(weightText($0))" } ?? "Use this weight") { apply(load) }
                .disabled(!canApply(load))
            .accessibilityHint("Set the weight for this set")
            .accessibilityIdentifier("plate-target-apply")
        }
    }

    private func canApply(_ load: PlateLoading?) -> Bool {
        if case .exact = load { return !model.canRetrySave }
        return false
    }

    private func apply(_ load: PlateLoading?) {
        guard case .exact(let weight, _) = load, let bar else { return }
        if model.applyPlateLoad(totalWeight: weight, barbellWeight: bar, focus: focus) {
            close()
        } else {
            enteringTotal = false
            failedToApply = true
        }
    }
}
