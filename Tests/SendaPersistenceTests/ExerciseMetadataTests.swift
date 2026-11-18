import Foundation
import Testing
import SendaDomain
@testable import SendaPersistence

@MainActor struct ExerciseMetadataTests {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("senda-exercises-\(UUID()).json")
    }
    private func workspace(for exercise: Exercise) -> EntryWorkspace {
        EntryWorkspace(selectedExerciseID: exercise.id,
            sessions: [exercise.id: .draft(DraftBatch(exerciseID: exercise.id, sets: [SetValues(weight: 0, reps: 10)]))],
            numberInputText: "0", workoutExerciseIDs: ["bench", "deadlift", "squat", exercise.id])
    }

    @Test func taggedCustomExercisesSurviveJournalAndBackupWithoutChangingEarlierRecords() throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileJournalRepository(url: url)
        let day = try TrainingDay("2026-11-16")
        let original = try ExerciseLibrary.custom(named: "My equipment circuit")
        let legacy = JournalSnapshot(customExercises: [original], training: TrainingWorkspace(visibleWeek: day))
        try repository.saveSnapshot(legacy)
        let legacyBytes = try Data(contentsOf: url)
        let untagged = try repository.loadSnapshot()
        #expect(untagged.customExercises?.first?.customSetup.isEmpty == true)
        #expect(!String(decoding: legacyBytes, as: UTF8.self).contains("customSetup"))

        var tagged = original
        tagged.customSetup = .init(gyms: [.home, .crossFit], requiredEquipment: [.flatBench, .dumbbells])
        let free = try ExerciseLibrary.custom(named: "My no gear circuit", customSetup: .init(requiredEquipment: []))
        let workout = WorkoutTemplate(name: "Circuits", exerciseIDs: [original.id, free.id])
        let saved = JournalSnapshot(customExercises: [tagged, free],
            training: TrainingWorkspace(visibleWeek: day, workoutTemplates: [workout]))
        try repository.saveSnapshot(saved)
        #expect(try repository.loadSnapshot() == saved)
        let journal = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect(journal["version"] as? Int == 9)

        let archive = NotebookArchive(snapshot: saved, profile: ProfileDetails())
        let bytes = try NotebookBackupCodec.encode(archive)
        let json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(json["version"] as? Int == 8)
        let restored = try NotebookBackupCodec.decode(bytes)
        #expect(restored == archive)
        #expect(try NotebookBackupCodec.encode(restored) == bytes)
        let records = try #require((json["snapshot"] as? [String: Any])?["customExercises"] as? [[String: Any]])
        let setup = try #require(records.first?["customSetup"] as? [String: Any])
        #expect(setup["gyms"] as? [String] == ["crossFit", "home"])
        #expect(setup["requiredEquipment"] as? [String] == ["dumbbells", "flatBench"])
    }

    @Test func taggedFormatsRejectLostTagsAndLostWorkoutTemplates() throws {
        let exercise = try ExerciseLibrary.custom(named: "My floor sequence", customSetup: .init(requiredEquipment: []))
        let workout = WorkoutTemplate(name: "Floor day", exerciseIDs: [exercise.id])
        let snapshot = JournalSnapshot(customExercises: [exercise],
            training: TrainingWorkspace(visibleWeek: try TrainingDay("2026-11-16"), workoutTemplates: [workout]))
        let url = location()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileJournalRepository(url: url)
        try repository.saveSnapshot(snapshot)
        let journal = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let archive = try NotebookBackupCodec.encode(NotebookArchive(snapshot: snapshot, profile: ProfileDetails()))
        let backup = try #require(JSONSerialization.jsonObject(with: archive) as? [String: Any])
        let payload = try #require(backup["snapshot"] as? [String: Any])

        for key in ["customSetup", "workoutTemplates"] {
            func stripped(_ object: [String: Any]) throws -> [String: Any] {
                var result = object
                if key == "customSetup" {
                    var rows = try #require(result["customExercises"] as? [[String: Any]])
                    rows[0].removeValue(forKey: key)
                    result["customExercises"] = rows
                } else {
                    var training = try #require(result["training"] as? [String: Any])
                    training.removeValue(forKey: key)
                    result["training"] = training
                }
                return result
            }
            let bytes = try JSONSerialization.data(withJSONObject: stripped(journal))
            try bytes.write(to: url)
            let error: StorageError = key == "customSetup" ? .missingExerciseSetups : .missingWorkoutTemplates
            #expect(throws: error) { try repository.loadSnapshot() }
            #expect(try Data(contentsOf: url) == bytes)
            var damaged = backup
            damaged["snapshot"] = try stripped(payload)
            #expect(throws: NotebookBackupError.invalidBackup) {
                try NotebookBackupCodec.decode(JSONSerialization.data(withJSONObject: damaged))
            }
        }
    }

    @Test func versionTwoLoadsUnchangedThenUpgradesWithCustomLibraryAndWorkoutOrder() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]), at: Date())
        struct Legacy: Encodable { let version = 2; let journal: Journal; let workspace: EntryWorkspace? = nil }
        let original = try JSONEncoder().encode(Legacy(journal: journal))
        try original.write(to: url)
        let repository = FileJournalRepository(url: url)
        #expect(try repository.loadSnapshot().journal == journal)
        #expect(try Data(contentsOf: url) == original)
        let custom = try ExerciseLibrary.custom(named: "My exercise")
        let snapshot = JournalSnapshot(journal: journal, workspace: workspace(for: custom), customExercises: [custom])
        try repository.saveSnapshot(snapshot)
        #expect(try repository.loadSnapshot() == snapshot)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect(object["version"] as? Int == 7)
    }

    @Test func journalOnlySavePreservesTheLibraryAndWorkout() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileJournalRepository(url: url)
        let custom = try ExerciseLibrary.custom(named: "My exercise")
        let original = JournalSnapshot(workspace: workspace(for: custom), customExercises: [custom])
        try repository.saveSnapshot(original)
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]), at: Date())
        try repository.save(journal)
        let recovered = try repository.loadSnapshot()
        #expect(recovered.journal == journal)
        #expect(recovered.customExercises == [custom])
        #expect(recovered.workspace == original.workspace)
    }

    @Test func populatedVersionTwoRecoverySurvivesLibraryUpgradeWithoutRecordingItsChanges() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        var journal = Journal()
        let performed = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]), at: Date())
        let recovery = EntryWorkspace(selectedExerciseID: "deadlift", sessions: [
            "bench": .editing(RecordedEdit(batchID: performed.id, revision: 1, sets: [SetValues(weight: 13_500, reps: 8)])),
            "deadlift": .draft(DraftBatch(exerciseID: "deadlift", sets: [SetValues(weight: 22_500, reps: 5)]))
        ], numberInputText: "229.", numberInputDirty: true, selectedSetIndex: 0, weightUnit: .pounds)
        struct Legacy: Encodable { let version = 2; let journal: Journal; let workspace: EntryWorkspace }
        let bytes = try JSONEncoder().encode(Legacy(journal: journal, workspace: recovery))
        try bytes.write(to: url)
        let repository = FileJournalRepository(url: url)
        var loaded = try repository.loadSnapshot()
        #expect(loaded.workspace == recovery)
        #expect(try Data(contentsOf: url) == bytes)
        loaded.customExercises = [try ExerciseLibrary.custom(named: "My exercise")]
        try repository.saveSnapshot(loaded)
        let upgraded = try repository.loadSnapshot()
        #expect(upgraded.workspace == recovery)
        #expect(upgraded.journal == journal)
        #expect(upgraded.journal.batches[0].values[0].reps == 10)
        #expect(upgraded.customExercises?.first?.name == "My exercise")
    }

    @Test func corruptVersionThreeMetadataRemainsUntouched() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let custom = try ExerciseLibrary.custom(named: "My exercise")
        let snapshot = JournalSnapshot(workspace: workspace(for: custom), customExercises: [custom])
        let repository = FileJournalRepository(url: url)
        try repository.saveSnapshot(snapshot)
        let valid = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        for missingField in [true, false] {
            var corrupt = valid
            if missingField { corrupt.removeValue(forKey: "customExercises") }
            else { corrupt["customExercises"] = [] }
            let bytes = try JSONSerialization.data(withJSONObject: corrupt)
            try bytes.write(to: url)
            #expect(throws: (any Error).self) { try repository.loadSnapshot() }
            #expect(try Data(contentsOf: url) == bytes)
        }
    }

    @Test func failedCatalogWriteKeepsTheEntirePreviousSnapshot() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileJournalRepository(url: url)
        try repository.saveSnapshot(JournalSnapshot())
        let original = try Data(contentsOf: url)
        var writes = 0
        let failing = FileJournalRepository(url: url) { _, _ in writes += 1; throw CocoaError(.fileWriteUnknown) }
        let custom = try ExerciseLibrary.custom(named: "My exercise")
        #expect(throws: (any Error).self) {
            try failing.saveSnapshot(JournalSnapshot(workspace: workspace(for: custom), customExercises: [custom]))
        }
        #expect(writes == 1)
        #expect(try Data(contentsOf: url) == original)
        #expect(try repository.loadSnapshot().customExercises?.isEmpty != false)
    }
}
