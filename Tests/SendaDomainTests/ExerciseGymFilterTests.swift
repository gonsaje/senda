import Foundation
import Testing
@testable import SendaDomain

struct ExerciseGymFilterTests {
    private func preset(_ id: String) throws -> Exercise {
        try #require(Exercise.catalog.first { $0.id == id })
    }

    @Test func eachPresetHasGymAndEquipmentData() {
        let fullGym = ExerciseGymFilter(availableEquipment: Set(GymEquipmentItem.allCases))
        for exercise in Exercise.catalog {
            #expect(fullGym.matches(exercise), "Missing setup for \(exercise.id)")
            #expect(ExerciseGym.allCases.contains { ExerciseGymFilter(gym: $0).matches(exercise) },
                    "Missing gyms for \(exercise.id)")
        }
        #expect(Set(GymEquipmentItem.allCases.map(\.label)).count == GymEquipmentItem.allCases.count)
    }

    @Test func allComponentsOfACompoundSetupMustBeAvailable() throws {
        let exercise = try preset("bench")
        let setup: Set<GymEquipmentItem> = [.barbell, .weightPlates, .rack, .flatBench]
        #expect(ExerciseGymFilter(availableEquipment: setup).matches(exercise))
        for item in setup {
            #expect(!ExerciseGymFilter(availableEquipment: setup.subtracting([item])).matches(exercise))
        }
        #expect(!ExerciseGymFilter(availableEquipment: [.dumbbells]).matches(try preset("biceps-curl")))
        #expect(ExerciseGymFilter(availableEquipment: [.dumbbells, .chair]).matches(try preset("biceps-curl")))
        #expect(ExerciseGymFilter(availableEquipment: [.dumbbells]).matches(try preset("dumbbell-shoulder-press")))
    }

    @Test func substitutesMatchIndividually() throws {
        let suitcase = try preset("suitcase-deadlift")
        #expect(ExerciseGymFilter(availableEquipment: [.kettlebells]).matches(suitcase))
        #expect(ExerciseGymFilter(availableEquipment: [.dumbbells]).matches(suitcase))
        #expect(!ExerciseGymFilter(availableEquipment: [.barbell]).matches(suitcase))
        let elevated = try preset("hands-elevated-push-up")
        for item in [GymEquipmentItem.flatBench, .adjustableBench, .box] {
            #expect(ExerciseGymFilter(availableEquipment: [item]).matches(elevated))
        }
    }

    @Test func machinesIncludeTheirStandardHandlesAndKeepSpecializedAttachmentsDistinct() throws {
        #expect(ExerciseGymFilter(availableEquipment: [.cableRow]).matches(try preset("cable-row")))
        let kickback = try preset("cable-glute-kickback")
        #expect(!ExerciseGymFilter(availableEquipment: [.cableMachine]).matches(kickback))
        #expect(ExerciseGymFilter(availableEquipment: [.cableMachine, .ankleCuff]).matches(kickback))
        #expect(!ExerciseGymFilter(availableEquipment: [.hackSquat]).matches(try preset("hack-squat")))
        #expect(ExerciseGymFilter(availableEquipment: [.hackSquat, .weightPlates]).matches(try preset("hack-squat")))
    }

    @Test func ringsAndBandsRequireTheirSupportingApparatus() throws {
        let ringDip = try preset("strict-ring-dip")
        #expect(!ExerciseGymFilter(availableEquipment: [.rings]).matches(ringDip))
        #expect(ExerciseGymFilter(availableEquipment: [.rings, .overheadAnchor]).matches(ringDip))
        let assisted = try preset("band-assisted-pull-up")
        #expect(!ExerciseGymFilter(availableEquipment: [.resistanceBand]).matches(assisted))
        #expect(ExerciseGymFilter(availableEquipment: [.pullUpBar, .resistanceBand]).matches(assisted))
    }

    @Test func noEquipmentAndAnyEquipmentAreDifferent() throws {
        let floor = try preset("push-up")
        let hanging = try preset("pull-up")
        let noEquipment = ExerciseGymFilter(availableEquipment: [])
        #expect(noEquipment.matches(floor))
        #expect(!noEquipment.matches(hanging))
        #expect(!noEquipment.matches(try preset("dip")))
        #expect(ExerciseGymFilter().matches(hanging))
        #expect(ExerciseGymFilter(availableEquipment: [.pullUpBar]).matches(hanging))
    }

    @Test func gymAndGearMustBothMatch() throws {
        let stone = try preset("atlas-stone-load")
        #expect(ExerciseGymFilter(gym: .specialty).matches(stone))
        #expect(!ExerciseGymFilter(gym: .home).matches(stone))
        #expect(!ExerciseGymFilter(gym: .specialty, availableEquipment: [.dumbbells]).matches(stone))
        #expect(ExerciseGymFilter(gym: .home, availableEquipment: [.dumbbells, .flatBench]).matches(try preset("dumbbell-bench")))
    }

    @Test func savedAliasesAndAlternatePresetsKeepTheirSetupWithoutBorrowingAnID() throws {
        let oldAlias = Exercise(id: "my-wall-chair", name: "Wall chair", shortName: "Wall chair", startingWeight: 0)
        let idCollision = Exercise(id: "wall-sit", name: "My custom movement", shortName: "My move", startingWeight: 0)
        let library = try ExerciseLibrary.validated(custom: [idCollision, oldAlias])
        let alias = try #require(library.first { $0.id == oldAlias.id })
        let alternate = try #require(library.first { $0.presetID == "wall-sit" })
        let unrelated = try #require(library.first { $0.id == idCollision.id })
        let atHome = ExerciseGymFilter(gym: .home, availableEquipment: [.wall])
        #expect(atHome.matches(alias))
        #expect(atHome.matches(alternate))
        #expect(!atHome.matches(unrelated))
        #expect(!ExerciseGymFilter(availableEquipment: []).matches(unrelated))
        #expect(ExerciseGymFilter().matches(unrelated))
    }

    @Test func filtersRoundTripWithAnyNoOrSelectedEquipment() throws {
        for filter in [ExerciseGymFilter(), .init(availableEquipment: []), .init(gym: .crossFit, availableEquipment: [.dumbbells])] {
            let data = try JSONEncoder().encode(filter)
            #expect(try JSONDecoder().decode(ExerciseGymFilter.self, from: data) == filter)
        }
    }

    @Test func savedCustomSetupMatchesEachGymAndRequiresEverySelectedItem() throws {
        let json = #"{"id":"custom-pair","name":"My bench pair","shortName":"Pair","startingWeight":0,"customSetup":{"gyms":["home","commercial"],"requiredEquipment":["dumbbells","flatBench"]}}"#
        let saved = try JSONDecoder().decode(Exercise.self, from: Data(json.utf8))
        let library = try ExerciseLibrary.validated(custom: [saved])
        let exercise = try #require(library.first { $0.id == saved.id })
        for gym in [ExerciseGym.home, .commercial] {
            #expect(ExerciseGymFilter(gym: gym, availableEquipment: [.dumbbells, .flatBench, .box]).matches(exercise))
        }
        #expect(!ExerciseGymFilter(gym: .crossFit).matches(exercise))
        #expect(!ExerciseGymFilter(availableEquipment: [.flatBench]).matches(exercise))
        #expect(!ExerciseGymFilter(availableEquipment: []).matches(exercise))
    }

    @Test func customAliasOverridesOnlyTheMetadataSomeoneProvided() throws {
        let json = #"{"id":"custom-chair","name":"Wall chair","shortName":"Wall chair","startingWeight":0,"customSetup":{"gyms":["specialty"]}}"#
        let saved = try JSONDecoder().decode(Exercise.self, from: Data(json.utf8))
        let library = try ExerciseLibrary.validated(custom: [saved])
        let alias = try #require(library.first { $0.id == saved.id })
        #expect(ExerciseGymFilter(gym: .specialty, availableEquipment: [.wall]).matches(alias))
        #expect(!ExerciseGymFilter(gym: .home).matches(alias))
        #expect(!ExerciseGymFilter(availableEquipment: []).matches(alias))

        var noGear = saved
        noGear.customSetup = .init(requiredEquipment: [])
        let edited = try #require(ExerciseLibrary.validated(custom: [noGear]).first { $0.id == noGear.id })
        #expect(ExerciseGymFilter(gym: .home, availableEquipment: []).matches(edited))
        #expect(!ExerciseGymFilter(gym: .specialty).matches(edited))
    }

    @Test func standaloneCustomExercisesDistinguishUnspecifiedFromNoEquipment() throws {
        var exercise = try ExerciseLibrary.custom(named: "My floor sequence")
        exercise.customSetup.gyms = [.home]
        #expect(ExerciseGymFilter(gym: .home).matches(exercise))
        #expect(!ExerciseGymFilter(gym: .home, availableEquipment: []).matches(exercise))
        exercise.customSetup = .init(requiredEquipment: [])
        #expect(ExerciseGymFilter(availableEquipment: []).matches(exercise))
        #expect(ExerciseGymFilter(availableEquipment: [.box]).matches(exercise))
        #expect(!ExerciseGymFilter(gym: .home).matches(exercise))
    }

    @Test func searchFindsCustomEquipmentNamesAndAliasesAlongsideActiveFilters() throws {
        let setup = CustomExerciseSetup(gyms: [.home], requiredEquipment: [.dumbbells, .flatBench])
        let exercise = try ExerciseLibrary.custom(named: "My press variation", equipment: .other, customSetup: setup)
        let equipped = ExerciseGymFilter(gym: .home, availableEquipment: [.dumbbells, .flatBench])
        for query in ["dumbbells", "flat bench", "hand weights"] {
            #expect(ExerciseFormGuide.search(query, in: [exercise], gymFilter: equipped) == [exercise])
            #expect(ExerciseFormGuide.search(query, in: [exercise], gymFilter: .init(availableEquipment: [.dumbbells])).isEmpty)
        }
    }
}
