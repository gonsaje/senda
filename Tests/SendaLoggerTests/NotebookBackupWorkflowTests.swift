import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct NotebookBackupWorkflowTests {
    private func notebook(_ repository: any JournalRepository = MemoryJournalRepository(), profile: (any ProfileRepository)? = nil,
                          restore: (any NotebookRestoreStore)? = nil) throws -> TrainingNotebookModel {
        try TrainingNotebookModel(repository: repository, profileRepository: profile, restoreStore: restore)
    }
    private func input(_ model: TrainingNotebookModel, weight: String, reps: String) throws {
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .weight)); model.typeInput(weight, focus: try #require(model.focus))
        #expect(model.selectInput(row.id, field: .reps)); model.typeInput(reps, focus: try #require(model.focus))
    }
    @Test func exportingCapturesUnfinishedInputWithoutFinalizingIt() throws {
        let profile = MemoryProfileRepository(); try profile.save(ProfileDetails(name: "Jae", email: "legacy@example.com"))
        let model = try notebook(profile: profile)
        try input(model, weight: "31.", reps: "8")
        let before = model.snapshot
        let archive = try NotebookBackupCodec.decode(model.backupData())
        #expect(archive.snapshot == before && archive.profile == model.profile.details)
        #expect(model.snapshot == before && model.journal.batches.isEmpty)
        let csv = try #require(String(data: try model.csvData(), encoding: .utf8))
        #expect(csv.split(separator: "\n").count == 1)
    }
    @Test func successfulRestoreReplacesDataAndRetainsPreviousNotebook() throws {
        let source = try notebook(); try input(source, weight: "135", reps: "10"); #expect(source.finishEditing())
        #expect(source.setPreferredUnit(.kilograms)); #expect(source.profile.saveName("Source"))
        let archive = try NotebookBackupCodec.decode(source.backupData())
        let store = MemoryJournalRepository(), profile = MemoryProfileRepository()
        let target = try notebook(store, profile: profile)
        try input(target, weight: "99.", reps: "")
        #expect(target.profile.saveName("Target"))
        let before = target.snapshot
        #expect(target.restoreBackup(archive))
        #expect(target.snapshot == archive.snapshot && target.profile.details.name == "Source")
        #expect(target.workspace.preferredUnit == .kilograms && target.canRetrySave == false)
        let previous = try NotebookBackupCodec.decode(#require(try target.previousBackupData()))
        #expect(previous.snapshot == before && previous.profile.name == "Target")
        let reopened = try notebook(store, profile: profile)
        #expect(reopened.snapshot == archive.snapshot && reopened.profile.details == archive.profile)
    }
    @Test func restoredNotebookCannotReplayOldFailedNavigation() throws {
        let source = try notebook(); let archive = try NotebookBackupCodec.decode(source.backupData())
        let store = BackupWorkflowFailureJournal()
        let target = try notebook(store)
        try input(target, weight: "135", reps: "10")
        store.reject = true
        #expect(!target.changeDay(1) && target.canRetrySave)
        store.reject = false
        #expect(target.restoreBackup(archive))
        #expect(!target.canRetrySave && target.retrySave())
        #expect(target.snapshot == archive.snapshot && target.journal.batches.isEmpty)
    }
    @Test func invalidArchiveNeverReachesRestoreStorage() throws {
        let store = BackupWorkflowRestoreStore()
        let target = try notebook(restore: store), before = target.snapshot
        let invalid = NotebookArchive(snapshot: JournalSnapshot(), profile: ProfileDetails())
        #expect(!target.restoreBackup(invalid))
        #expect(store.restoreCalls == 0 && target.snapshot == before && target.backupErrorMessage != nil)
    }
    @Test func failedRollbackBlocksLoggingUntilRecoverySucceeds() throws {
        let store = BackupWorkflowRestoreStore()
        let target = try notebook(restore: store), before = target.snapshot
        let archive = try NotebookBackupCodec.decode(target.backupData())
        store.rejectRestore = true; store.rejectRecovery = true
        #expect(!target.restoreBackup(archive) && target.backupRecoveryRequired)
        #expect(target.snapshot == before && !target.openToday())
        #expect(!target.retryBackupRecovery())
        store.rejectRecovery = false
        #expect(target.retryBackupRecovery() && !target.backupRecoveryRequired)
        #expect(target.openToday())
    }
    @Test func nameOnlySavePreservesLegacyStoredEmail() throws {
        let store = MemoryProfileRepository(); try store.save(ProfileDetails(name: "Old", email: "legacy@example.com"))
        let model = ProfileModel(repository: store)
        #expect(model.saveName(" New name "))
        #expect(try store.load() == ProfileDetails(name: "New name", email: "legacy@example.com"))
    }
    @Test func unreadableProfileCannotExportAnIncompleteFullBackup() throws {
        let profile = BackupWorkflowFailureProfile()
        let target = try notebook(profile: profile)
        #expect(target.profile.openingError != nil)
        #expect(throws: (any Error).self) { try target.backupData() }
        #expect(try target.csvData().isEmpty == false)
    }
    @Test func unreadableProfileMustProtectVisibleDraftBeforeReplacement() throws {
        let journal = BackupWorkflowFailureJournal(), restore = BackupWorkflowRestoreStore()
        let target = try notebook(journal, profile: BackupWorkflowFailureProfile(), restore: restore)
        try input(target, weight: "31.", reps: "8")
        journal.reject = true
        let archive = try NotebookBackupCodec.decode(notebook().backupData())
        let before = target.snapshot
        #expect(!target.restoreBackup(archive))
        #expect(target.snapshot == before && restore.restoreCalls == 0)
    }
    @Test func failedRestoreAfterDraftProtectionKeepsPersistenceBaselineCurrent() throws {
        let journal = BackupWorkflowFailureJournal(), restore = BackupWorkflowRestoreStore()
        let target = try notebook(journal, profile: BackupWorkflowFailureProfile(), restore: restore)
        #expect(target.openToday()); #expect(target.addExercise("bench"))
        let row = try #require(target.rows.first)
        #expect(target.selectInput(row.id, field: .weight))
        let focus = try #require(target.focus)
        target.typeInput("0", focus: focus)
        journal.reject = true; target.typeInput("135", focus: focus)
        journal.reject = false; restore.rejectRestore = true
        let archive = try NotebookBackupCodec.decode(notebook().backupData())
        #expect(!target.restoreBackup(archive))
        target.typeInput("0", focus: focus)
        #expect(try journal.loadSnapshot() == target.snapshot)
    }
    @Test func restoreMakesHiddenLegacyExercisesReachableImmediately() throws {
        let target = try notebook(), day = target.today
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: "legacy-lift", sets: [SetValues(weight: 13500, reps: 10)]), at: day.date())
        var training = try TrainingWorkspace.migrate(JournalSnapshot(journal: journal), today: day, calendar: .current)
        training.legacyExerciseIDs = nil
        training.days[day.rawValue]!.exerciseIDs = []
        training.days[day.rawValue]!.selectedExerciseID = nil
        let archive = NotebookArchive(snapshot: JournalSnapshot(journal: journal, training: training), profile: ProfileDetails())
        #expect(target.restoreBackup(archive)); #expect(target.openDay(day))
        #expect(target.addExercise("legacy-lift"))
        #expect(target.rows.first?.performedSetID == journal.batches.first?.sets.first?.id)
    }
    @Test func openingErrorRestoreKeepsOriginalFilesExportable() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journalURL = directory.appendingPathComponent("journal.json"), profileURL = directory.appendingPathComponent("profile.json")
        let originalJournal = Data("damaged journal".utf8), originalProfile = Data("damaged profile".utf8)
        try originalJournal.write(to: journalURL); try originalProfile.write(to: profileURL)
        let session = TrainingSession(repository: FileJournalRepository(url: journalURL),
            profileRepository: FileProfileRepository(url: profileURL),
            restoreStore: FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL))
        #expect(session.notebook == nil && session.openingError != nil)
        let source = try notebook(); try input(source, weight: "31.", reps: "8")
        let archive = try NotebookBackupCodec.decode(source.backupData())
        #expect(session.restoreBackup(archive) && session.notebook?.snapshot == archive.snapshot)
        let data = try #require(try session.previousOriginalFilesData())
        let pair = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let journal = try #require(pair["journal"] as? [String: Any]), profile = try #require(pair["profile"] as? [String: Any])
        #expect(Data(base64Encoded: try #require(journal["contents"] as? String)) == originalJournal)
        #expect(Data(base64Encoded: try #require(profile["contents"] as? String)) == originalProfile)
        #expect(try session.previousBackupData() == nil)
    }
    @Test func sessionRecoversBeforeOpeningAndExposesOriginalFile() throws {
        let store = BackupWorkflowRestoreStore()
        let session = TrainingSession(repository: MemoryJournalRepository(), restoreStore: store)
        #expect(store.recoveryCalls >= 1 && session.notebook != nil)
        #expect(try session.originalJournalData() == Data("original".utf8))
        store.rejectRecovery = true
        session.open()
        #expect(session.notebook == nil && session.openingError != nil)
    }
}
@MainActor private final class BackupWorkflowFailureJournal: JournalRepository {
    private var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }; snapshot = try next.validated()
    }
}
@MainActor private final class BackupWorkflowFailureProfile: ProfileRepository {
    func load() throws -> ProfileDetails { throw CocoaError(.fileReadCorruptFile) }
    func save(_ details: ProfileDetails) throws { throw CocoaError(.fileWriteUnknown) }
}
@MainActor private final class BackupWorkflowRestoreStore: NotebookRestoreStore {
    var recoveryCalls = 0, restoreCalls = 0
    var rejectRecovery = false, rejectRestore = false
    func recoverInterruptedRestore() throws {
        recoveryCalls += 1
        if rejectRecovery { throw CocoaError(.fileWriteUnknown) }
    }
    func restore(_ archive: NotebookArchive, current: NotebookArchive?) throws {
        restoreCalls += 1
        if rejectRestore { throw CocoaError(.fileWriteUnknown) }
    }
    func previousBackupData() throws -> Data? { nil }
    func originalJournalData() throws -> Data? { Data("original".utf8) }
}
