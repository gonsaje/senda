import Foundation
import Observation
import SendaDomain
import SendaPersistence

@Observable @MainActor public final class TrainingSession {
    public private(set) var notebook: TrainingNotebookModel?
    public private(set) var recovery: LegacyRecoveryModel?
    public private(set) var openingError: String?
    public private(set) var backupErrorMessage: String?
    @ObservationIgnored private let restoreStore: any NotebookRestoreStore
    @ObservationIgnored private let repository: any JournalRepository
    @ObservationIgnored private let profileRepository: any ProfileRepository
    public let isSample: Bool
    public init(repository: any JournalRepository, isSample: Bool = false, profileRepository: (any ProfileRepository)? = nil,
                restoreStore: (any NotebookRestoreStore)? = nil) {
        let profileRepository = profileRepository ?? MemoryProfileRepository()
        self.profileRepository = profileRepository
        self.restoreStore = restoreStore ?? MemoryNotebookRestoreStore(repository: repository, profileRepository: profileRepository)
        self.repository = repository; self.isSample = isSample; open()
    }
    public func open() {
        do {
            try restoreStore.recoverInterruptedRestore()
            let saved = try repository.loadSnapshot().validated()
            if TrainingWorkspace.requiresLegacyReview(saved) {
                let review = try LegacyRecoveryModel(repository: repository)
                if review.isComplete { recovery = nil; notebook = try TrainingNotebookModel(repository: repository, isSample: isSample, profileRepository: profileRepository, restoreStore: restoreStore) }
                else { notebook = nil; recovery = review }
            } else { recovery = nil; notebook = try TrainingNotebookModel(repository: repository, isSample: isSample, profileRepository: profileRepository, restoreStore: restoreStore) }
            openingError = nil
        } catch { notebook = nil; recovery = nil; openingError = error.localizedDescription }
    }
    public func previousBackupData() throws -> Data? { try restoreStore.previousBackupData() }
    public func previousOriginalFilesData() throws -> Data? { try restoreStore.previousOriginalFilesData() }
    public func originalJournalData() throws -> Data? { try restoreStore.originalJournalData() }
    @discardableResult public func restoreBackup(_ archive: NotebookArchive) -> Bool {
        if let notebook {
            let restored = notebook.restoreBackup(archive)
            backupErrorMessage = notebook.backupErrorMessage
            return restored
        }
        do {
            let archive = try archive.validated()
            try restoreStore.restore(archive, current: nil)
            open()
            guard notebook != nil else {
                backupErrorMessage = openingError ?? "The restored notebook could not be opened."
                return false
            }
            backupErrorMessage = nil
            return true
        } catch { backupErrorMessage = error.localizedDescription; open(); return false }
    }
    public func suspend() {
        if let recovery { _ = recovery.flushRecovery() }
        else if let notebook {
            guard !notebook.backupRecoveryRequired else { return }
            // A lifecycle flush must replay a failed intended action before creating
            // a new boundary transaction that would supersede its destination.
            if notebook.canRetrySave && !notebook.flushRecovery() { return }
            _ = notebook.finishEditing()
            _ = notebook.flushRecovery()
        }
    }
}
