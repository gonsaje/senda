import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingSessionView: View {
    @Bindable private var session: TrainingSession
    @Environment(\.scenePhase) private var scenePhase
    private let automaticBackup: NotebookAutomaticBackup?

    public init(session: TrainingSession, automaticBackup: NotebookAutomaticBackup? = nil) {
        self.session = session
        self.automaticBackup = automaticBackup
    }

    public var body: some View {
        Group {
            if let recovery = session.recovery {
                LegacyTrainingRecoveryView(recovery: recovery, finished: session.open)
            } else if let model = session.notebook {
                if let automaticBackup {
                    let trigger = backupTrigger(model: model, backup: automaticBackup)
                    TrainingNotebookView(model: model)
                        .environment(automaticBackup)
                        .task(id: trigger) {
                            guard trigger != nil else { return }
                            do { try await Task.sleep(for: .seconds(4)) }
                            catch { return }
                            await automaticBackup.backUpWhenDue { try model.backupArchive() }
                        }
                } else {
                    TrainingNotebookView(model: model)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Your notebook couldn’t be opened.").font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                        Text(session.openingError ?? "Try opening it again.")
                        Text("Your saved file has been preserved. Save a copy before restoring a backup.").font(.callout)
                        Button("Try again", action: session.open).frame(minHeight: 44)
                        NotebookBackupTools(previousBackup: { try session.previousBackupData() },
                            previousArchive: { try await session.previousBackupArchive() },
                            previousOriginalFiles: { try session.previousOriginalFilesData() },
                            originalJournal: { try session.originalJournalData() },
                            restore: { archive in session.restoreBackup(archive) ? nil : session.backupErrorMessage ?? "Could not restore the backup." })
                    }.padding(28).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
            }
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
    }

    private struct BackupTrigger: Equatable {
        let folderName: String
        let snapshot: JournalSnapshot
        let profile: ProfileDetails
    }

    private func backupTrigger(model: TrainingNotebookModel, backup: NotebookAutomaticBackup) -> BackupTrigger? {
        guard scenePhase == .active, !backup.isChoosingFolder, let folderName = backup.folderName else { return nil }
        return BackupTrigger(folderName: folderName, snapshot: model.snapshot, profile: model.profile.details)
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
                        Text("Recovered entry").font(NotebookTypography.heading(32))
                        Text(logger.exercise.displayName).font(.title2)
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
                            Text("Recovered entry").font(NotebookTypography.heading(32))
                            Text(logger.exercise.displayName).font(.title2)
                            SetRowsView(model: logger)
                        }.padding(24)
                    }.safeAreaInset(edge: .bottom) { NumericDock(model: logger, onComplete: { recovery.accept() }) }
                } else {
                    VStack(spacing: 18) {
                        Text("Save recovered changes").font(NotebookTypography.heading(28))
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
