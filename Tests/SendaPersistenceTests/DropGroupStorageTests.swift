import Foundation
import Testing
import SendaDomain
@testable import SendaPersistence

@MainActor struct DropGroupStorageTests {
    private let day = try! TrainingDay("2026-11-09")
    private let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
    private let recordedAt = Date(timeIntervalSinceReferenceDate: 815_144_123.123456)

    private func fixture() throws -> NotebookArchive {
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [
            SetValues(weight: 13_755, reps: 9), SetValues(weight: 4_501, reps: 10), SetValues(weight: 101, reps: 12)
        ]), at: recordedAt)
        var stages = batch.sets.map { set in
            var row = TrainingRow(set: set, unit: .kilograms)
            row.kind = .dropSet; row.dropGroupID = groupID
            return row
        }
        var draft = TrainingRow(weight: "31.", unit: .kilograms, weightIsDirty: true, kind: .dropSet)
        draft.dropGroupID = groupID
        stages.insert(draft, at: 1)
        let regular = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 0, reps: 15)]),
            at: recordedAt.addingTimeInterval(1)).sets[0]
        let workout = DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench",
            rows: ["bench": stages + [TrainingRow(set: regular, unit: .kilograms)]], unit: .kilograms)
        let training = TrainingWorkspace(visibleWeek: day, selectedDay: day, preferredUnit: .kilograms,
            days: [day.rawValue: workout])
        return try NotebookArchive(snapshot: JournalSnapshot(journal: journal, training: training),
            profile: ProfileDetails(), createdAt: recordedAt.addingTimeInterval(2)).validated()
    }

    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("senda-drop-storage-\(UUID()).json")
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func deletingGroup(_ archive: NotebookArchive) throws -> NotebookArchive {
        var snapshot = archive.snapshot
        let removed = Array(snapshot.training!.days[day.rawValue]!.rows["bench"]!.prefix { $0.dropGroupID == groupID })
        let removal = try snapshot.journal.removeSets(removed.compactMap(\.performedSetID))
        snapshot.training!.days[day.rawValue]!.rows["bench"]!.removeFirst(removed.count)
        snapshot.training!.undo = .deletedGroup(day: day, exerciseID: "bench", index: 0, rows: removed, removal: removal)
        return try NotebookArchive(snapshot: snapshot, profile: archive.profile, createdAt: archive.createdAt).validated()
    }

    @Test func groupedStagesAndPartialInputRoundTripThroughLocalStorageAndFullBackup() throws {
        let archive = try fixture(), url = location()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileJournalRepository(url: url)
        try repository.saveSnapshot(archive.snapshot)
        #expect(try object(Data(contentsOf: url))["version"] as? Int == 7)
        #expect(try repository.loadSnapshot() == archive.snapshot)
        let data = try NotebookBackupCodec.encode(archive)
        #expect(try object(data)["version"] as? Int == 4)
        let loaded = try NotebookBackupCodec.decode(data)
        #expect(loaded == archive)
        let rows = try #require(loaded.snapshot.training?.days[day.rawValue]?.rows["bench"])
        #expect(rows.map(\.dropGroupID) == [groupID, groupID, groupID, groupID, nil])
        #expect(rows[1].weight == "31." && rows[1].performedSetID == nil)
        #expect(loaded.snapshot.journal.batches[0].recordedAt == recordedAt)
        #expect(loaded.snapshot.journal.batches[0].values.map(\.weight) == [13_755, 4_501, 101])
    }

    @Test func groupedDeletionUndoSurvivesBackupRestoreWithItsOriginalBatchAndStageOrder() throws {
        let original = try fixture(), deleted = try deletingGroup(original)
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let fileRepository = FileJournalRepository(url: url)
        try fileRepository.saveSnapshot(deleted.snapshot)
        #expect(try fileRepository.loadSnapshot() == deleted.snapshot)
        let decoded = try NotebookBackupCodec.decode(NotebookBackupCodec.encode(deleted))
        let repository = try MemoryJournalRepository(snapshot: original.snapshot)
        let profile = MemoryProfileRepository()
        try MemoryNotebookRestoreStore(repository: repository, profileRepository: profile).restore(decoded, current: original)
        var restored = try repository.loadSnapshot()
        #expect(restored == deleted.snapshot)
        guard case .deletedGroup(let undoDay, let exerciseID, let index, let rows, let removal)? = restored.training?.undo else {
            Issue.record("Missing grouped deletion undo"); return
        }
        #expect(removal.batches.count == 1)
        #expect(removal.batches[0].batch == original.snapshot.journal.batches[0])
        #expect(removal.batches[0].removedSetIDs == original.snapshot.journal.batches[0].sets.map(\.id))
        _ = try restored.journal.restoreSets(removal)
        restored.training!.days[undoDay.rawValue]!.rows[exerciseID]!.insert(contentsOf: rows, at: index)
        restored.training!.undo = nil
        _ = try restored.validated()
        #expect(restored.training == original.snapshot.training)
        #expect(restored.journal.batches[0].sets == original.snapshot.journal.batches[0].sets)
        #expect(restored.journal.batches[0].id == original.snapshot.journal.batches[0].id)
        #expect(restored.journal.batches[0].revision == 3)
    }

    @Test func groupedRepeatUndoRoundTripsWithoutChangingStageIdentity() throws {
        var archive = try fixture(), snapshot = archive.snapshot
        snapshot.training!.days[day.rawValue]!.rows["bench"]!.remove(at: 1)
        let rows = try #require(snapshot.training?.days[day.rawValue]?.rows["bench"])
        snapshot.training!.undo = .repeatedGroup(day: day, exerciseID: "bench", rowIDs: Array(rows.prefix(3)).map(\.id))
        archive = NotebookArchive(snapshot: snapshot, profile: archive.profile, createdAt: archive.createdAt)
        #expect(try NotebookBackupCodec.decode(NotebookBackupCodec.encode(archive)) == archive)
    }

    @Test func csvIncludesEveryRecordedStageWithExactWeightsAndPhysicalStageNumbers() throws {
        let archive = try fixture()
        let text = try #require(String(data: NotebookBackupCodec.csv(snapshot: archive.snapshot), encoding: .utf8))
        let rows = text.components(separatedBy: "\r\n").filter { !$0.isEmpty }.map { $0.components(separatedBy: ",") }
        #expect(rows.count == 5)
        #expect(Array(rows[0].suffix(2)) == ["Drop Group ID", "Drop Stage"])
        try #require(rows.allSatisfy { $0.count == 17 })
        #expect(rows.dropFirst().map { $0[5] } == ["137.55", "45.01", "1.01", "0"])
        #expect(rows.dropFirst().map { $0[6] } == ["62.3916304935", "20.4161925737", "0.4581282937", "0"])
        #expect(rows.dropFirst().map { $0[15] } == [groupID.uuidString, groupID.uuidString, groupID.uuidString, ""])
        #expect(rows.dropFirst().map { $0[16] } == ["1", "3", "4", ""])
        #expect(rows.dropFirst().map { $0[9] } == archive.snapshot.journal.batches.flatMap(\.sets).map { $0.id.uuidString })
        #expect(!text.contains("31."))
    }

    @Test func legacyDropRowsLoadWithoutInferredGroupsOrFileRewrites() throws {
        var snapshot = try fixture().snapshot
        for index in snapshot.training!.days[day.rawValue]!.rows["bench"]!.indices {
            snapshot.training!.days[day.rawValue]!.rows["bench"]![index].dropGroupID = nil
        }
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileJournalRepository(url: url)
        try repository.saveSnapshot(snapshot)
        var json = try object(Data(contentsOf: url)); json["version"] = 6
        let oldBytes = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
        try oldBytes.write(to: url)
        let loaded = try repository.loadSnapshot()
        #expect(loaded == snapshot)
        #expect(loaded.training?.days[day.rawValue]?.rows["bench"]?.allSatisfy { $0.dropGroupID == nil } == true)
        #expect(try Data(contentsOf: url) == oldBytes)
        let archive = NotebookArchive(snapshot: snapshot, profile: ProfileDetails())
        var backup = try object(NotebookBackupCodec.encode(archive)); backup["version"] = 3
        let legacyBackup = try JSONSerialization.data(withJSONObject: backup)
        #expect(try NotebookBackupCodec.decode(legacyBackup) == archive)
    }

    @Test(arguments: [-62_135_596_801.0, 253_402_300_800.0, 1e100], [0, 1])
    func backupRejectsUnreadableDatesRetainedOnlyByGroupedDeletionUndo(_ seconds: Double, _ batchIndex: Int) throws {
        let original = try fixture()
        var grouped = original.snapshot
        let lastIndex = grouped.training!.days[day.rawValue]!.rows["bench"]!.count - 1
        grouped.training!.days[day.rawValue]!.rows["bench"]![lastIndex].kind = .dropSet
        grouped.training!.days[day.rawValue]!.rows["bench"]![lastIndex].dropGroupID = groupID
        let deleted = try deletingGroup(NotebookArchive(snapshot: grouped, profile: original.profile, createdAt: original.createdAt))
        var json = try object(NotebookBackupCodec.encode(deleted))
        var snapshot = try #require(json["snapshot"] as? [String: Any])
        var training = try #require(snapshot["training"] as? [String: Any])
        var undo = try #require(training["undo"] as? [String: Any])
        var group = try #require(undo["deletedGroup"] as? [String: Any])
        var removal = try #require(group["removal"] as? [String: Any])
        var batches = try #require(removal["batches"] as? [[String: Any]])
        var batch = try #require(batches[batchIndex]["batch"] as? [String: Any])
        batch["recordedAt"] = Date(timeIntervalSince1970: seconds).timeIntervalSinceReferenceDate
        batches[batchIndex]["batch"] = batch; removal["batches"] = batches; group["removal"] = removal
        undo["deletedGroup"] = group; training["undo"] = undo; snapshot["training"] = training; json["snapshot"] = snapshot
        let bytes = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: NotebookBackupError.invalidBackup) { try NotebookBackupCodec.decode(bytes) }
        let candidateSnapshot = try JSONDecoder().decode(JournalSnapshot.self,
            from: JSONSerialization.data(withJSONObject: snapshot))
        let candidate = NotebookArchive(snapshot: candidateSnapshot, profile: deleted.profile, createdAt: deleted.createdAt)
        #expect(throws: NotebookBackupError.invalidBackup) { try candidate.validated() }
        #expect(throws: NotebookBackupError.invalidBackup) { try NotebookBackupCodec.encode(candidate) }
    }
}
