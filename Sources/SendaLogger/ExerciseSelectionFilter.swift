import SendaDomain

/// Applies the same constraints to recent choices and the exercise library.
/// Input order is retained, so a newest-first recent list stays newest first.
public enum ExerciseSelectionFilter {
    /// Matches already arrive in recent-first order. Preserve that order within each level of relevance.
    public static func inlineSuggestions(from matches: [Exercise], query: String) -> ArraySlice<Exercise> {
        rankedMatches(matches, query: query).prefix(5)
    }

    public static func rankedMatches(_ matches: [Exercise], query: String) -> [Exercise] {
        let key = ExerciseLibrary.matchingKey(query)
        guard !key.isEmpty else { return matches }
        let ranked = matches.map { exercise in
            let names = exercise.searchNames.map(ExerciseLibrary.matchingKey)
            let rank: Int
            if names.contains(key) { rank = 0 }
            else if names.contains(where: { $0.hasPrefix(key) }) { rank = 1 }
            else if names.contains(where: { $0.contains(key) }) { rank = 2 }
            else { rank = 3 }
            return (rank: rank, exercise: exercise)
        }
        return ranked.sorted { $0.rank < $1.rank }.map(\.exercise)
    }

    public static func results(in exercises: [Exercise], query: String, group: MuscleGroup?, equipment: ExerciseEquipment?,
                               gymFilter: ExerciseGymFilter = .init()) -> [Exercise] {
        let key = ExerciseLibrary.matchingKey(query)
        var seen = Set<String>()
        return exercises.filter { exercise in
            exercise.isLibraryChoice
                && (group == nil || exercise.group == group)
                && (equipment == nil || exercise.equipmentType == equipment)
                && gymFilter.matches(exercise)
                && (key.isEmpty || exercise.matchesCatalogSearch(key: key))
                && seen.insert(exercise.id).inserted
        }
    }
}
