import SwiftUI
import SendaDomain
import SendaLogger

struct SetEditorView: View {
    @Bindable var model: LoggerModel
    @State private var invalidRows = Set<Int>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(model.exercise.name).font(.system(size: 41, weight: .regular, design: .serif).italic())
                HStack {
                    Text("SET").frame(width: 28, alignment: .leading)
                    Text("WEIGHT · LB").frame(maxWidth: .infinity)
                    Text("REPS").frame(maxWidth: .infinity)
                }.font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(NotebookStyle.quiet)
                VStack(spacing: 0) {
                    ForEach(Array((model.editor?.sets ?? []).enumerated()), id: \.offset) { index, values in
                        SetEditorRow(index: index, values: values, update: { newValues in
                            model.updateEditedSet(at: index, values: newValues)
                        }, validity: { valid in
                            if valid { invalidRows.remove(index) } else { invalidRows.insert(index) }
                        })
                        Rectangle().fill(NotebookStyle.rule).frame(height: 1)
                    }
                }
                if !invalidRows.isEmpty {
                    Text("Enter a valid weight and rep count for each set.")
                        .font(.callout).foregroundStyle(NotebookStyle.clay)
                }
                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                }
            }.padding(.horizontal, 24).padding(.top, 15).padding(.bottom, 24)
        }
        .accessibilityIdentifier("set-editor-scroll")
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button("Cancel") { model.cancelSetEdits() }
                    .frame(minHeight: 44).accessibilityIdentifier("cancel-set-edits")
                Spacer()
                Text(model.draft != nil ? "DRAFT · NOT RECORDED" : "EDITING RECORDED SETS")
                    .font(.system(size: 10, weight: .semibold)).tracking(1)
            }
            .padding(.horizontal, 24).padding(.top, 8).background(NotebookStyle.ivory)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Text(model.draft != nil ? "These sets are still unrecorded." : "Save changes to this recorded entry.")
                    .font(.caption).foregroundStyle(NotebookStyle.quiet)
                RecordButton(title: model.draft != nil ? "Keep draft changes" : "Save corrections") {
                    if invalidRows.isEmpty { model.confirmSetEdits() }
                }
                .disabled(!invalidRows.isEmpty).opacity(invalidRows.isEmpty ? 1 : 0.45)
                .accessibilityIdentifier("confirm-set-edits")
            }.padding(.horizontal, 24).padding(.vertical, 12).background(NotebookStyle.ivory)
        }
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .interactiveDismissDisabled(!invalidRows.isEmpty)
    }
}

private struct SetEditorRow: View {
    let index: Int
    let values: SetValues
    let update: (SetValues) -> Bool
    let validity: (Bool) -> Void
    @State private var weightText = ""
    @State private var repsText = ""
    @FocusState private var focused: NumericField?

    var body: some View {
        HStack(spacing: 7) {
            Text("\(index + 1)").font(.system(.caption, design: .monospaced))
                .foregroundStyle(NotebookStyle.quiet).frame(width: 28, alignment: .leading)
            control(.weight, text: $weightText, current: values.weight)
            control(.reps, text: $repsText, current: values.reps)
        }
        .padding(.vertical, 14)
        .onAppear {
            weightText = NumericField.weight.text(values.weight)
            repsText = String(values.reps)
        }
    }

    private func control(_ field: NumericField, text: Binding<String>, current: Int) -> some View {
        VStack(spacing: 6) {
            TextField(field.label, text: Binding(get: { text.wrappedValue }, set: {
                text.wrappedValue = $0
                applyText()
            }))
            .font(.system(size: 25, weight: .regular).monospacedDigit())
            .textFieldStyle(.plain).multilineTextAlignment(.center)
            .numericKeyboard(decimal: field == .weight).focused($focused, equals: field)
            .accessibilityLabel("Set \(index + 1), \(field.title)")
            .accessibilityIdentifier("set-\(index + 1)-\(field.rawValue)")
            HStack(spacing: 0) {
                stepButton(field, symbol: "minus", current: current, delta: -field.step)
                stepButton(field, symbol: "plus", current: current, delta: field.step)
            }
        }.frame(maxWidth: .infinity)
    }

    private func stepButton(_ field: NumericField, symbol: String, current: Int, delta: Int) -> some View {
        Button {
            focused = nil
            let changed = min(field.range.upperBound, max(field.range.lowerBound, current + delta))
            if field == .weight { weightText = field.text(changed) } else { repsText = field.text(changed) }
            applyText()
        } label: {
            Image(systemName: symbol).font(.system(size: 16, weight: .light))
                .frame(maxWidth: .infinity).frame(minHeight: 44)
        }
        .buttonStyle(.plain).foregroundStyle(NotebookStyle.clay)
        .accessibilityLabel("\(delta < 0 ? "Decrease" : "Increase") set \(index + 1) \(field.title)")
        .accessibilityIdentifier("set-\(index + 1)-\(field.rawValue)-\(delta < 0 ? "decrease" : "increase")")
    }

    private func applyText() {
        guard let weight = NumericField.weight.parse(weightText), let reps = NumericField.reps.parse(repsText) else {
            validity(false)
            return
        }
        validity(update(SetValues(weight: weight, reps: reps)))
    }
}
