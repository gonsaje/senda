import Testing
@testable import SendaDomain

struct ExerciseMuscleMapTests {
    @Test func everyPresetHasAnOfflineMapForItsGuidedVariation() throws {
        for exercise in Exercise.catalog {
            let map = try #require(ExerciseMuscleMap.map(for: exercise.id))
            #expect(!map.primary.isEmpty)
            #expect(!map.variation.isEmpty)
            #expect(ExerciseFormGuide.guide(for: exercise.id) != nil)
        }
    }

    @Test func rolesAreDistinctAndContainNoDuplicateRegions() throws {
        for exercise in Exercise.catalog {
            let map = try #require(ExerciseMuscleMap.map(for: exercise.id))
            #expect(Set(map.primary).count == map.primary.count)
            #expect(Set(map.supporting).count == map.supporting.count)
            #expect(Set(map.stabilizing).count == map.stabilizing.count)
            #expect(Set(map.primary).isDisjoint(with: map.supporting))
            #expect(Set(map.primary).isDisjoint(with: map.stabilizing))
            #expect(Set(map.supporting).isDisjoint(with: map.stabilizing))
        }
    }

    @Test func unknownAndCustomExercisesDoNotBorrowAnatomyFromTheirNameOrGroup() throws {
        let custom = try ExerciseLibrary.custom(named: "Travel press", muscleGroup: .chest)
        #expect(ExerciseMuscleMap.map(for: custom.id) == nil)
        #expect(ExerciseMuscleMap.map(for: "unknown") == nil)
        #expect(ExerciseMuscleMap.map(for: "") == nil)
        #expect(ExerciseMuscleMap.map(for: "Bench") == nil)
    }

    @Test func pressingAndPullingHighlightDifferentNamedMuscles() throws {
        let bench = try #require(ExerciseMuscleMap.map(for: "bench"))
        let pullUp = try #require(ExerciseMuscleMap.map(for: "pull-up"))
        #expect(bench.primary.contains(.chest))
        #expect(bench.supporting.contains(.triceps))
        #expect(bench.supporting.contains(.frontShoulders))
        #expect(pullUp.primary.contains(.lats))
        #expect(pullUp.supporting.contains(.biceps))
        #expect(!pullUp.primary.contains(.chest))
    }

    @Test func hipHingingDiffersFromKneeExtensionAndTrunkBracing() throws {
        let deadlift = try #require(ExerciseMuscleMap.map(for: "deadlift"))
        let romanian = try #require(ExerciseMuscleMap.map(for: "romanian-deadlift"))
        let legExtension = try #require(ExerciseMuscleMap.map(for: "leg-extension"))
        #expect(deadlift.primary.contains(.quadriceps))
        #expect(romanian.primary.contains(.hamstrings))
        #expect(romanian.primary.contains(.glutes))
        #expect(!romanian.primary.contains(.quadriceps))
        #expect(legExtension.primary == [.quadriceps])
        #expect(romanian.stabilizing.contains(.spinalErectors))
        #expect(romanian.stabilizing.contains(.abdominals))
        #expect(!romanian.primary.contains(.abdominals))
    }

    @Test func ambiguousCatalogNamesUseTheExistingGuideVariation() throws {
        let triceps = try #require(ExerciseMuscleMap.map(for: "triceps-extension"))
        let calf = try #require(ExerciseMuscleMap.map(for: "calf-raise"))
        let curl = try #require(ExerciseMuscleMap.map(for: "leg-curl"))
        let lunge = try #require(ExerciseMuscleMap.map(for: "lunge"))
        #expect(triceps.variation == "Standing cable rope pressdown")
        #expect(triceps.primary == [.triceps])
        #expect(calf.variation == "Seated foot-press machine")
        #expect(calf.primary == [.calves])
        #expect(curl.variation == "Lying machine leg curl")
        #expect(curl.primary == [.hamstrings])
        #expect(lunge.variation == "Forward lunge with dumbbells")
    }

    @Test func muscleRegionsHaveDistinctReadableAndAnatomicalNames() {
        #expect(Set(MuscleRegion.allCases.map(\.name)).count == MuscleRegion.allCases.count)
        for region in MuscleRegion.allCases {
            #expect(!region.name.isEmpty)
            #expect(!region.anatomicalName.isEmpty)
        }
        #expect(MuscleRegion.chest.anatomicalName == "Pectoralis major")
        #expect(MuscleRegion.frontShoulders.anatomicalName == "Anterior deltoid")
        #expect(MuscleRegion.lats.anatomicalName == "Latissimus dorsi")
    }
}
