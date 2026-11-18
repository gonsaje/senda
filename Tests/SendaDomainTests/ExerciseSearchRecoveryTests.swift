import Testing
@testable import SendaDomain

struct ExerciseSearchRecoveryTests {
    let home = ExerciseGymFilter(gym: .home, availableEquipment: [.dumbbells])

    @Test func everyRelatedIDResolvesAndEachListIsDistinct() {
        let ids = Set(Exercise.catalog.map(\.id))
        #expect(!ExerciseSearchRecovery.alternativesByPreset.isEmpty)
        for (id, alternatives) in ExerciseSearchRecovery.alternativesByPreset {
            #expect(ids.contains(id) && !alternatives.isEmpty)
            #expect(ids.isSuperset(of: alternatives))
            #expect(!alternatives.contains(id) && Set(alternatives).count == alternatives.count)
        }
    }

    @Test func narrowFamiliesKeepOppositeShoulderMovementsSeparate() throws {
        let result = try #require(ExerciseSearchRecovery.find(query: "Cable shoulder external rotation",
            in: Exercise.catalog, gymFilter: .init(availableEquipment: [.resistanceBand, .bandAnchor, .dumbbells])))
        #expect(!result.alternatives.isEmpty)
        #expect(result.alternatives.allSatisfy { $0.id.contains("external-rotation") })
    }

    @Test func missingBenchShowsInterchangeableBenchesAndOnlyAvailableRelatedMovements() throws {
        let recovery = try #require(ExerciseSearchRecovery.find(query: "Flat dumbbell press", in: Exercise.catalog,
                                                                gymFilter: home))
        #expect(recovery.exercise.id == "dumbbell-bench")
        #expect(recovery.reason == .missingEquipment([[.flatBench, .adjustableBench, .anchoredBench]]))
        #expect(recovery.alternatives.first?.id == "dumbbell-floor-press")
        #expect(recovery.alternatives.allSatisfy { home.matches($0) })
        let withBench = ExerciseGymFilter(gym: .home, availableEquipment: [.dumbbells, .adjustableBench])
        #expect(ExerciseSearchRecovery.find(query: "Flat dumbbell press", in: Exercise.catalog, gymFilter: withBench) == nil)
    }

    @Test func alternativesHonorAdditionalFiltersAndAvoidRepeatingVisibleResults() throws {
        let result = try #require(ExerciseSearchRecovery.find(query: "dumbbell bench press", in: Exercise.catalog,
            gymFilter: home, group: .chest, equipment: .dumbbell, includePartialMatch: false))
        #expect(result.alternatives.map(\.id) == ["dumbbell-floor-press"])
        let alreadyVisible = try #require(ExerciseSearchRecovery.find(query: "dumbbell bench press", in: Exercise.catalog,
            gymFilter: home, group: .chest, equipment: .dumbbell, excludingAlternatives: ["dumbbell-floor-press"]))
        #expect(alreadyVisible.alternatives.isEmpty)
    }

    @Test func ambiguousOrUnrecognizedNamesNeverTriggerGuesses() {
        for query in ["", "dumbbell", "press", "unrecognized exercise"] {
            #expect(ExerciseSearchRecovery.find(query: query, in: Exercise.catalog, gymFilter: home) == nil)
        }
    }

    @Test func specificAcronymsStillIdentifyTheRequestedExercise() throws {
        let result = try #require(ExerciseSearchRecovery.find(query: "rdl", in: Exercise.catalog, gymFilter: home))
        #expect(result.exercise.id == "romanian-deadlift")
    }

    @Test func unexplainedCustomSetupsNeverInventMissingGearOrExerciseEquivalents() throws {
        let custom = try ExerciseLibrary.custom(named: "Porch drill")
        let result = try #require(ExerciseSearchRecovery.find(query: "Porch drill", in: [custom],
            gymFilter: .init(availableEquipment: [.dumbbells])))
        #expect(result.reason == .equipmentUnspecified)
        #expect(result.alternatives.isEmpty)
        let otherGym = try #require(ExerciseSearchRecovery.find(query: "Porch drill", in: [custom], gymFilter: home))
        #expect(otherGym.reason == .gymsUnspecified)
    }

    @Test func alternativeRowsHonorNotebookIDsWhenAPresetIsShadowed() throws {
        let old = Exercise(id: "custom-floor", name: "DB floor press", shortName: "Floor", startingWeight: 0)
        let exercises = try ExerciseLibrary.validated(custom: [old])
        let result = try #require(ExerciseSearchRecovery.find(query: "Flat dumbbell press", in: exercises, gymFilter: home))
        #expect(result.alternatives.first?.id == "custom-floor")
        #expect(!result.alternatives.contains { $0.id == "dumbbell-floor-press" })
    }
}
