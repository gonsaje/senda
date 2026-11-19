import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingInputDock: View {
    @Bindable var model: TrainingNotebookModel
    let focus: TrainingFocus
    @Binding var weightEntry: TrainingWeightEntrySettings
    var beginInteraction: () -> Void = {}
    @FocusState private var typing: Bool
    @AccessibilityFocusState(for: .voiceOver) private var editorFocused: Bool
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .largeTitle) private var numeralSize: CGFloat = 31
    private var usesPlates: Bool { focus.field == .weight && weightEntry.usesPlates }
    private var plateSize: Decimal { weightEntry[model.unit] }
    private var plateDelta: String { (plateSize * Decimal(weightEntry.count)).formatted(.number) }
    private var index: Int { model.setPosition(for: focus.rowID)?.setIndex ?? 1 }
    private var setContext: String {
        let base = "Set \(index)"
        guard let position = model.setPosition(for: focus.rowID), position.isDropSet else { return base }
        return "\(base) · \(position.stageIndex == 1 ? "Start" : "Drop \(position.stageIndex - 1)")"
    }
    private var fieldLabel: String { focus.field == .weight ? "Weight (\(model.unit.symbol))" : "Reps" }
    private var headerLayout: AnyLayout {
        textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 8))
    }
    private var isLastRow: Bool { model.rows.last?.id == focus.rowID }
    private var canStartNextSet: Bool {
        guard let row = model.focusedRow else { return false }
        return model.rowStatus(for: row) == .recorded && model.errorMessage == nil && !model.canRetrySave
    }
    private var inputAccessibilityValue: String {
        let text = model.inputText(for: focus)
        guard !text.isEmpty else { return "Not entered" }
        let unit: String
        if focus.field == .weight {
            unit = model.unit == .pounds ? (text == "1" ? "pound" : "pounds") : (text == "1" ? "kilogram" : "kilograms")
        } else {
            unit = text == "1" ? "rep" : "reps"
        }
        return "\(text) \(unit)"
    }
    var body: some View {
        VStack(spacing: usesPlates && !typing ? 3 : 8) {
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
            headerLayout {
                if textSize.isAccessibilitySize && focus.field == .weight {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            contextTitle
                            fieldTitle
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: 0) { contextTitle; fieldTitle }
                    }
                } else {
                    contextTitle
                }
                HStack(spacing: 8) {
                    if !textSize.isAccessibilitySize { Spacer(minLength: 0) }
                    if focus.field == .weight {
                        if typing && !textSize.isAccessibilitySize {
                            Button { typing = false } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }
                            .accessibilityLabel(usesPlates ? "Use plates" : "Use weight dial")
                            .accessibilityHint("Close the keyboard without changing the value")
                            .accessibilityIdentifier("input-use-dial")
                        }
                        Button { beginInteraction(); model.selectInput(focus.rowID, field: .reps) } label: {
                            Text("Reps →").font(.subheadline.weight(.medium)).foregroundStyle(NotebookStyle.clay)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                        }
                        .accessibilityLabel("Edit reps")
                        .accessibilityHint("Edit reps for \(setContext.lowercased())")
                        .accessibilityIdentifier("input-next")
                    } else if isLastRow {
                        Button {
                            beginInteraction()
                            if model.newSet(keyboard: typing) {
                                TrainingAccessibility.announce("New set. Enter \(model.exercise?.requiresWeight == false ? "reps" : "weight").")
                            }
                        } label: {
                            Text("Next set").font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                        }
                        .disabled(!canStartNextSet)
                        .foregroundStyle(canStartNextSet ? NotebookStyle.clay : NotebookStyle.quiet)
                        .accessibilityHint("Start another working set with blank values")
                        .accessibilityIdentifier("input-next-set")
                    }
                    if textSize.isAccessibilitySize { Spacer(minLength: 8) }
                    Button(action: finishEditing) {
                        Text("Done").font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityHint("Close the number editor")
                    .accessibilityIdentifier("input-done")
                }
            }
            if focus.field == .weight {
                HStack(spacing: 6) {
                    if !textSize.isAccessibilitySize { fieldTitle }
                    Spacer(minLength: 0)
                    modeButton(plates: false)
                    modeButton(plates: true)
                    if textSize.isAccessibilitySize { Spacer(minLength: 0) }
                }
            } else {
                fieldTitle.frame(maxWidth: .infinity)
            }
            if textSize.isAccessibilitySize {
                valueInput
                HStack {
                    step(false)
                    Spacer(minLength: 8)
                    step(true)
                }
            } else {
                HStack(spacing: 16) {
                    step(false)
                    valueInput
                    step(true)
                }
            }
            if usesPlates && !typing {
                TrainingPlateControls(unit: model.unit, settings: $weightEntry)
            } else if focus.field == .weight && !typing && !textSize.isAccessibilitySize {
                WeightDialSurface(
                    value: model.focusedRow?.parsedWeight ?? model.focusedRow?.canonicalWeight ?? 0,
                    unit: model.unit,
                    beginInteraction: beginInteraction,
                    update: { model.setInputWeight($0, focus: focus) }
                )
                .id(model.unit)
            }
            if focus.field == .weight && !typing {
                if let last = model.lastPlateAdjustment(focus: focus) {
                    undoPlate(size: last.size, count: last.count)
                } else if usesPlates {
                    let equation = "\(plateSize.formatted(.number)) × \(weightEntry.count) = \(plateDelta) \(model.unit.symbol)"
                    Text(equation)
                        .font(.caption.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                        .frame(minHeight: 44)
                        .accessibilityLabel("\(weightEntry.count) \(plateSize.formatted(.number)) \(model.unit.symbol) \(weightEntry.count == 1 ? "plate" : "plates"), \(plateDelta) \(model.unit.symbol) total change")
                        .accessibilityIdentifier("input-plate-calculation")
                }
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(NotebookStyle.inputSurface, ignoresSafeAreaEdges: .bottom)
        .foregroundStyle(NotebookStyle.ink)
        .task {
            await Task.yield()
            if !Task.isCancelled { typing = focus.keyboard; editorFocused = true }
        }
    }

    private var contextTitle: some View {
        Text(textSize.isAccessibilitySize ? setContext : "\(model.exercise?.displayName ?? "") · \(setContext)")
            .font(textSize.isAccessibilitySize ? .caption2 : .caption).foregroundStyle(NotebookStyle.quiet)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("input-set-context")
    }

    private var fieldTitle: some View {
        Text(fieldLabel).font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.quiet)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("input-field-label")
    }

    private func modeButton(plates: Bool) -> some View {
        let selected = weightEntry.usesPlates == plates
        return Button {
            beginInteraction()
            weightEntry.usesPlates = plates
            typing = false
        } label: {
            Text(plates ? "Plates" : "Dial")
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 6)
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(selected ? NotebookStyle.ink : NotebookStyle.quiet)
                .overlay(alignment: .bottom) {
                    if selected { Rectangle().fill(NotebookStyle.clay).frame(height: 2) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(plates ? "input-mode-plates" : "input-mode-dial")
    }

    private func undoPlate(size: Decimal, count: Int) -> some View {
        let magnitude = (size * Decimal(abs(count))).formatted(.number)
        let signed = (count > 0 ? "+" : "−") + magnitude
        return Button {
            beginInteraction()
            if model.undoPlateAdjustment(focus: focus) {
                TrainingAccessibility.announce("Plate change undone. \(inputAccessibilityValue).")
            }
        } label: {
            Label("Undo \(signed) \(model.unit.symbol)", systemImage: "arrow.uturn.backward")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(NotebookStyle.clay)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Undo \(count > 0 ? "adding" : "removing") \(abs(count)) \(size.formatted(.number)) \(model.unit.symbol) \(abs(count) == 1 ? "plate" : "plates")")
        .accessibilityIdentifier("input-plate-undo")
    }

    private var valueInput: some View {
                TextField(usesPlates ? "0" : "", text: Binding(
                    get: { model.inputText(for: focus) }, set: { beginInteraction(); model.typeInput($0, focus: focus) }))
                    .font(.system(size: numeralSize, weight: .medium).monospacedDigit()).multilineTextAlignment(.center)
                    .textFieldStyle(.plain).numericKeyboard(decimal: focus.field == .weight).focused($typing)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .submitLabel(focus.field == .weight ? .next : .done)
                    .onSubmit {
                        if focus.field == .weight { beginInteraction(); model.selectInput(focus.rowID, field: .reps) }
                        else { finishEditing() }
                    }
                    .accessibilityLabel("\(setContext), \(focus.field == .weight ? "weight in \(model.unit.symbol)" : "reps")")
                    .accessibilityHint("Type a value or use the increase and decrease buttons")
                    .accessibilityFocused($editorFocused)
                    .accessibilityIdentifier("set-input")
                    .simultaneousGesture(TapGesture().onEnded { beginInteraction() })
    }
    private func finishEditing() {
        beginInteraction()
        guard model.finishEditing(), let row = model.rows.first(where: { $0.id == focus.rowID }) else { return }
        let message: String
        switch model.rowStatus(for: row) {
        case .empty: message = "\(setContext) needs values."
        case .unfinished: message = "Input saved. Enter valid values to complete the set."
        case .recorded: message = "\(setContext) saved."
        case .pendingCorrection: message = "Input saved. Last saved values are unchanged."
        }
        TrainingAccessibility.announce(message)
    }
    private func step(_ increasing: Bool) -> some View {
        let count = increasing ? weightEntry.count : -weightEntry.count
        return Button {
            beginInteraction()
            let changed = usesPlates
                ? model.adjustPlate(plateSize, count: count, focus: focus)
                : model.stepInput(increasing: increasing, focus: focus)
            if changed {
                if focus.field == .weight { typing = false }
                if model.errorMessage == nil { TrainingAccessibility.announce(inputAccessibilityValue) }
            }
        } label: {
            if usesPlates {
                Text((increasing ? "+" : "−") + plateDelta)
                    .font(.body.weight(.semibold).monospacedDigit()).foregroundStyle(NotebookStyle.clay)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(.horizontal, 8).frame(minWidth: 52, minHeight: 48)
                    .background(NotebookStyle.ivory, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
            } else {
                Image(systemName: increasing ? "plus" : "minus").font(.system(size: 22, weight: .light))
                    .frame(width: 50, height: 48).contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(usesPlates && !model.canAdjustPlate(plateSize, count: count, focus: focus))
        .accessibilityLabel(usesPlates ? "\(increasing ? "Add" : "Subtract") \(plateDelta) \(model.unit.symbol)"
            : "\(increasing ? "Increase" : "Decrease") \(focus.field == .weight ? "weight in \(model.unit.symbol)" : "reps")")
        .accessibilityValue(inputAccessibilityValue)
        .accessibilityIdentifier(increasing ? "input-increase" : "input-decrease")
    }
}
