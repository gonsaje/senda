import Testing
@testable import SendaDomain
struct ExerciseFormGuideTests {
    @Test func everyPresetHasItsOwnOfflineGuideAndSource() throws {
        for exercise in Exercise.catalog {
            let guide = try #require(ExerciseFormGuide.guide(for: exercise.id))
            #expect(guide.id == exercise.id)
            #expect(!guide.setup.isEmpty && !guide.movement.isEmpty && !guide.cue.isEmpty)
            #expect(guide.sourceURL.scheme == "https")
        }
        #expect(Set(ExerciseFormGuide.all.map(\.id)).count == Exercise.catalog.count)
    }
    @Test func searchMatchesExerciseNamesAliasesMuscleAndEquipment() {
        #expect(ExerciseFormGuide.search("  dL  ", in: Exercise.catalog).contains { $0.id == "deadlift" })
        #expect(ExerciseFormGuide.search("chest", in: Exercise.catalog).map(\.id).sorted() == ["bench", "dumbbell-bench", "push-up"])
        #expect(ExerciseFormGuide.search("cable", in: Exercise.catalog).contains { $0.id == "cable-row" })
        #expect(ExerciseFormGuide.search("unmatched-name", in: Exercise.catalog).isEmpty)
    }
    @Test func customExercisesStaySearchableWithoutFabricatedGuides() throws {
        let custom = try ExerciseLibrary.custom(named: "Travel press")
        #expect(ExerciseFormGuide.search("travel", in: Exercise.catalog + [custom]).map(\.id) == [custom.id])
        #expect(ExerciseFormGuide.guide(for: custom.id) == nil)
        #expect(ExerciseFormGuide.guide(for: "unknown") == nil)
    }
}
