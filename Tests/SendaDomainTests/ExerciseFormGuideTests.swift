import Testing
@testable import SendaDomain
struct ExerciseFormGuideTests {
    @Test func originalGuidedExercisesKeepTheirOfflineGuidesAndSources() throws {
        for exercise in Exercise.originalCatalog {
            let guide = try #require(ExerciseFormGuide.guide(for: exercise.id))
            #expect(guide.id == exercise.id)
            #expect(!guide.setup.isEmpty && !guide.movement.isEmpty && !guide.cue.isEmpty)
            #expect(guide.sourceURL.scheme == "https")
        }
        #expect(Set(ExerciseFormGuide.all.map(\.id)) == Set(Exercise.originalCatalog.map(\.id)))
    }
    @Test func searchMatchesExerciseNamesAliasesMuscleAndEquipment() {
        #expect(ExerciseFormGuide.search("  dL  ", in: Exercise.catalog).contains { $0.id == "deadlift" })
        let chest = Set(ExerciseFormGuide.search("chest", in: Exercise.catalog).map(\.id))
        #expect(Set(["bench", "dumbbell-bench", "push-up", "incline-dumbbell-bench", "machine-chest-press"]).isSubset(of: chest))
        #expect(!chest.contains("front-squat"))
        #expect(ExerciseFormGuide.search("cable", in: Exercise.catalog).contains { $0.id == "cable-row" })
        #expect(ExerciseFormGuide.search("unmatched-name", in: Exercise.catalog).isEmpty)
    }
    @Test func searchCombinesMuscleGroupAndEquipment() {
        let matches = ExerciseFormGuide.search("Chest Barbell", in: Exercise.catalog)
        #expect(matches.contains { $0.id == "bench" })
        #expect(!matches.contains { $0.id == "dumbbell-bench" })
    }

    @Test func searchesPrintedVariationNamesAndPrimaryMuscles() {
        for (query, id) in [("bench press", "bench"), ("pull up", "pull-up"), ("pushup", "push-up"),
                            ("hamstrings", "leg-curl"), ("quadriceps", "front-squat")] {
            #expect(ExerciseFormGuide.search(query, in: Exercise.catalog).contains { $0.id == id })
        }
    }

    @Test func customExercisesStaySearchableWithoutFabricatedGuides() throws {
        let custom = try ExerciseLibrary.custom(named: "Travel press")
        #expect(ExerciseFormGuide.search("travel", in: Exercise.catalog + [custom]).map(\.id) == [custom.id])
        #expect(ExerciseFormGuide.guide(for: custom.id) == nil)
        #expect(ExerciseFormGuide.guide(for: "unknown") == nil)
    }
}
