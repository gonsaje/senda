import Foundation
import Testing
@testable import SendaDomain

struct ExerciseLibraryTests {
    @Test func presetLibraryExtendsBeyondTheOriginalThree() {
        #expect(Exercise.catalog.count > 3)
        #expect(Exercise.catalog.contains { $0.id == "row" })
        #expect(Exercise.catalog.contains { $0.id == "overhead-press" })
        #expect(Set(Exercise.catalog.map(\.id)).count == Exercise.catalog.count)
    }

    @Test func customExerciseNormalizesNamesAndRetainsItsStableIdentityWhenEncoded() throws {
        let exercise = try ExerciseLibrary.custom(named: "  Jae’s   cable row  ")
        #expect(exercise.name == "Jae’s cable row")
        #expect(exercise.shortName == exercise.name)
        #expect(exercise.startingWeight == 0)
        let decoded = try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise))
        #expect(decoded == exercise)
        #expect(try ExerciseLibrary.custom(named: exercise.name).id != exercise.id)
    }

    @Test func invalidAndDuplicateNamesAreRejected() throws {
        for name in ["", " \n ", String(repeating: "a", count: 81), "Hidden\u{0000}name", " bench ", "dl"] {
            #expect(throws: (any Error).self) { try ExerciseLibrary.custom(named: name) }
        }
        let first = try ExerciseLibrary.custom(named: "Café Row")
        #expect(throws: (any Error).self) {
            try ExerciseLibrary.custom(named: " CAFE   ROW ", existing: Exercise.catalog + [first])
        }
    }

    @Test func libraryRejectsDuplicateIdentitiesAndPresetShadowing() throws {
        let custom = try ExerciseLibrary.custom(named: "My lift")
        #expect(throws: (any Error).self) { try ExerciseLibrary.validated(custom: [custom, custom]) }
        #expect(throws: (any Error).self) { try ExerciseLibrary.validated(custom: [Exercise.catalog[0]]) }
        #expect(try ExerciseLibrary.validated(custom: [custom]).last == custom)
    }

    @Test func workspaceAcceptsMoreTabsAndHiddenRetainedSessionsButRejectsDanglingSelection() throws {
        let custom = try ExerciseLibrary.custom(named: "My lift")
        let order = ["bench", "deadlift", "squat", "row", custom.id]
        let pending = DraftBatch(exerciseID: custom.id, sets: [SetValues(weight: 0, reps: 8)])
        var workspace = EntryWorkspace(selectedExerciseID: custom.id,
            sessions: [custom.id: .draft(pending)], numberInputText: "0", workoutExerciseIDs: order)
        #expect(throws: Never.self) { try JournalSnapshot(workspace: workspace, customExercises: [custom]).validated() }
        workspace.workoutExerciseIDs = ["bench"]
        #expect(throws: (any Error).self) { try JournalSnapshot(workspace: workspace, customExercises: [custom]).validated() }
        workspace.selectedExerciseID = "bench"
        workspace.sessions["bench"] = .draft(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 0, reps: 10)]))
        #expect(throws: Never.self) { try JournalSnapshot(workspace: workspace, customExercises: [custom]).validated() }
        workspace.workoutExerciseIDs = ["bench", "bench"]
        #expect(throws: (any Error).self) { try JournalSnapshot(workspace: workspace, customExercises: [custom]).validated() }
    }

    @Test func unknownLegacyHistoryIsRetainedWithoutInventingCatalogMetadata() throws {
        var journal = Journal()
        let entry = try journal.record(DraftBatch(exerciseID: "legacy-import", sets: [SetValues(weight: 1_000, reps: 5)]), at: Date())
        #expect(try JournalSnapshot(journal: journal).validated().journal.batches == [entry])
    }
}
