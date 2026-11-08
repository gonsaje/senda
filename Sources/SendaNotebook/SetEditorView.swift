import SwiftUI
import SendaDomain
import SendaLogger

struct SetEditorView: View {
    @Bindable var model: LoggerModel
    var onCancel: (() -> Void)? = nil
    var onConfirm: (() -> Void)? = nil
    private var targetDate: Date? {
        let id: UUID
        switch model.editor?.source {
        case .recorded(let value): id = value
        case .editing(let edit): id = edit.batchID
        default: return nil
        }
        return model.journal.batches.first { $0.id == id }?.recordedAt
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Set").frame(width: 28, alignment: .leading)
                    HStack(spacing: 18) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Button { model.selectEditorWeightUnit(unit) } label: {
                                Text(unit.symbol)
                                    .underline(unit == model.editorWeightUnit, color: NotebookStyle.clay)
                                    .frame(minWidth: 40, minHeight: 44)
                            }
                            .foregroundStyle(unit == model.editorWeightUnit ? NotebookStyle.clay : NotebookStyle.quiet)
                            .accessibilityLabel("Edit in \(unit.symbol)")
                            .accessibilityIdentifier("editor-unit-\(unit.symbol)")
                        }
                    }.frame(maxWidth: .infinity)
                    Text("reps").frame(maxWidth: .infinity)
                }.font(.caption).foregroundStyle(NotebookStyle.quiet)
                VStack(spacing: 0) {
                    ForEach(Array((model.editor?.sets ?? []).indices), id: \.self) { index in
                        SetEditorRow(index: index, model: model)
                        Rectangle().fill(NotebookStyle.rule).frame(height: 1)
                    }
                }
                if !model.canConfirmSetEdits {
                    Text("Enter a valid weight and rep count for each set.").font(.callout).foregroundStyle(NotebookStyle.clay)
                }
                if let error = model.errorMessage ?? model.recoveryErrorMessage {
                    Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                }
            }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 24)
        }
        .accessibilityIdentifier("set-editor-scroll")
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button("Cancel") { if let onCancel { onCancel() } else { model.cancelSetEdits() } }.frame(minHeight: 44).accessibilityIdentifier("cancel-set-edits")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.exercise.name).font(.system(size: 23, weight: .regular, design: .serif).italic())
                    if let date = targetDate { Text(EntryText.date(date)).font(.caption).foregroundStyle(NotebookStyle.quiet) }
                }
            }.padding(.horizontal, 24).padding(.top, 8).background(NotebookStyle.ivory)
        }
        .safeAreaInset(edge: .bottom) {
            RecordButton(title: "Done") { if model.confirmSetEdits() { onConfirm?() } }
                .disabled(!model.canConfirmSetEdits).opacity(model.canConfirmSetEdits ? 1 : 0.45)
                .accessibilityIdentifier("confirm-set-edits")
                .padding(.horizontal, 24).padding(.vertical, 12).background(NotebookStyle.ivory)
        }
        .tint(NotebookStyle.clay).buttonStyle(.plain)
        .interactiveDismissDisabled(!model.canConfirmSetEdits)
    }
}

private struct SetEditorRow: View {
    let index: Int
    @Bindable var model: LoggerModel
    @FocusState private var focused: NumericField?
    var body: some View {
        HStack(spacing: 7) {
            Text("\(index + 1)").font(.system(.caption, design: .monospaced)).foregroundStyle(NotebookStyle.quiet)
                .frame(width: 28, alignment: .leading)
            control(.weight)
            control(.reps)
        }.padding(.vertical, 14)
        .onAppear {
            if let focus = model.editor?.focus, focus.index == index { focused = focus.field }
        }
        .onChange(of: focused) { _, field in model.setEditorFocus(index: index, field: field) }
    }
    private func text(_ field: NumericField) -> String {
        guard let edit = model.editor, edit.inputs.indices.contains(index) else { return "" }
        return field == .weight ? edit.inputs[index].weight : edit.inputs[index].reps
    }
    private func control(_ field: NumericField) -> some View {
        VStack(spacing: 6) {
            TextField(field == .weight ? model.editorWeightUnit.symbol : field.label, text: Binding(get: { text(field) }, set: { model.typeEditedSet(at: index, field: field, text: $0) }))
                .font(.system(size: 25).monospacedDigit()).textFieldStyle(.plain).multilineTextAlignment(.center)
                .numericKeyboard(decimal: field == .weight).focused($focused, equals: field)
                .accessibilityLabel("Set \(index + 1), \(field == .weight ? model.editorWeightUnit.symbol : field.title)")
                .accessibilityIdentifier("set-\(index + 1)-\(field.rawValue)")
            if field == .weight, let edit = model.editor, edit.sets.indices.contains(index) {
                let other = model.editorWeightUnit.alternate
                Text("\(other.text(for: edit.sets[index].weight)) \(other.symbol)")
                    .font(.caption.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    .accessibilityIdentifier("set-\(index + 1)-alternate-weight")
            }
            HStack(spacing: 0) {
                step(field, increasing: false)
                step(field, increasing: true)
            }
        }.frame(maxWidth: .infinity)
    }
    private func step(_ field: NumericField, increasing: Bool) -> some View {
        Button {
            if model.stepEditedSet(at: index, field: field, increasing: increasing) { focused = nil }
        } label: {
            Image(systemName: increasing ? "plus" : "minus").font(.system(size: 16, weight: .light))
                .frame(maxWidth: .infinity).frame(minHeight: 44)
        }.foregroundStyle(NotebookStyle.clay)
            .accessibilityLabel("\(increasing ? "Increase" : "Decrease") set \(index + 1) \(field.title)")
            .accessibilityIdentifier("set-\(index + 1)-\(field.rawValue)-\(increasing ? "increase" : "decrease")")
    }
}
