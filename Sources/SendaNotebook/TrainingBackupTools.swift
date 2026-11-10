import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SendaDomain
import SendaPersistence

/// The same recovery tools work in Settings and when the saved notebook cannot open.
@MainActor
struct NotebookBackupTools: View {
    let showsHeading: Bool
    let exportBackup: (() throws -> Data)?
    let exportCSV: (() throws -> Data)?
    let previousBackup: () throws -> Data?
    let previousOriginalFiles: (() throws -> Data?)?
    let originalJournal: (() throws -> Data?)?
    let restore: (NotebookArchive) -> String?

    @State private var showsImporter = false
    @State private var showsExporter = false
    @State private var showsRestoreConfirmation = false
    @State private var exportDocument: NotebookExportDocument?
    @State private var exportKind = NotebookExportKind.backup
    @State private var preview: NotebookArchive?
    @State private var isReading = false
    @State private var importTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    init(
        showsHeading: Bool = true,
        exportBackup: (() throws -> Data)? = nil,
        exportCSV: (() throws -> Data)? = nil,
        previousBackup: @escaping () throws -> Data?,
        previousOriginalFiles: (() throws -> Data?)? = nil,
        originalJournal: (() throws -> Data?)? = nil,
        restore: @escaping (NotebookArchive) -> String?
    ) {
        self.showsHeading = showsHeading
        self.exportBackup = exportBackup
        self.exportCSV = exportCSV
        self.previousBackup = previousBackup
        self.previousOriginalFiles = previousOriginalFiles
        self.originalJournal = originalJournal
        self.restore = restore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsHeading {
                Text("Backup & restore").font(NotebookTypography.heading(22)).accessibilityAddTraits(.isHeader)
            }
            Text("Your notebook is stored on this device and does not sync automatically. Save a full backup somewhere you can find it, such as Files or iCloud Drive.")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
            if let exportBackup {
                action("Save full backup", icon: "square.and.arrow.up", identifier: "export-backup") {
                    prepareExport(.backup, data: exportBackup)
                }
                Text("A full backup includes recorded workouts, custom exercises, unfinished rows, units, your optional local name, and any profile details saved by earlier versions. Senda does not encrypt backup files.")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
            }
            if let exportCSV {
                action("Export recorded sets (CSV)", icon: "tablecells", identifier: "export-csv") {
                    prepareExport(.csv, data: exportCSV)
                }
                Text("CSV is for viewing recorded sets in a spreadsheet. Use a full backup to restore your notebook.")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
            action("Choose backup to restore", icon: "square.and.arrow.down", identifier: "restore-import") {
                errorMessage = nil
                statusMessage = nil
                preview = nil
                showsImporter = true
            }
            Text("Choose a Senda full backup (.json, up to 50 MB). You can review it before replacing anything.")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
            if isReading {
                ProgressView("Checking backup…").font(.subheadline).accessibilityIdentifier("restore-checking")
            }
            if let preview {
                VStack(alignment: .leading, spacing: 16) {
                    NotebookRestorePreview(archive: preview)
                    Text("Restoring replaces the current notebook and local details; it does not merge them. Senda keeps a pre-restore copy on this device before making the change.")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
                    Button { showsRestoreConfirmation = true } label: {
                        Text("Restore this backup").fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(NotebookStyle.ivory)
                            .background(NotebookStyle.clay, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .disabled(isReading).accessibilityIdentifier("restore-preview-confirm")
                    Button { self.preview = nil; errorMessage = nil } label: {
                        Text("Cancel restore").frame(minWidth: 44, minHeight: 44)
                    }.accessibilityIdentifier("restore-preview-cancel")
                }
                .padding(16).background(NotebookStyle.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            }
            action("Save pre-restore copy", icon: "clock.arrow.circlepath", identifier: "export-pre-restore-backup") {
                preparePreviousCopyExport()
            }
            if let originalJournal {
                action("Save original notebook file", icon: "doc", identifier: "export-original-notebook") {
                    prepareOptionalExport(.original, missing: "There is no original notebook file to save.", data: originalJournal)
                }
                Text("Keeps an unchanged copy of the saved file for recovery, even if Senda cannot open it.")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
            }
            if let errorMessage {
                Text(errorMessage).font(.callout).foregroundStyle(NotebookStyle.clay)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("backup-error")
            }
            if let statusMessage {
                Text(statusMessage).font(.callout).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("backup-status")
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json], allowsMultipleSelection: false, onCompletion: importSelectedFile)
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: exportKind.contentType,
            defaultFilename: exportKind.filename,
            onCompletion: exportFinished
        )
        .confirmationDialog("Replace this notebook?", isPresented: $showsRestoreConfirmation, titleVisibility: .visible) {
            Button("Replace notebook", role: .destructive, action: confirmRestore)
                .accessibilityIdentifier("restore-final-confirm")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the current notebook with the reviewed backup. A pre-restore copy will be kept on this device.")
        }
        .onDisappear { importTask?.cancel() }
    }

    private func action(_ title: String, icon: String, identifier: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: icon).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.clay).disabled(isReading).accessibilityIdentifier(identifier)
    }

    private func prepareExport(_ kind: NotebookExportKind, data: () throws -> Data) {
        errorMessage = nil
        statusMessage = nil
        do {
            exportDocument = NotebookExportDocument(data: try data())
            exportKind = kind
            showsExporter = true
        } catch { reportError(error.localizedDescription) }
    }

    private func prepareOptionalExport(_ kind: NotebookExportKind, missing: String, data: () throws -> Data?) {
        errorMessage = nil
        statusMessage = nil
        do {
            guard let bytes = try data() else {
                statusMessage = missing
                TrainingAccessibility.announce(missing)
                return
            }
            prepareExport(kind, data: { bytes })
        } catch { reportError(error.localizedDescription) }
    }

    private func preparePreviousCopyExport() {
        errorMessage = nil
        statusMessage = nil
        do {
            if let data = try previousBackup() {
                prepareExport(.previous, data: { data })
            } else if let data = try previousOriginalFiles?() {
                prepareExport(.originalRecovery, data: { data })
            } else {
                let message = "There is no pre-restore copy yet. Senda keeps one when you restore a backup."
                statusMessage = message
                TrainingAccessibility.announce(message)
            }
        } catch { reportError(error.localizedDescription) }
    }

    private func exportFinished(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            statusMessage = exportKind.successMessage
            TrainingAccessibility.announce(exportKind.successMessage)
        case .failure(let error):
            if !NotebookBackupImport.isCancellation(error) { reportError(error.localizedDescription) }
        }
        exportDocument = nil
    }

    private func importSelectedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            if !NotebookBackupImport.isCancellation(error) { reportError(error.localizedDescription) }
        case .success(let urls):
            guard let url = urls.first else { return }
            importTask?.cancel()
            isReading = true
            importTask = Task { @MainActor in
                defer { isReading = false; importTask = nil }
                do {
                    let archive = try await NotebookBackupImport.readArchive(at: url)
                    try Task.checkCancellation()
                    preview = archive
                    errorMessage = nil
                    statusMessage = nil
                    TrainingAccessibility.announce("Backup checked. Review the contents before restoring.")
                } catch {
                    if !NotebookBackupImport.isCancellation(error) { reportError(error.localizedDescription) }
                }
            }
        }
    }

    private func confirmRestore() {
        guard let preview else { return }
        errorMessage = nil
        statusMessage = nil
        if let error = restore(preview) { reportError(error) }
        else {
            self.preview = nil
            let message = "Notebook restored. A pre-restore copy is saved on this device."
            statusMessage = message
            TrainingAccessibility.announce(message)
        }
    }

    private func reportError(_ message: String) {
        errorMessage = message
        statusMessage = nil
        TrainingAccessibility.announce(message)
    }
}

public struct NotebookRestorePreview: View {
    let archive: NotebookArchive

    public init(archive: NotebookArchive) { self.archive = archive }

    private var snapshot: JournalSnapshot { archive.snapshot }
    private var recordedDays: Int {
        guard let training = snapshot.training else {
            return Set(snapshot.journal.batches.map { TrainingDay($0.recordedAt, calendar: .current).rawValue }).count
        }
        return training.days.values.filter { $0.rows.values.contains { $0.contains { $0.performedSetID != nil } } }.count
    }
    private var recordedSets: Int {
        guard let training = snapshot.training else {
            return snapshot.journal.batches.reduce(0) { $0 + $1.sets.count }
        }
        return training.days.values.reduce(0) { count, day in
            count + day.rows.values.reduce(0) { count, rows in
                count + TrainingSetEntry.grouping(rows).filter { entry in
                    entry.rows.contains { $0.performedSetID != nil }
                }.count
            }
        }
    }
    private var unfinishedRows: Int {
        guard let training = snapshot.training else { return legacyUnfinishedRows }
        let exercises = Dictionary(uniqueKeysWithValues: (Exercise.catalog + (snapshot.customExercises ?? [])).map { ($0.id, $0) })
        let recordedValues = Dictionary(uniqueKeysWithValues: snapshot.journal.batches.flatMap { $0.sets.map { ($0.id, $0.values) } })
        return training.days.values.reduce(0) { count, day in
            count + day.rows.reduce(0) { count, item in
                let exercise = exercises[item.key] ?? Exercise(id: item.key, name: item.key, shortName: item.key, startingWeight: 0)
                return count + TrainingSetEntry.grouping(item.value).filter { entry in
                    entry.rows.contains { row in
                        if let setID = row.performedSetID {
                            return row.pendingCorrection == true || row.parsed(for: exercise) != recordedValues[setID]
                        }
                        return !row.weight.isEmpty || !row.reps.isEmpty
                    }
                }.count
            }
        }
    }
    private var legacyUnfinishedRows: Int {
        guard let workspace = snapshot.workspace else { return 0 }
        return workspace.sessions.reduce(0) { count, item in
            if item.key == workspace.selectedExerciseID, let editor = workspace.editor { return count + editor.inputs.count }
            switch item.value {
            case .draft(let draft): return count + draft.sets.count
            case .editing(let edit): return count + edit.sets.count
            case .recorded: return count
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review backup").font(NotebookTypography.heading(25)).accessibilityAddTraits(.isHeader)
            summary("Created", value: archive.createdAt.formatted(date: .abbreviated, time: .shortened))
            summary("Recorded workout days", value: String(recordedDays))
            summary("Recorded sets", value: String(recordedSets))
            summary("Custom exercises", value: String(snapshot.customExercises?.count ?? 0))
            summary("Unfinished rows", value: String(unfinishedRows))
            let unit = snapshot.training?.preferredUnit ?? snapshot.workspace?.weightUnit ?? .pounds
            summary("Weight units", value: unit == .pounds ? "Pounds (lb)" : "Kilograms (kg)")
            summary("Local name", value: archive.profile.name.isEmpty ? "None" : archive.profile.name)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("restore-preview")
    }

    private func summary(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title).foregroundStyle(NotebookStyle.quiet)
            Spacer(minLength: 0)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline).fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
}

private struct NotebookExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private enum NotebookExportKind {
    case backup, csv, previous, original, originalRecovery
    var contentType: UTType { self == .csv ? .commaSeparatedText : .json }
    var filename: String {
        let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        switch self {
        case .backup: return "senda-backup-\(date).json"
        case .csv: return "senda-recorded-sets-\(date).csv"
        case .previous: return "senda-before-restore-\(date).json"
        case .original: return "senda-original-notebook-\(date).json"
        case .originalRecovery: return "senda-before-restore-original-files-\(date).json"
        }
    }
    var successMessage: String {
        switch self {
        case .backup: "Full backup saved."
        case .csv: "Recorded sets exported."
        case .previous: "Pre-restore backup saved."
        case .original: "Original notebook file saved."
        case .originalRecovery: "Pre-restore original files saved for recovery. This copy cannot be restored as a Senda full backup."
        }
    }
}

private enum NotebookBackupImport {
    static func readArchive(at url: URL) async throws -> NotebookArchive {
        try await Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { throw ImportError.notAFile }
            let limit = NotebookBackupCodec.maxImportBytes
            guard let size = values.fileSize, size <= limit else { throw ImportError.tooLarge }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let data = try file.read(upToCount: limit + 1) ?? Data()
            guard data.count <= limit else { throw ImportError.tooLarge }
            return try NotebookBackupCodec.decode(data)
        }.value
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }

    private enum ImportError: LocalizedError {
        case notAFile, tooLarge
        var errorDescription: String? {
            switch self {
            case .notAFile: "Choose a regular Senda backup file."
            case .tooLarge: "Choose a backup smaller than 50 MB."
            }
        }
    }
}
