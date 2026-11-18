import SwiftUI
import UniformTypeIdentifiers
import SendaLogger

struct TrainingAutomaticBackupSettings: View {
    let backup: NotebookAutomaticBackup
    let model: TrainingNotebookModel
    @State private var showsFolderPicker = false
    @State private var selectionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Automatic backups")
                .font(NotebookTypography.heading(22, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            if let folder = backup.folderName {
                Text(folder).font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("backup-folder-name")
                if let date = backup.lastSavedAt {
                    detail("Last saved \(date.formatted(date: .abbreviated, time: .shortened))")
                        .accessibilityIdentifier("automatic-backup-last-saved")
                }
                action("Back up now", id: "automatic-backup-now", perform: backUpNow)
                if backup.isSaving {
                    ProgressView("Saving backup…").font(.subheadline)
                }
                action("Change folder", id: "change-backup-folder", perform: chooseFolder)
                action("Turn off automatic backups", id: "disable-automatic-backup") {
                    selectionError = nil
                    backup.turnOff()
                }
            } else {
                detail("Choose a folder in Files, such as iCloud Drive. Backups include your workouts and profile details. Senda checks for changes while you use the app and saves up to one copy a day.")
                action("Choose backup folder", id: "choose-backup-folder", perform: chooseFolder)
            }
            if let error = selectionError ?? backup.errorMessage {
                Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("automatic-backup-error")
            }
        }
        .fileImporter(isPresented: $showsFolderPicker, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let folder):
                if backup.chooseFolder(folder) { backUpNow() }
                else if let error = backup.errorMessage { TrainingAccessibility.announce(error) }
            case .failure(let error):
                let failure = error as NSError
                guard failure.domain != NSCocoaErrorDomain || failure.code != NSUserCancelledError else { return }
                let message = "Couldn’t open the backup folder. " + error.localizedDescription
                selectionError = message
                TrainingAccessibility.announce(message)
            }
        }
        .onChange(of: showsFolderPicker) { _, isOpen in
            if !isOpen { backup.isChoosingFolder = false }
        }
        .onDisappear { backup.isChoosingFolder = false }
    }

    private func detail(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func action(_ title: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.clay)
        .disabled(backup.isSaving)
        .accessibilityIdentifier(id)
    }

    private func chooseFolder() {
        selectionError = nil
        backup.isChoosingFolder = true
        showsFolderPicker = true
    }

    private func backUpNow() {
        selectionError = nil
        Task {
            let saved = await backup.backUpNow { try model.backupArchive() }
            if let error = backup.errorMessage { TrainingAccessibility.announce(error) }
            else if saved { TrainingAccessibility.announce("Backup saved to the selected folder.") }
        }
    }
}
