import Testing
import SendaDomain
@testable import SendaLogger

struct ExerciseSelectionFilterTests {
    @Test func queryGroupAndEquipmentAlwaysIntersect() {
        let results = ExerciseSelectionFilter.results(in: Exercise.catalog, query: "bench", group: .legs, equipment: .barbell)
        #expect(results.isEmpty)
        #expect(ExerciseSelectionFilter.results(in: Exercise.catalog, query: "bench", group: .chest, equipment: .dumbbell).map(\.id) == ["dumbbell-bench"])
    }

    @Test func allGroupsIncludesEveryGroupAndClearFiltersRetainsQuery() {
        #expect(ExerciseSelectionFilter.results(in: Exercise.catalog, query: "", group: nil, equipment: nil) == Exercise.catalog)
        let restricted = ExerciseSelectionFilter.results(in: Exercise.catalog, query: "row", group: .legs, equipment: .bodyweight)
        #expect(restricted.isEmpty)
        let cleared = ExerciseSelectionFilter.results(in: Exercise.catalog, query: "row", group: nil, equipment: nil)
        #expect(cleared.map(\.id) == ["row", "cable-row"])
    }

    @Test func normalizesSearchAndMatchesShortNames() {
        let exercise = Exercise(id: "custom", name: "Élévation latérale", shortName: "Side raise", startingWeight: 0, muscleGroup: .shoulders, equipment: .dumbbell)
        #expect(ExerciseSelectionFilter.results(in: [exercise], query: "  ELEVATION  ", group: nil, equipment: nil) == [exercise])
        #expect(ExerciseSelectionFilter.results(in: [exercise], query: " SIDE   RAISE ", group: .shoulders, equipment: .dumbbell) == [exercise])
    }

    @Test func preservesRecentOrderAndReturnsUniqueExerciseIDs() {
        let newest = Exercise.catalog[2], older = Exercise.catalog[0]
        #expect(ExerciseSelectionFilter.results(in: [newest, older, newest], query: "", group: nil, equipment: nil) == [newest, older])
    }
}
