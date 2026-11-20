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
    @ObservationIgnored private let health: (any BodyMeasurementsHealthSource)?
    public struct Demo {
        public let session: TrainingSession
        public let preferences: UserDefaults
    }
    public private(set) var demo: Demo?
    private static let demoPreferencesDomain = "com.senda.journal.sample-preferences"
    public let isSample: Bool
    public init(repository: any JournalRepository, isSample: Bool = false, profileRepository: (any ProfileRepository)? = nil,
                restoreStore: (any NotebookRestoreStore)? = nil, health: (any BodyMeasurementsHealthSource)? = nil) {
        self.health = health
        let profileRepository = profileRepository ?? MemoryProfileRepository()
        self.profileRepository = profileRepository
        self.restoreStore = restoreStore ?? MemoryNotebookRestoreStore(repository: repository, profileRepository: profileRepository)
        self.repository = repository; self.isSample = isSample; open()
    }
    public static func sample() throws -> TrainingSession {
        let repository = MemoryJournalRepository(journal: try SampleJournal.makeTwelveWeeks())
        let profile = MemoryProfileRepository()
        try profile.save(ProfileDetails(goals: [
            StrengthGoal(exerciseID: "bench", target: SetValues(weight: 15_500, reps: 8)),
            StrengthGoal(exerciseID: "deadlift", target: SetValues(weight: 21_500, reps: 5))
        ]))
        let session = TrainingSession(repository: repository, isSample: true, profileRepository: profile)
        guard session.notebook != nil else { throw TrainingError.invalidWorkspace }
        return session
    }

    public func openDemo() throws {
        guard !isSample, demo == nil else { return }
        let session = try Self.sample()
        guard let preferences = UserDefaults(suiteName: Self.demoPreferencesDomain) else {
            throw CocoaError(.fileReadUnknown)
        }
        preferences.removePersistentDomain(forName: Self.demoPreferencesDomain)
        demo = Demo(session: session, preferences: preferences)
    }

    public func closeDemo() {
        demo?.preferences.removePersistentDomain(forName: Self.demoPreferencesDomain)
        demo = nil
    }

    public func open() {
        do {
            try restoreStore.recoverInterruptedRestore()
            let saved = try repository.loadSnapshot().validated()
            if TrainingWorkspace.requiresLegacyReview(saved) {
                let review = try LegacyRecoveryModel(repository: repository)
                if review.isComplete { recovery = nil; notebook = try TrainingNotebookModel(repository: repository, isSample: isSample, profileRepository: profileRepository, restoreStore: restoreStore, health: health) }
                else { notebook = nil; recovery = review }
            } else { recovery = nil; notebook = try TrainingNotebookModel(repository: repository, isSample: isSample, profileRepository: profileRepository, restoreStore: restoreStore, health: health) }
            openingError = nil
        } catch { notebook = nil; recovery = nil; openingError = error.localizedDescription }
    }
    public func previousBackupData() throws -> Data? { try restoreStore.previousBackupData() }
    public func previousBackupArchive() async throws -> NotebookArchive? { try await restoreStore.previousBackupArchive() }
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
        if let demo { demo.session.suspend(); return }
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
