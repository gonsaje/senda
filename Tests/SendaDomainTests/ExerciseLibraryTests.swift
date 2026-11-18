import Foundation
import Testing
@testable import SendaDomain

struct ExerciseLibraryTests {
    @Test func catalogImportKeepsHistoricalIDsAndSeparatesNamedVariations() throws {
        func exactMatches(_ name: String) -> [String] {
            Exercise.catalog.filter { $0.searchNames.map(ExerciseLibrary.matchingKey).contains(ExerciseLibrary.matchingKey(name)) }.map(\.id)
        }
        #expect(exactMatches("Rope triceps pushdown") == ["triceps-extension"])
        #expect(exactMatches("45-degree leg press") == ["leg-press"])
        #expect(exactMatches("Leg press calf raise") == ["calf-raise"])
        #expect(exactMatches("Hex bar deadlift") == ["trap-bar-deadlift"])
        #expect(exactMatches("Kipping pull-up") == ["kipping-pull-up"])
        #expect(exactMatches("Strict pull-up") == ["pull-up"])
        #expect(exactMatches("Wall chair") == ["wall-sit"])
        #expect(throws: ExerciseLibraryError.duplicateName("Hex bar deadlift")) {
            try ExerciseLibrary.custom(named: "Hex bar deadlift")
        }
    }

    @Test func oldCustomAliasRemainsTheChoiceInItsOwnNotebook() throws {
        let old = Exercise(id: "custom-before-import", name: "Wall chair", shortName: "Wall chair",
                           startingWeight: 0, muscleGroup: .legs, equipment: .bodyweight)
        let restored = try ExerciseLibrary.validated(custom: [old])
        #expect(ExerciseFormGuide.search("Wall sit", in: restored).map(\.id) == [old.id])
        #expect(restored.contains { $0.id == "wall-sit" })
        #expect(ExerciseFormGuide.search("Wall sit", in: ExerciseLibrary.resolved(custom: [])).map(\.id) == ["wall-sit"])
        #expect(restored.first { $0.id == old.id }?.muscleMap == nil)
    }

    @Test func cardioAndResistanceExercisesUseTheirOwnEquipmentAndLoad() throws {
        let walk = try #require(Exercise.catalog.first { $0.name == "Treadmill walk" })
        #expect(walk.equipmentType == .machine && !walk.requiresWeight)
        #expect(walk.muscleMap == nil)
        let trapBar = try #require(Exercise.catalog.first { $0.name == "Trap bar deadlift" })
        #expect(trapBar.requiresWeight)
        #expect(trapBar.muscleMap?.primary.contains(.glutes) == true)
    }

    @Test func eachExactPresetNameOrAliasHasOneOwner() {
        var owner = [String: String]()
        for exercise in Exercise.catalog {
            for name in exercise.searchNames {
                let key = ExerciseLibrary.matchingKey(name)
                if let previous = owner[key] {
                    #expect(previous == exercise.id, "Ambiguous exercise name: \(name)")
                }
                owner[key] = exercise.id
            }
        }
    }

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

    @Test func expandedCatalogueCoversCommonEquipmentAndCountsBodyweightReps() throws {
        #expect(Exercise.catalog.count >= 50)
        let facePull = try #require(Exercise.catalog.first { $0.id == "face-pull" })
        #expect(facePull.equipmentType == .cable)
        #expect(facePull.group == .shoulders)
        #expect(ExerciseMuscleMap.map(for: facePull.id)?.primary.contains(.rearShoulders) == true)
        let dip = try #require(Exercise.catalog.first { $0.id == "dip" })
        #expect(!dip.requiresWeight)
    }

    @Test func alternatePresetIDsStayStableWhenAnImportAlreadyUsesTheFirstAlternate() throws {
        let personal = Exercise(id: "face-pull", name: "My movement", shortName: "My movement", startingWeight: 0)
        let other = Exercise(id: "preset:1:face-pull", name: "Second movement", shortName: "Second movement", startingWeight: 0)
        let resolved = try ExerciseLibrary.validated(custom: [personal, other])
        let preset = try #require(resolved.first { $0.name == "Face pull" })
        #expect(preset.id != personal.id && preset.id != other.id)
        #expect(preset.muscleMap?.primary.contains(.rearShoulders) == true)
        #expect(resolved.first { $0.id == personal.id }?.muscleMap == nil)
        let reordered = try ExerciseLibrary.validated(custom: [other, personal])
        #expect(reordered.first { $0.name == "Face pull" } == preset)
    }

    @Test func aSavedExerciseCanKeepItsNameWhenTheCatalogueAddsThatMovement() throws {
        let legacy = Exercise(id: "custom-face-pull", name: "Face pull", shortName: "Face pull", startingWeight: 0,
                              muscleGroup: .shoulders, equipment: .cable)
        let library = try ExerciseLibrary.validated(custom: [legacy])
        #expect(library.filter { ExerciseLibrary.searchKey($0.name) == "face pull" }.map(\.id) == ["face-pull", legacy.id])
        #expect(library.first { $0.id == "face-pull" }?.displayName == "Face pull")
        #expect(library.first { $0.id == legacy.id }?.displayName == "Face pull (custom)")
        #expect(throws: (any Error).self) { try ExerciseLibrary.custom(named: "Face pull", existing: library) }
    }
}
