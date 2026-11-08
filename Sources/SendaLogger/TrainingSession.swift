import Foundation
import Observation
import SendaDomain
import SendaPersistence

@Observable @MainActor public final class TrainingSession {
    public private(set) var notebook: TrainingNotebookModel?
    public private(set) var recovery: LegacyRecoveryModel?
    public private(set) var openingError: String?
    @ObservationIgnored private let repository: any JournalRepository
    @ObservationIgnored private let profileRepository: any ProfileRepository
    public let isSample: Bool
    public init(repository: any JournalRepository, isSample: Bool = false, profileRepository: (any ProfileRepository)? = nil) {
        self.profileRepository = profileRepository ?? MemoryProfileRepository()
        self.repository = repository; self.isSample = isSample; open()
    }
    public func open() {
        do {
            let saved = try repository.loadSnapshot().validated()
            if TrainingWorkspace.requiresLegacyReview(saved) {
                let review = try LegacyRecoveryModel(repository: repository)
                if review.isComplete { recovery = nil; notebook = try TrainingNotebookModel(repository: repository, isSample: isSample, profileRepository: profileRepository) }
                else { notebook = nil; recovery = review }
            } else { recovery = nil; notebook = try TrainingNotebookModel(repository: repository, isSample: isSample, profileRepository: profileRepository) }
            openingError = nil
        } catch { openingError = error.localizedDescription }
    }
    public func suspend() {
        if let recovery { _ = recovery.flushRecovery() }
        else if let notebook { _ = notebook.finishEditing(); _ = notebook.flushRecovery() }
    }
}
