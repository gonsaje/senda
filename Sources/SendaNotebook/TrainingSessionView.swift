import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingSessionView: View {
    @Bindable private var session: TrainingSession
    public init(session: TrainingSession) { self.session = session }
    public var body: some View {
        Group {
            if let recovery = session.recovery {
                LegacyTrainingRecoveryView(recovery: recovery, finished: session.open)
            } else if let model = session.notebook { TrainingNotebookView(model: model) }
            else {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your notebook couldn’t be opened.").font(.system(.largeTitle, design: .serif))
                    Text(session.openingError ?? "Try opening it again.")
                    Text("Your saved file has been left untouched.").font(.callout)
                    Button("Try again", action: session.open).frame(minHeight: 44)
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
    }
}

private struct LegacyTrainingRecoveryView: View {
    @Bindable var recovery: LegacyRecoveryModel
    let finished: () -> Void
    var body: some View {
        Group {
            if let logger = recovery.logger {
                if logger.editor != nil {
                    SetEditorView(model: logger, onCancel: { recovery.discard() }, onConfirm: { recovery.accept() })
                } else if recovery.reviewsSetCount {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Recovered entry").font(.system(size: 32, design: .serif).italic())
                        Text(logger.exercise.name).font(.title2)
                        TextField("Set count", text: Binding(get: { logger.numberInputText }, set: { logger.typeNumber($0) }))
                            .textFieldStyle(.plain).font(.largeTitle.monospacedDigit()).numericKeyboard(decimal: false)
                        HStack {
                            Button("Cancel") { recovery.discard() }.frame(minHeight: 44)
                            Spacer()
                            Button("Done") {
                                if logger.isEditingRecorded ? logger.finishEditing() : logger.closeNumberEditor() { recovery.accept() }
                            }.frame(minHeight: 44)
                        }
                    }.padding(24)
                } else if logger.isEditingRecorded {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Recovered entry").font(.system(size: 32, design: .serif).italic())
                            Text(logger.exercise.name).font(.title2)
                            SetRowsView(model: logger)
                        }.padding(24)
                    }.safeAreaInset(edge: .bottom) { NumericDock(model: logger, onComplete: { recovery.accept() }) }
                } else {
                    VStack(spacing: 18) {
                        Text("Save recovered changes").font(.system(.title, design: .serif))
                        Button("Try again") { recovery.accept() }.frame(minHeight: 44)
                    }.padding(24)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if let error = recovery.errorMessage { Text(error).font(.callout).foregroundStyle(NotebookStyle.clay).padding(16) }
        }
        .onChange(of: recovery.logger?.numberInputText) { _, _ in recovery.flushRecovery() }
        .onChange(of: recovery.logger?.editor) { _, _ in recovery.flushRecovery() }
        .onChange(of: recovery.logger?.phase) { _, _ in recovery.flushRecovery() }
        .onChange(of: recovery.logger?.selectedSetIndex) { _, _ in recovery.flushRecovery() }
        .onChange(of: recovery.logger?.selectedField) { _, _ in recovery.flushRecovery() }
        .onChange(of: recovery.logger?.selectedWeightUnit) { _, _ in recovery.flushRecovery() }
        .onChange(of: recovery.isComplete) { _, done in if done { finished() } }
    }
}
