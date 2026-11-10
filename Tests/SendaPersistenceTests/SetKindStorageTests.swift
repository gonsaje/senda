import Foundation
import Testing
import SendaDomain
@testable import SendaPersistence

@MainActor struct SetKindStorageTests {
    private let day = try! TrainingDay("2026-11-09")
    private let recordedAt = Date(timeIntervalSinceReferenceDate: 815_144_123.123456)
    private let createdAt = Date(timeIntervalSinceReferenceDate: 815_144_125.987654)

    private func fixture(legacy: Bool = false) throws -> NotebookArchive {
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [
            SetValues(weight: 101, reps: 12), SetValues(weight: 13_755, reps: 9),
            SetValues(weight: 4_501, reps: 10), SetValues(weight: 99_999, reps: 6),
            SetValues(weight: 0, reps: 15)
        ]), at: recordedAt)
        let legacyBatch = try journal.record(DraftBatch(exerciseID: "retired-lift", sets: [
            SetValues(weight: 555, reps: 7)
        ]), at: Date(timeIntervalSinceReferenceDate: 815_144_124.000001))
        let kinds: [TrainingSetKind?] = legacy ? [nil, .working, .warmup, nil, nil] : [.regular, .working, .warmup, .dropSet, nil]
        let reserves: [Int?] = [0, 5, 4, 2, nil]
        var rows = batch.sets.enumerated().map { index, set in
            var row = TrainingRow(set: set, unit: .kilograms)
            row.kind = kinds[index]; row.repsInReserve = reserves[index]
            return row
        }
        rows.append(TrainingRow(weight: "31.", reps: "", unit: .kilograms, weightIsDirty: true,
            kind: legacy ? nil : .dropSet, repsInReserve: 3))
        var unknown = TrainingRow(set: legacyBatch.sets[0], unit: .kilograms)
        unknown.kind = nil; unknown.repsInReserve = nil
        let workout = DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench",
            rows: ["bench": rows, "retired-lift": [unknown]], unit: .kilograms,
            exercisePlans: ["bench": ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)])
        let snapshot = try JournalSnapshot(journal: journal, training: TrainingWorkspace(visibleWeek: day,
            selectedDay: day, preferredUnit: .kilograms, days: [day.rawValue: workout],
            legacyExerciseIDs: ["retired-lift"])).validated()
        return NotebookArchive(snapshot: snapshot, profile: ProfileDetails(name: "Ada Example", email: "ada@example.com"),
            createdAt: createdAt)
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("senda-set-kinds-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func object(_ bytes: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    }
    private func rows(_ snapshot: JournalSnapshot) throws -> [TrainingRow] {
        try #require(snapshot.training?.days[day.rawValue]?.rows["bench"])
    }

    @Test func localFormatSevenRoundTripPreservesEveryKindAndExactNotebookState() throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = FileJournalRepository(url: folder.appendingPathComponent("journal.json"))
        let original = try fixture()
        try store.saveSnapshot(original.snapshot)
        let loaded = try store.loadSnapshot()
        #expect(loaded == original.snapshot)
        #expect(try rows(loaded).map(\.kind) == [.regular, .working, .warmup, .dropSet, nil, .dropSet])
        #expect(try rows(loaded).map(\.repsInReserve) == [0, 5, 4, 2, nil, 3])
        #expect(loaded.journal.batches[0].values.map(\.weight) == [101, 13_755, 4_501, 99_999, 0])
        #expect(loaded.journal.batches[0].recordedAt == recordedAt)
        #expect(loaded.training?.days[day.rawValue]?.rows["retired-lift"]?.first?.kind == nil)
    }

    @Test func fullBackupVersionFourPreservesAllKindsIDsDatesWeightsRIRAndPlans() throws {
        let original = try fixture()
        let data = try NotebookBackupCodec.encode(original)
        let loaded = try NotebookBackupCodec.decode(data)
        #expect(loaded == original)
        #expect(try JSONDecoder().decode(NotebookArchive.self, from: data) == original)
        let json = try object(data)
        #expect(json["version"] as? Int == 4)
        let text = try #require(String(data: data, encoding: .utf8))
        for rawValue in ["regular", "working", "warmup", "dropSet"] {
            #expect(text.contains("\"kind\" : \"\(rawValue)\""))
        }
        #expect(loaded.createdAt == createdAt)
    }

    @Test func csvExportsAllKindsAndUnknownLegacyWithoutRoundingCanonicalWeightsOrIncludingDrafts() throws {
        let original = try fixture()
        let data = try NotebookBackupCodec.csv(snapshot: original.snapshot)
        let text = try #require(String(data: data, encoding: .utf8))
        let csv = text.components(separatedBy: "\r\n").filter { !$0.isEmpty }.map { $0.components(separatedBy: ",") }
        #expect(csv.count == 7)
        #expect(csv.dropFirst().map { $0[10] } == ["regular", "working", "warmup", "dropSet", "", ""])
        #expect(csv.dropFirst().map { $0[11] } == ["0", "5+", "4", "2", "", ""])
        #expect(csv.dropFirst().map { $0[5] } == ["1.01", "137.55", "45.01", "999.99", "0", "5.55"])
        #expect(csv.dropFirst().map { $0[6] } == ["0.4581282937", "62.3916304935", "20.4161925737", "453.5878340763", "0", "2.5174376535"])
        #expect(csv[1][1] == "2026-10-31T12:55:23.123Z")
        let sets = original.snapshot.journal.batches.flatMap(\.sets)
        #expect(csv.dropFirst().map { $0[9] } == sets.map { $0.id.uuidString })
        #expect(csv[1...5].allSatisfy { Array($0[12...14]) == ["3", "8", "12"] })
        #expect(Array(csv[6][10...14]) == ["", "", "", "", ""])
        #expect(!text.contains("31."))
    }

    @Test func exportedBackupRestoresAllKindsAndKeepsPreviousNotebookRecoverable() throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let journalURL = folder.appendingPathComponent("journal.json"), profileURL = folder.appendingPathComponent("profile.json")
        let store = FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL)
        let previous = try fixture(legacy: true), original = try fixture()
        try FileJournalRepository(url: journalURL).saveSnapshot(previous.snapshot)
        try FileProfileRepository(url: profileURL).save(previous.profile)
        let decoded = try NotebookBackupCodec.decode(NotebookBackupCodec.encode(original))
        try store.restore(decoded, current: previous)
        #expect(try FileJournalRepository(url: journalURL).loadSnapshot() == original.snapshot)
        #expect(try FileProfileRepository(url: profileURL).load() == original.profile)
        #expect(try NotebookBackupCodec.decode(#require(try store.previousBackupData())) == previous)
        #expect(!FileManager.default.fileExists(atPath: store.pendingURL.path))
    }

    @Test func formatFiveLoadsBytesUnchangedAndUpgradesOnlyAfterASetTypeMutation() throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("journal.json"), original = try fixture(legacy: true)
        let store = FileJournalRepository(url: url)
        try store.saveSnapshot(original.snapshot)
        var json = try object(Data(contentsOf: url)); json["version"] = 5
        let oldBytes = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
        try oldBytes.write(to: url)
        var loaded = try store.loadSnapshot()
        #expect(loaded == original.snapshot)
        #expect(try Data(contentsOf: url) == oldBytes)
        #expect(try rows(loaded).map(\.kind) == [nil, .working, .warmup, nil, nil, nil])
        loaded.training!.days[day.rawValue]!.rows["bench"]![0].kind = .regular
        try store.saveSnapshot(loaded)
        #expect(try object(Data(contentsOf: url))["version"] as? Int == 7)
        #expect(try store.loadSnapshot() == loaded)
        #expect(loaded.journal == original.snapshot.journal)
    }

    @Test func backupVersionTwoReadsExactLegacyStateAndReexportsAsVersionFour() throws {
        let original = try fixture(legacy: true)
        var json = try object(NotebookBackupCodec.encode(original)); json["version"] = 2
        let oldBytes = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
        let loaded = try NotebookBackupCodec.decode(oldBytes)
        #expect(loaded == original)
        #expect(try rows(loaded.snapshot).map(\.kind) == [nil, .working, .warmup, nil, nil, nil])
        #expect(try object(NotebookBackupCodec.encode(loaded))["version"] as? Int == 4)
    }

    @Test func futureHeadersAreRejectedBeforeEnumPayloadDecodingAndLeaveLocalBytesUntouched() throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("journal.json")
        let bytes = Data(#"{"version":8,"journal":{"kind":"future-kind"}}"#.utf8)
        try bytes.write(to: url)
        #expect(throws: StorageError.unsupportedVersion(8)) { try FileJournalRepository(url: url).loadSnapshot() }
        #expect(try Data(contentsOf: url) == bytes)
        let backup = Data(#"{"format":"senda-backup","version":5,"snapshot":{"kind":"future-kind"}}"#.utf8)
        #expect(throws: NotebookBackupError.unsupportedVersion(5)) { try NotebookBackupCodec.decode(backup) }
    }
}
