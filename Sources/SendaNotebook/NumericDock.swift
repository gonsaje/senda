import SwiftUI
import SendaLogger

struct NumericDock: View {
    @Bindable var model: LoggerModel
    @FocusState private var typing: Bool

    private var field: NumericField { model.selectedField }
    private var value: Int {
        switch field {
        case .weight: model.values.first?.weight ?? 0
        case .reps: model.values.first?.reps ?? 10
        case .sets: model.values.count
        }
    }
    private var commonValues: [Int] {
        switch field {
        case .weight:
            let base = (value / 500) * 500
            return [max(0, base - 2_000), max(0, base - 1_000), base, min(1_000_000, base + 1_000)]
        case .reps: return [6, 8, 10, 12]
        case .sets: return [1, 3, 4, 5]
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Rectangle().fill(NotebookStyle.rule).frame(height: 1)
            HStack {
                Text("\(field.title) · \(field.label)").font(.caption.weight(.medium))
                Spacer()
                if typing || !model.numberInputIsValid {
                    Button("Cancel") { model.cancelNumberInput(); typing = false }
                        .font(.caption).frame(minHeight: 30).accessibilityIdentifier("cancel-number-input")
                    Button("Done") { if model.applyNumberInput() { typing = false } }
                        .font(.caption.weight(.semibold)).frame(minHeight: 30).accessibilityIdentifier("apply-number-input")
                } else {
                    Text(field == .sets ? "Batch size" : "Applies to every set").font(.caption)
                }
            }.foregroundStyle(NotebookStyle.quiet)
            HStack(spacing: 0) {
                ForEach(Array(commonValues.enumerated()), id: \.offset) { _, suggestion in
                    Button { apply(suggestion) } label: {
                        Text(field.text(suggestion)).monospacedDigit().font(.subheadline)
                            .frame(maxWidth: .infinity).frame(minHeight: 38)
                    }.buttonStyle(.plain)
                    .foregroundStyle(suggestion == value ? NotebookStyle.clay : NotebookStyle.quiet)
                    .accessibilityLabel("Use \(field.text(suggestion)) \(field.label)")
                }
            }
            HStack(spacing: 18) {
                changeButton(symbol: "minus", label: "Decrease \(field.title)", increasing: false)
                TextField(field.title, text: Binding(get: { model.numberInputText }, set: { model.typeNumber($0) }))
                    .font(.system(size: 31, weight: .medium).monospacedDigit())
                    .multilineTextAlignment(.center).textFieldStyle(.plain)
                    .numericKeyboard(decimal: field == .weight)
                    .focused($typing).submitLabel(.done).onSubmit {
                        if model.applyNumberInput() { typing = false }
                    }
                    .accessibilityLabel("\(field.title) in \(field.label)")
                    .accessibilityIdentifier("dock-number")
                changeButton(symbol: "plus", label: "Increase \(field.title)", increasing: true)
            }
            if !model.numberInputIsValid {
                Text("Enter \(field.text(field.range.lowerBound))–\(field.text(field.range.upperBound)) \(field.label)")
                    .font(.caption).foregroundStyle(NotebookStyle.clay)
            }
            RecordButton(title: "Record \(model.recordSetCount) \(model.recordSetCount == 1 ? "set" : "sets")") {
                typing = false
                model.record()
            }
            .disabled(!model.numberInputIsValid).opacity(model.numberInputIsValid ? 1 : 0.45)
            .accessibilityIdentifier("record-batch")
        }
        .padding(.horizontal, 26).padding(.bottom, 12)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory)
        .onChange(of: typing) { _, focused in if !focused { model.applyNumberInput() } }
        .onChange(of: field) { _, _ in typing = false }
        .onChange(of: model.selectedExerciseID) { _, _ in typing = false }
    }

    private func changeButton(symbol: String, label: String, increasing: Bool) -> some View {
        Button { if model.stepNumber(increasing: increasing) { typing = false } } label: {
            Image(systemName: symbol).font(.system(size: 22, weight: .light))
                .frame(width: 55, height: 50)
                .background(NotebookStyle.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain).accessibilityLabel(label)
        .accessibilityIdentifier(increasing ? "dock-increase" : "dock-decrease")
    }

    private func apply(_ value: Int) {
        typing = false
        _ = model.setValue(value, for: field)
    }
}
