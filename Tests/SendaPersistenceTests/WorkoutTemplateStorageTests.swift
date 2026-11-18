import Foundation
import Testing
import SendaDomain
import SendaPersistence

@MainActor struct WorkoutTemplateStorageTests {
    private func snapshot() throws -> JournalSnapshot {
        let week = try #require(TrainingDay(rawValue: "2026-11-16"))
        let customExercise = try ExerciseLibrary.custom(named: "My high row")
        let workout = WorkoutTemplate(name: "My Tuesday workout", exerciseIDs: [customExercise.id, "bench"],
            exercisePlans: ["bench": ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)])
        return JournalSnapshot(customExercises: [customExercise],
            training: TrainingWorkspace(visibleWeek: week, workoutTemplates: [workout]))
    }

    private func withoutTemplates(_ training: [String: Any]) -> [String: Any] {
        var legacy = training
        legacy.removeValue(forKey: "workoutTemplates")
        return legacy
    }

    @Test func journalRetainsWorkoutIdentityOrderAndPlansAndReadsLegacyFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("journal.json")
        let repository = FileJournalRepository(url: url)
        let saved = try snapshot()
        try repository.saveSnapshot(saved)
        #expect(try repository.loadSnapshot() == saved)

        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect(json["version"] as? Int == 8)
        json["training"] = withoutTemplates(try #require(json["training"] as? [String: Any]))
        let truncated = try JSONSerialization.data(withJSONObject: json)
        try truncated.write(to: url)
        #expect(throws: StorageError.missingWorkoutTemplates) { try repository.loadSnapshot() }
        #expect(try Data(contentsOf: url) == truncated)

        json["version"] = 7
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        var legacy = saved
        legacy.training?.workoutTemplates = nil
        #expect(try repository.loadSnapshot() == legacy)
    }

    @Test func fullBackupRetainsWorkoutsAndChoosesVersionSevenOnlyWhenNeeded() throws {
        let saved = try snapshot()
        let archive = NotebookArchive(snapshot: saved, profile: ProfileDetails())
        let encoded = try NotebookBackupCodec.encode(archive)
        #expect(try NotebookBackupCodec.decode(encoded) == archive)

        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(json["version"] as? Int == 7)
        var payload = try #require(json["snapshot"] as? [String: Any])
        payload["training"] = withoutTemplates(try #require(payload["training"] as? [String: Any]))
        json["snapshot"] = payload
        #expect(throws: NotebookBackupError.invalidBackup) {
            try NotebookBackupCodec.decode(JSONSerialization.data(withJSONObject: json))
        }

        json["version"] = 4
        var legacy = saved
        legacy.training?.workoutTemplates = nil
        let old = try NotebookBackupCodec.decode(JSONSerialization.data(withJSONObject: json))
        #expect(old.snapshot == legacy)
        let oldAgain = try #require(JSONSerialization.jsonObject(with: NotebookBackupCodec.encode(old)) as? [String: Any])
        #expect(oldAgain["version"] as? Int == 4)
    }
}
