import SwiftUI
import SendaDomain
import SendaLogger
#if canImport(UIKit)
import UIKit
#endif

struct NumericDock: View {
    @Bindable var model: LoggerModel
    @FocusState private var typing: Bool
    private var field: NumericField { model.selectedField }
    var body: some View {
        VStack(spacing: 8) {
            Rectangle().fill(NotebookStyle.rule).frame(height: 1)
            HStack(spacing: 12) {
                Text("\(model.exercise.shortName) · " + (model.selectedSetIndex.map { "Set \($0 + 1)" } ?? "All sets"))
                    .font(.caption).foregroundStyle(NotebookStyle.quiet).lineLimit(1).minimumScaleFactor(0.8)
                if field == .weight {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Button { if model.selectWeightUnit(unit) { typing = false } } label: {
                            Text(unit.symbol).font(.subheadline.weight(unit == model.selectedWeightUnit ? .semibold : .regular))
                                .underline(unit == model.selectedWeightUnit, color: NotebookStyle.clay).frame(minWidth: 44, minHeight: 44)
                        }.foregroundStyle(unit == model.selectedWeightUnit ? NotebookStyle.clay : NotebookStyle.quiet)
                            .accessibilityLabel("Edit in \(unit.symbol)").accessibilityIdentifier("weight-unit-\(unit.symbol)")
                    }
                } else { Text(field.label).font(.caption).foregroundStyle(NotebookStyle.quiet) }
                Spacer(minLength: 4)
                if model.isEditingRecorded {
                    Button("Cancel") { model.cancelEditing(); typing = false }.font(.caption).frame(minHeight: 36)
                        .accessibilityIdentifier("cancel-entry-changes")
                } else {
                    if typing || !model.numberInputIsValid {
                        Button("Cancel") { model.cancelNumberInput(); model.closeNumberEditor(); typing = false }
                            .font(.caption).frame(minHeight: 36).accessibilityIdentifier("cancel-number-input")
                    }
                    Button("Done") { if model.closeNumberEditor() { typing = false } }
                        .font(.caption.weight(.medium)).frame(minHeight: 36).accessibilityIdentifier("apply-number-input")
                }
            }
            HStack(spacing: 18) {
                step(increasing: false)
                TextField(field.title, text: Binding(get: { model.numberInputText }, set: { trace("binding incoming=\($0.debugDescription) old=\(model.numberInputText.debugDescription)"); model.typeNumber($0) }))
                    .font(.system(size: 31, weight: .medium).monospacedDigit()).multilineTextAlignment(.center)
                    .textFieldStyle(.plain).numericKeyboard(decimal: field == .weight).focused($typing)
                    .submitLabel(.done).onSubmit { finish() }
                    .accessibilityLabel(field == .weight ? "Weight in \(model.selectedWeightUnit.symbol)" : field.title)
                    .accessibilityIdentifier("dock-number")
                step(increasing: true)
            }
            // The keyboard replaces the ruler while entering a number.
            if field == .weight && !typing {
                WeightDial(model: model).id("\(model.selectedExerciseID)-\(model.selectedSetIndex ?? -1)-\(model.selectedWeightUnit.rawValue)")
            }
            if !model.numberInputIsValid {
                Text(field == .weight ? "Enter a valid weight in \(model.selectedWeightUnit.symbol)" : "Enter a valid \(field.label) value")
                    .font(.caption).foregroundStyle(NotebookStyle.clay)
            }
            RecordButton(title: model.isEditingRecorded ? "Done" : "Record \(model.recordSetCount) \(model.recordSetCount == 1 ? "set" : "sets")") {
                if model.isEditingRecorded { if model.finishEditing() { typing = false } }
                else if model.record() { typing = false }
            }
            .disabled(!model.numberInputIsValid).opacity(model.numberInputIsValid ? 1 : 0.45)
            .accessibilityIdentifier(model.isEditingRecorded ? "save-entry-changes" : "record-batch")
        }
        .padding(.horizontal, 26).padding(.bottom, 12)
        .frame(maxWidth: 560).frame(maxWidth: .infinity).background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .onChange(of: typing) { _, focused in trace("focus=\(focused) raw=\(model.numberInputText.debugDescription)"); if !focused { model.applyNumberInput() } }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification)) { notification in
            if let input = notification.object as? UITextField { trace("native text=\((input.text ?? "").debugDescription) raw=\(model.numberInputText.debugDescription)") }
        }
        #endif
        .onChange(of: field) { _, _ in typing = false }
        .onChange(of: model.selectedSetIndex) { _, _ in typing = false }
        .onChange(of: model.selectedExerciseID) { _, _ in typing = false }
    }
    private func trace(_ message: String) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SENDA_TRACE_INPUT"] == "1" { print("SENDA_INPUT \(Date().timeIntervalSince1970) \(message)") }
        #endif
    }
    private func step(increasing: Bool) -> some View {
        Button { if model.stepNumber(increasing: increasing) { typing = false } } label: {
            Image(systemName: increasing ? "plus" : "minus").font(.system(size: 22, weight: .light))
                .frame(width: 55, height: 48)
                .background(NotebookStyle.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
        }.accessibilityLabel("\(increasing ? "Increase" : "Decrease") \(field.title)")
            .accessibilityIdentifier(increasing ? "dock-increase" : "dock-decrease")
    }
    private func finish() {
        if model.isEditingRecorded { if model.finishEditing() { typing = false } }
        else if model.closeNumberEditor() { typing = false }
    }
}
