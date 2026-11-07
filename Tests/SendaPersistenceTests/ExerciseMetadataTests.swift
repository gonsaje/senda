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
        #expect(object["version"] as? Int == 3)
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
