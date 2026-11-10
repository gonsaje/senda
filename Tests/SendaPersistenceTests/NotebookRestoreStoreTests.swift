import Foundation
import Testing
import SendaDomain
@testable import SendaPersistence

@MainActor struct NotebookRestoreStoreTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("senda-restore-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func archive(name: String, weight: Int = 13_500) throws -> NotebookArchive {
        let day = try TrainingDay("2026-11-09")
        var journal = Journal()
        let set = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: weight, reps: 8)]), at: day.date()).sets[0]
        let row = TrainingRow(set: set, unit: .kilograms)
        let workspace = TrainingWorkspace(visibleWeek: try day.week()[0], selectedDay: day, preferredUnit: .kilograms,
            days: [day.rawValue: DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": [row]], unit: .kilograms)])
        return NotebookArchive(snapshot: JournalSnapshot(journal: journal, training: workspace),
            profile: ProfileDetails(name: name, email: "previous@example.com"), createdAt: day.date())
    }
    private func seed(_ archive: NotebookArchive, journal: URL, profile: URL) throws {
        try FileJournalRepository(url: journal).saveSnapshot(archive.snapshot)
        try FileProfileRepository(url: profile).save(archive.profile)
    }

    @Test func fileRestoreReplacesBothFilesAndRetainsTheLatestCurrentArchive() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let old = try archive(name: "Before"), target = try archive(name: "After", weight: 14_000)
        try seed(old, journal: journalURL, profile: profileURL)
        var latestSnapshot = old.snapshot
        let day = try TrainingDay("2026-11-09")
        latestSnapshot.training!.days[day.rawValue]!.rows["bench"]!.append(TrainingRow(weight: "31.", unit: .kilograms, weightIsDirty: true))
        let latest = NotebookArchive(snapshot: latestSnapshot, profile: old.profile, createdAt: old.createdAt)
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        try store.restore(target, current: latest)
        #expect(try FileJournalRepository(url: journalURL).loadSnapshot() == target.snapshot)
        #expect(try FileProfileRepository(url: profileURL).load() == target.profile)
        #expect(try NotebookBackupCodec.decode(#require(try store.previousBackupData())) == latest)
        #expect(!FileManager.default.fileExists(atPath: store.pendingURL.path))
        try store.recoverInterruptedRestore()
        #expect(try FileJournalRepository(url: journalURL).loadSnapshot() == target.snapshot)
    }

    @Test func invalidTargetCannotOverwriteJournalProfileOrProtectedBackup() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let first = try archive(name: "First"), second = try archive(name: "Second")
        try seed(first, journal: journalURL, profile: profileURL)
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        try store.restore(second, current: first)
        let protected = try store.previousBackupData(), journal = try Data(contentsOf: journalURL), profile = try Data(contentsOf: profileURL)
        let invalid = NotebookArchive(snapshot: second.snapshot, profile: ProfileDetails(name: String(repeating: "x", count: 81)))
        #expect(throws: (any Error).self) { try store.restore(invalid, current: second) }
        #expect(try store.previousBackupData() == protected)
        #expect(try Data(contentsOf: journalURL) == journal)
        #expect(try Data(contentsOf: profileURL) == profile)
    }

    @Test func invalidCurrentArchiveAlsoLeavesTheProtectedPointUntouched() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        try seed(old, journal: journalURL, profile: profileURL)
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        let invalidCurrent = NotebookArchive(snapshot: old.snapshot, profile: ProfileDetails(name: String(repeating: "x", count: 81)))
        #expect(throws: (any Error).self) { try store.restore(target, current: invalidCurrent) }
        #expect(try FileJournalRepository(url: journalURL).loadSnapshot() == old.snapshot)
        #expect(try store.previousBackupData() == nil)
    }

    @Test func failureAtEachWriteStepLeavesTheOriginalPairUntouched() throws {
        for failure in 1...4 {
            let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
            let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
            let old = try archive(name: "Old"), target = try archive(name: "Target", weight: 15_000)
            try seed(old, journal: journalURL, profile: profileURL)
            let journalBytes = try Data(contentsOf: journalURL), profileBytes = try Data(contentsOf: profileURL)
            var writes = 0
            let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL, writer: { data, url in
                writes += 1
                if writes == failure { throw CocoaError(.fileWriteOutOfSpace) }
                try data.write(to: url, options: .atomic)
            })
            #expect(throws: (any Error).self) { try store.restore(target, current: old) }
            #expect(try Data(contentsOf: journalURL) == journalBytes)
            #expect(try Data(contentsOf: profileURL) == profileBytes)
            #expect(!FileManager.default.fileExists(atPath: store.pendingURL.path))
        }
    }

    @Test func writeThenFailureRollsBackBothAlreadyWrittenTargets() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let old = try archive(name: "Old"), target = try archive(name: "Target", weight: 15_000)
        try seed(old, journal: journalURL, profile: profileURL)
        let journalBytes = try Data(contentsOf: journalURL), profileBytes = try Data(contentsOf: profileURL)
        var failed = false
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL, writer: { data, url in
            try data.write(to: url, options: .atomic)
            if url == journalURL && !failed { failed = true; throw CocoaError(.fileWriteUnknown) }
        })
        #expect(throws: (any Error).self) { try store.restore(target, current: old) }
        #expect(try Data(contentsOf: journalURL) == journalBytes)
        #expect(try Data(contentsOf: profileURL) == profileBytes)
        #expect(!FileManager.default.fileExists(atPath: store.pendingURL.path))
    }

    @Test func interruptedRestoreRetainsMarkerAndFreshStoreRecoversTheOriginalPair() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let old = try archive(name: "Old"), target = try archive(name: "Target", weight: 15_000)
        try seed(old, journal: journalURL, profile: profileURL)
        let journalBytes = try Data(contentsOf: journalURL), profileBytes = try Data(contentsOf: profileURL)
        var interrupted = false
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL, writer: { data, url in
            if interrupted { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: url, options: .atomic)
            if url == journalURL { interrupted = true; throw CocoaError(.fileWriteUnknown) }
        })
        #expect(throws: (any Error).self) { try store.restore(target, current: old) }
        #expect(FileManager.default.fileExists(atPath: store.pendingURL.path))
        let protected = try store.previousBackupData()
        #expect(throws: (any Error).self) { try store.restore(old, current: target) }
        #expect(try store.previousBackupData() == protected)
        let reopened = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        try reopened.recoverInterruptedRestore()
        #expect(try Data(contentsOf: journalURL) == journalBytes)
        #expect(try Data(contentsOf: profileURL) == profileBytes)
        #expect(!FileManager.default.fileExists(atPath: store.pendingURL.path))
        #expect(try NotebookBackupCodec.decode(#require(try reopened.previousBackupData())) == old)
    }

    @Test func startupRecoveryRecreatesAMissingOriginalParentDirectory() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile-folder/profile.json")
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        try seed(old, journal: journalURL, profile: profileURL)
        var interrupted = false
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL, writer: { data, url in
            if interrupted { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: url, options: .atomic)
            if url == journalURL { interrupted = true; throw CocoaError(.fileWriteUnknown) }
        })
        #expect(throws: (any Error).self) { try store.restore(target, current: old) }
        try FileManager.default.removeItem(at: profileURL.deletingLastPathComponent())
        let reopened = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        try reopened.recoverInterruptedRestore()
        #expect(try FileJournalRepository(url: journalURL).loadSnapshot() == old.snapshot)
        #expect(try FileProfileRepository(url: profileURL).load() == old.profile)
        #expect(!FileManager.default.fileExists(atPath: reopened.pendingURL.path))
    }

    @Test func absentFilesAreRestoredToAbsenceAfterInterruptedFirstRestore() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let target = try archive(name: "Target")
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL, writer: { data, url in
            if url == journalURL { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: url, options: .atomic)
        }, remover: { url in
            if url == journalURL || url == profileURL { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.removeItem(at: url)
        })
        #expect(throws: (any Error).self) { try store.restore(target, current: nil) }
        #expect(FileManager.default.fileExists(atPath: store.pendingURL.path))
        let reopened = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        try reopened.recoverInterruptedRestore()
        #expect(!FileManager.default.fileExists(atPath: journalURL.path))
        #expect(!FileManager.default.fileExists(atPath: profileURL.path))
        #expect(try reopened.previousBackupData() == nil)
        #expect(try reopened.originalJournalData() == nil)
    }

    @Test func missingFilesCanBeRestoredAndCurrentRawExportUsesLiveBytes() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("nested/journal.json"), profileURL = root.appendingPathComponent("nested/profile.json")
        let target = try archive(name: "Target")
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        #expect(try store.originalJournalData() == nil)
        try store.restore(target, current: nil)
        #expect(try FileJournalRepository(url: journalURL).loadSnapshot() == target.snapshot)
        #expect(try FileProfileRepository(url: profileURL).load() == target.profile)
        #expect(try store.originalJournalData() == Data(contentsOf: journalURL))
    }

    @Test func corruptOriginalFilesAreRetainedByteForByteBeforeReplacement() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let brokenJournal = Data("unreadable future journal".utf8), brokenProfile = Data("broken profile".utf8)
        try brokenJournal.write(to: journalURL); try brokenProfile.write(to: profileURL)
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        #expect(try store.originalJournalData() == brokenJournal)
        try store.restore(try archive(name: "Target"), current: nil)
        let retained = try JSONDecoder().decode(RetainedOriginalFixture.self, from: Data(contentsOf: store.originalsURL))
        #expect(retained.journal.contents == brokenJournal && retained.profile.contents == brokenProfile)
        #expect(retained.journal.existed && retained.profile.existed)
        #expect(try store.previousBackupData() == nil)
    }

    @Test func rawRecoveryCopyReplacesAnEarlierValidBackupAndExportsExactOriginalFiles() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        try seed(old, journal: journalURL, profile: profileURL)
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        try store.restore(target, current: old)
        #expect(try store.previousBackupData() != nil)
        let rawJournal = Data("unreadable later journal".utf8), rawProfile = Data("unreadable later profile".utf8)
        try rawJournal.write(to: journalURL); try rawProfile.write(to: profileURL)
        try store.restore(old, current: nil)
        #expect(try store.previousBackupData() == nil)
        let retained = try JSONDecoder().decode(RetainedOriginalFixture.self, from: #require(try store.previousOriginalFilesData()))
        #expect(retained.journal.contents == rawJournal && retained.profile.contents == rawProfile)
        #expect(retained.journal.existed && retained.profile.existed)
        #expect(!FileManager.default.fileExists(atPath: store.backupURL.path))
        #expect(try FileJournalRepository(url: journalURL).loadSnapshot() == old.snapshot)
    }

    @Test func validRecoveryCopyReplacesEarlierRawOriginalFiles() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let rawJournal = Data("unreadable original journal".utf8)
        try rawJournal.write(to: journalURL)
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        try store.restore(old, current: nil)
        #expect(try store.previousOriginalFilesData() != nil)
        try store.restore(target, current: old)
        #expect(try store.previousOriginalFilesData() == nil)
        #expect(!FileManager.default.fileExists(atPath: store.originalsURL.path))
        #expect(try NotebookBackupCodec.decode(#require(try store.previousBackupData())) == old)
    }

    @Test func failureRemovingAnObsoleteRecoveryCopyStopsBeforeLiveFilesChange() throws {
        for replaceValidCopy in [true, false] {
            let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
            let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
            let old = try archive(name: "Old"), target = try archive(name: "Target")
            try seed(old, journal: journalURL, profile: profileURL)
            let setup = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
            try setup.restore(target, current: replaceValidCopy ? old : nil)
            let journalBefore = try Data(contentsOf: journalURL), profileBefore = try Data(contentsOf: profileURL)
            let removalURL = replaceValidCopy ? setup.backupURL : setup.originalsURL
            let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL,
                writer: { try $0.write(to: $1, options: .atomic) }, remover: { url in
                    if url == removalURL { throw CocoaError(.fileWriteUnknown) }
                    try FileManager.default.removeItem(at: url)
                })
            #expect(throws: (any Error).self) { try store.restore(old, current: replaceValidCopy ? nil : target) }
            #expect(try Data(contentsOf: journalURL) == journalBefore)
            #expect(try Data(contentsOf: profileURL) == profileBefore)
            #expect(!FileManager.default.fileExists(atPath: store.pendingURL.path))
        }
    }

    @Test func exportedOriginalFilesRejectCorruptRecoveryEnvelopes() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = FileNotebookRestoreStore(journalURL: root.appendingPathComponent("journal.json"), profileURL: root.appendingPathComponent("profile.json"))
        #expect(try store.previousOriginalFilesData() == nil)
        for raw in ["broken", #"{"format":"senda-restore-recovery","version":1,"journal":{"existed":true},"profile":{"existed":false}}"#] {
            let data = Data(raw.utf8)
            try data.write(to: store.originalsURL)
            #expect(throws: (any Error).self) { try store.previousOriginalFilesData() }
            #expect(try Data(contentsOf: store.originalsURL) == data)
        }
    }

    @Test func corruptPendingMarkerBlocksRecoveryAndReplacementWithoutTouchingFiles() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let old = try archive(name: "Old")
        try seed(old, journal: journalURL, profile: profileURL)
        let journalBytes = try Data(contentsOf: journalURL), profileBytes = try Data(contentsOf: profileURL)
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        for bytes in [Data("broken".utf8), Data(#"{"version":1,"journal":{},"profile":{}}"#.utf8),
                      Data(#"{"format":"senda-restore-recovery","version":1,"journal":{"existed":true},"profile":{"existed":false}}"#.utf8),
                      Data(#"{"format":"senda-restore-recovery","version":999,"journal":{"existed":false},"profile":{"existed":false}}"#.utf8)] {
            try bytes.write(to: store.pendingURL)
            #expect(throws: (any Error).self) { try store.recoverInterruptedRestore() }
            #expect(throws: (any Error).self) { try store.restore(try archive(name: "Target"), current: old) }
            #expect(try Data(contentsOf: journalURL) == journalBytes)
            #expect(try Data(contentsOf: profileURL) == profileBytes)
            #expect(try Data(contentsOf: store.pendingURL) == bytes)
        }
    }

    @Test func failureToRemoveCommitMarkerRollsBackAndKeepsRecoverableState() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        try seed(old, journal: journalURL, profile: profileURL)
        var removals = 0
        let pendingURL = journalURL.appendingPathExtension("restore-pending.json")
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL, writer: { try $0.write(to: $1, options: .atomic) }, remover: { url in
            if url == pendingURL {
                removals += 1
                if removals == 1 { throw CocoaError(.fileWriteUnknown) }
            }
            try FileManager.default.removeItem(at: url)
        })
        #expect(throws: (any Error).self) { try store.restore(target, current: old) }
        #expect(try FileJournalRepository(url: journalURL).loadSnapshot() == old.snapshot)
        #expect(try FileProfileRepository(url: profileURL).load() == old.profile)
        #expect(!FileManager.default.fileExists(atPath: store.pendingURL.path))
    }

    @Test func restoringThePreviousBackupProtectsTheReplacedNotebookForAnotherRoundtrip() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journalURL = root.appendingPathComponent("journal.json"), profileURL = root.appendingPathComponent("profile.json")
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        try seed(old, journal: journalURL, profile: profileURL)
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        try store.restore(target, current: old)
        let previous = try NotebookBackupCodec.decode(#require(try store.previousBackupData()))
        try store.restore(previous, current: target)
        #expect(try FileJournalRepository(url: journalURL).loadSnapshot() == old.snapshot)
        #expect(try NotebookBackupCodec.decode(#require(try store.previousBackupData())) == target)
    }

    @Test func memoryRestoreRoundtripsTheArchiveAndRetainsPreviousData() throws {
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        let journal = try MemoryJournalRepository(snapshot: old.snapshot), profile = MemoryProfileRepository()
        try profile.save(old.profile)
        let store = MemoryNotebookRestoreStore(repository: journal, profileRepository: profile)
        try store.restore(target, current: old)
        #expect(try journal.loadSnapshot() == target.snapshot)
        #expect(try profile.load() == target.profile)
        #expect(try NotebookBackupCodec.decode(#require(try store.previousBackupData())) == old)
        #expect(try store.originalJournalData() == nil)
        try store.recoverInterruptedRestore()
        #expect(try journal.loadSnapshot() == target.snapshot)
    }

    @Test func memoryRestoreWithoutValidCurrentArchiveClearsEarlierProtectedBackup() throws {
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        let journal = try MemoryJournalRepository(snapshot: old.snapshot), profile = MemoryProfileRepository()
        try profile.save(old.profile)
        let store = MemoryNotebookRestoreStore(repository: journal, profileRepository: profile)
        try store.restore(target, current: old)
        #expect(try store.previousBackupData() != nil)
        try store.restore(old, current: nil)
        #expect(try store.previousBackupData() == nil)
        #expect(try store.previousOriginalFilesData() == nil)
    }

    @Test func memoryRestoreRollsBackProfileWhenJournalWriteFailsAndRetriesBlockedRecovery() throws {
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        let journal = RestoreFailureJournal(snapshot: old.snapshot), profile = MemoryProfileRepository()
        try profile.save(old.profile)
        let store = MemoryNotebookRestoreStore(repository: journal, profileRepository: profile)
        journal.reject = true
        #expect(throws: (any Error).self) { try store.restore(target, current: old) }
        #expect(try journal.loadSnapshot() == old.snapshot)
        #expect(try profile.load() == old.profile)
        #expect(throws: (any Error).self) { try store.restore(target, current: old) }
        #expect(try profile.load() == old.profile)
        journal.reject = false
        try store.recoverInterruptedRestore()
        try store.restore(target, current: old)
        #expect(try journal.loadSnapshot() == target.snapshot)
        #expect(try profile.load() == target.profile)
    }

    @Test func memoryRestoreRollsBackWhenProfileWriteFails() throws {
        let old = try archive(name: "Old"), target = try archive(name: "Target")
        let journal = try MemoryJournalRepository(snapshot: old.snapshot), profile = RestoreFailureProfile(details: old.profile)
        let store = MemoryNotebookRestoreStore(repository: journal, profileRepository: profile)
        profile.failNext = true
        #expect(throws: (any Error).self) { try store.restore(target, current: old) }
        #expect(try journal.loadSnapshot() == old.snapshot)
        #expect(try profile.load() == old.profile)
        try store.recoverInterruptedRestore()
        try store.restore(target, current: old)
        #expect(try journal.loadSnapshot() == target.snapshot)
    }
}

private struct RetainedOriginalFixture: Decodable {
    struct File: Decodable { let existed: Bool; let contents: Data? }
    let journal: File
    let profile: File
}
@MainActor private final class RestoreFailureProfile: ProfileRepository {
    private var details: ProfileDetails
    var failNext = false
    init(details: ProfileDetails) { self.details = details }
    func load() throws -> ProfileDetails { details }
    func save(_ details: ProfileDetails) throws {
        if failNext { failNext = false; throw CocoaError(.fileWriteUnknown) }
        self.details = details
    }
}

@MainActor private final class RestoreFailureJournal: JournalRepository {
    private var snapshot: JournalSnapshot
    var reject = false
    init(snapshot: JournalSnapshot) { self.snapshot = snapshot }
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ snapshot: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        self.snapshot = try snapshot.validated()
    }
}
