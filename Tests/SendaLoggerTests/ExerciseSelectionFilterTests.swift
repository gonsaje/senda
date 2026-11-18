import Testing
import SendaDomain
@testable import SendaLogger

struct ExerciseSelectionFilterTests {
    @Test func gymAndAvailableEquipmentNarrowPickerAndLearnSearches() throws {
        let ids = ["dumbbell-floor-press", "dumbbell-bench", "bench", "bodyweight-squat"]
        let exercises = Exercise.catalog.filter { ids.contains($0.id) }
        let home = ExerciseGymFilter(gym: .home, availableEquipment: [.dumbbells])
        let pick = ExerciseSelectionFilter.results(in: exercises, query: "press", group: .chest, equipment: .dumbbell, gymFilter: home)
        #expect(pick.map(\.id) == ["dumbbell-floor-press"])
        #expect(ExerciseFormGuide.search("press", in: exercises, gymFilter: home).map(\.id) == ["dumbbell-floor-press"])
        #expect(ExerciseSelectionFilter.results(in: exercises, query: "goblet", group: nil, equipment: nil, gymFilter: home).isEmpty)
        let expanded = ExerciseGymFilter(gym: .home, availableEquipment: [.dumbbells, .flatBench])
        #expect(Set(ExerciseFormGuide.search("press", in: exercises, gymFilter: expanded).map(\.id)) == ["dumbbell-floor-press", "dumbbell-bench"])
        #expect(ExerciseFormGuide.search("bench press", in: exercises).contains { $0.id == "bench" })
    }

    @Test func workbookAliasFindsOneChoiceInEachNotebook() throws {
        let saved = Exercise(id: "my-wall-sit", name: "Wall sit", shortName: "Wall sit", startingWeight: 0)
        let personalLibrary = try ExerciseLibrary.validated(custom: [saved])
        let fresh = ExerciseSelectionFilter.results(in: Exercise.catalog, query: "Wall chair", group: nil, equipment: nil)
        let personal = ExerciseSelectionFilter.results(in: personalLibrary, query: "Wall chair", group: nil, equipment: nil)
        #expect(fresh.map(\.name) == ["Wall sit"])
        #expect(personal.map(\.id) == [saved.id])
        #expect(personalLibrary.contains { $0.id == fresh.first?.id })
    }

    @Test func queryGroupAndEquipmentAlwaysIntersect() {
        let ids = ["bench", "dumbbell-bench", "incline-dumbbell-bench", "front-squat"]
        let exercises = Exercise.catalog.filter { ids.contains($0.id) }
        let results = ExerciseSelectionFilter.results(in: exercises, query: "bench", group: .legs, equipment: .barbell)
        #expect(results.isEmpty)
        #expect(ExerciseSelectionFilter.results(in: exercises, query: "bench", group: .chest, equipment: .dumbbell).map(\.id) == ["dumbbell-bench", "incline-dumbbell-bench"])
    }

    @Test func allGroupsIncludesEveryGroupAndClearFiltersRetainsQuery() {
        #expect(ExerciseSelectionFilter.results(in: Exercise.catalog, query: "", group: nil, equipment: nil) == Exercise.catalog)
        let ids = ["bench", "row", "cable-row", "one-arm-dumbbell-row", "machine-chest-supported-row", "inverted-row", "bodyweight-squat"]
        let exercises = Exercise.catalog.filter { ids.contains($0.id) }
        let restricted = ExerciseSelectionFilter.results(in: exercises, query: "row", group: .legs, equipment: .bodyweight)
        #expect(restricted.isEmpty)
        let cleared = ExerciseSelectionFilter.results(in: exercises, query: "row", group: nil, equipment: nil)
        #expect(cleared.map(\.id) == ["row", "cable-row", "one-arm-dumbbell-row", "machine-chest-supported-row", "inverted-row"])
    }

    @Test func normalizesSearchAndMatchesShortNames() {
        let exercise = Exercise(id: "custom", name: "Élévation latérale", shortName: "Side raise", startingWeight: 0, muscleGroup: .shoulders, equipment: .dumbbell)
        #expect(ExerciseSelectionFilter.results(in: [exercise], query: "  ELEVATION  ", group: nil, equipment: nil) == [exercise])
        #expect(ExerciseSelectionFilter.results(in: [exercise], query: " SIDE   RAISE ", group: .shoulders, equipment: .dumbbell) == [exercise])
    }

    @Test func searchesCommonExerciseSpellingsAndKeepsActiveFilters() {
        for (query, id) in [("bench press", "bench"), ("push up", "push-up"), ("chinup", "chin-up"),
                            ("quadriceps", "front-squat"), ("hamstrings", "leg-curl")] {
            #expect(ExerciseSelectionFilter.results(in: Exercise.catalog, query: query, group: nil, equipment: nil).contains { $0.id == id })
        }
        #expect(ExerciseSelectionFilter.results(in: Exercise.catalog, query: "pushup", group: nil, equipment: .barbell).isEmpty)
    }

    @Test func cappedSuggestionsPromoteExactNamesAliasesAndNamePrefixesAheadOfRecentBroadMatches() throws {
        let catalog = Exercise.catalog.sorted { $0.name < $1.name }
        for (query, id) in [("Squat", "squat"), ("bench press", "bench"), ("RDL", "romanian-deadlift")] {
            let relevant = ExerciseSelectionFilter.results(in: catalog, query: query, group: nil, equipment: nil)
            let recentVariantsFirst = relevant.filter { $0.id != id } + relevant.filter { $0.id == id }
            let suggestions = ExerciseSelectionFilter.inlineSuggestions(from: recentVariantsFirst, query: query)
            #expect(suggestions.first?.id == id)
            #expect(suggestions.count <= 5)
        }
        let metadataMatch = Exercise(id: "personal-fly", name: "Low fly", shortName: "Fly", startingWeight: 0, equipment: .cable)
        let nameContains = Exercise(id: "personal-curl", name: "Seated cable curl", shortName: "Curl", startingWeight: 0, equipment: .cable)
        let nameStarts = Exercise(id: "personal-row", name: "Cable rope row", shortName: "Rope row", startingWeight: 0, equipment: .cable)
        let recent = [metadataMatch, nameContains, nameStarts]
        #expect(ExerciseSelectionFilter.inlineSuggestions(from: recent, query: "cable").map(\.id) == [nameStarts.id, nameContains.id, metadataMatch.id])
        #expect(Array(ExerciseSelectionFilter.inlineSuggestions(from: recent, query: "")) == recent)
    }

    @Test func preservesRecentOrderAndReturnsUniqueExerciseIDs() {
        let newest = Exercise.catalog[2], older = Exercise.catalog[0]
        #expect(ExerciseSelectionFilter.results(in: [newest, older, newest], query: "", group: nil, equipment: nil) == [newest, older])
    }
}
