import Testing
@testable import SendaDomain

struct ExerciseMuscleMapTests {
    @Test func everyPresetHasReviewedDiscoveryTargetsAndValidTrackingRoles() throws {
        #expect(Exercise.catalog.count == 709)
        for exercise in Exercise.catalog {
            #expect(!exercise.taggedMuscles.isEmpty, "\(exercise.id)")
            #expect(Set(exercise.taggedMuscles).count == exercise.taggedMuscles.count)
            #expect(Set(exercise.primaryTrackedMuscles).isSubset(of: Set(exercise.trackedMuscles)))
            #expect(Set(exercise.trackedMuscles).isSubset(of: Set(exercise.taggedMuscles)))
            if let map = exercise.muscleMap {
                #expect(Set(map.loadedStabilizers).isSubset(of: Set(map.stabilizing)))
            }
        }
    }

    @Test func deadliftsTrackLoadedSpinalErectorsAcrossEquipmentAndVariations() throws {
        let variations = Exercise.catalog.filter { $0.id.contains("deadlift") || ["barbell-rack-pull", "barbell-block-pull"].contains($0.id) }
        #expect(variations.count >= 16)
        for exercise in variations {
            #expect(exercise.taggedGroups.contains(.back), "\(exercise.id)")
            #expect(exercise.taggedGroups.contains(.legs), "\(exercise.id)")
            #expect(exercise.trackedMuscles.contains(.spinalErectors), "\(exercise.id)")
            #expect(!exercise.primaryTrackedMuscles.contains(.spinalErectors), "\(exercise.id)")
        }
        let bench = try #require(Exercise.catalog.first { $0.id == "bench" })
        #expect(bench.taggedGroups == [.chest, .shoulders, .arms])
        #expect(!bench.trackedMuscles.contains(.abdominals))
    }

    @Test func mobilityAndConditioningHaveDiscoveryTagsSeparateFromStrengthSets() throws {
        for (id, region) in [("supine-hamstring-stretch-with-strap", MuscleRegion.hamstrings), ("running", .calves),
                             ("doorway-chest-stretch", .chest), ("foam-pad-single-leg-stand", .glutes)] {
            let exercise = try #require(Exercise.catalog.first { $0.id == id })
            #expect(exercise.taggedMuscles.contains(region))
            #expect(exercise.trackedMuscles.isEmpty)
        }
        for exercise in Exercise.catalog where exercise.id.hasPrefix("manual-isometric-neck-") {
            #expect(exercise.group == .neck && exercise.taggedGroups == [.neck])
        }
        for (id, region) in [("machine-seated-hip-adduction", MuscleRegion.adductors),
                             ("side-lying-dumbbell-external-rotation", .rotatorCuff),
                             ("scapular-push-up", .serratus), ("wall-tibialis-raise", .shins),
                             ("manual-isometric-neck-flexion", .neck)] {
            let exercise = try #require(Exercise.catalog.first { $0.id == id })
            #expect(exercise.primaryTrackedMuscles == [region])
        }
    }

    @Test func establishedPresetsKeepTheirOfflineMaps() throws {
        for exercise in Exercise.originalCatalog + ExpandedExerciseCatalog.exercises {
            let map = try #require(ExerciseMuscleMap.map(for: exercise.id))
            #expect(!map.primary.isEmpty)
            #expect(!map.variation.isEmpty)
        }
    }

    @Test func rolesAreDistinctAndContainNoDuplicateRegions() throws {
        for exercise in Exercise.catalog {
            guard let map = ExerciseMuscleMap.map(for: exercise.id) else { continue }
            #expect(!map.primary.isEmpty && !map.variation.isEmpty)
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
