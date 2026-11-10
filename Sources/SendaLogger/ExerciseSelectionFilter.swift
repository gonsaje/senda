import SendaDomain

/// Applies the same constraints to recent choices and the exercise library.
/// Input order is retained, so a newest-first recent list stays newest first.
public enum ExerciseSelectionFilter {
    public static func results(in exercises: [Exercise], query: String, group: MuscleGroup?, equipment: ExerciseEquipment?) -> [Exercise] {
        let key = ExerciseLibrary.searchKey(query)
        var seen = Set<String>()
        return exercises.filter { exercise in
            (group == nil || exercise.group == group)
                && (equipment == nil || exercise.equipmentType == equipment)
                && (key.isEmpty || ExerciseLibrary.searchKey(exercise.name).contains(key)
                    || ExerciseLibrary.searchKey(exercise.shortName).contains(key))
                && seen.insert(exercise.id).inserted
        }
    }
}
