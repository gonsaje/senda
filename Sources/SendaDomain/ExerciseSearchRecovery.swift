import Foundation

/// Explains a specific exercise excluded by the current search filters.
public struct ExerciseSearchRecovery: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        /// Every group is needed. The items within a group are interchangeable.
        case missingEquipment([[GymEquipmentItem]])
        case differentGym(ExerciseGym), gymsUnspecified, equipmentUnspecified
        case differentMuscleGroup(MuscleGroup), differentMainEquipment(ExerciseEquipment)
    }

    public let exercise: Exercise
    public let reason: Reason
    public let alternatives: [Exercise]

    public static func find(query: String, in exercises: [Exercise], gymFilter: ExerciseGymFilter,
                            group: MuscleGroup? = nil, equipment: ExerciseEquipment? = nil,
                            includePartialMatch: Bool = true,
                            excludingAlternatives visibleIDs: Set<String> = []) -> Self? {
        guard gymFilter.gym != nil || gymFilter.availableEquipment != nil || group != nil || equipment != nil else { return nil }
        let key = ExerciseLibrary.matchingKey(query)
        guard !key.isEmpty else { return nil }
        guard let target = namedExercise(key: key, in: exercises, includePartialMatch: includePartialMatch) else { return nil }

        let reason: Reason
        if let excluded = gymFilter.exclusion(for: target) { reason = excluded }
        else if let group, target.group != group { reason = .differentMuscleGroup(target.group) }
        else if let equipment, target.equipmentType != equipment { reason = .differentMainEquipment(target.equipmentType) }
        else { return nil }

        let sourceID = target.catalogAliasID ?? target.presetID
        let related = sourceID.flatMap { alternativesByPreset[$0] } ?? []
        var available: [String: Exercise] = [:]
        if !related.isEmpty {
            for candidate in exercises where candidate.isLibraryChoice && candidate.id != target.id {
                guard let id = candidate.catalogAliasID ?? candidate.presetID, related.contains(id),
                      !visibleIDs.contains(candidate.id),
                      group.map({ candidate.group == $0 }) ?? true,
                      equipment.map({ candidate.equipmentType == $0 }) ?? true,
                      gymFilter.matches(candidate) else { continue }
                available[id] = candidate
            }
        }
        return Self(exercise: target, reason: reason, alternatives: Array(related.compactMap { available[$0] }.prefix(2)))
    }

    // The application searches on each keystroke. Presets and their aliases are immutable.
    private static let presetNames = Dictionary(uniqueKeysWithValues: Exercise.catalog.map {
        ($0.id, $0.searchNames.map(ExerciseLibrary.matchingKey))
    })

    private static func namedExercise(key: String, in exercises: [Exercise], includePartialMatch: Bool) -> Exercise? {
        var exact: Exercise?
        var shortNameOnly = false
        var partial: Exercise?
        var partialCount = 0
        for exercise in exercises where exercise.isLibraryChoice {
            let names = exercise.presetID.flatMap { presetNames[$0] }
                ?? exercise.searchNames.map(ExerciseLibrary.matchingKey)
            if names.contains(key) {
                guard exact == nil else { return nil }
                exact = exercise
                shortNameOnly = exercise.shortName != exercise.shortName.uppercased()
                    && ExerciseLibrary.matchingKey(exercise.shortName) == key
                    && ExerciseLibrary.matchingKey(exercise.name) != key
                    && !((exercise.catalogAliasID ?? exercise.presetID).map { id in
                        GymExerciseCatalog.aliases(for: id).contains { ExerciseLibrary.matchingKey($0) == key }
                    } ?? false)
            } else if names.contains(where: { $0.contains(key) }) {
                partialCount += 1
                partial = exercise
            }
        }
        if let exact { return shortNameOnly && partialCount > 0 ? nil : exact }
        return includePartialMatch && key.count >= 4 && partialCount == 1 ? partial : nil
    }

    // The offline catalog's movement families, narrowed to related variations.
    // A movement can appear in more than one family (for example, push-ups and
    // horizontal presses). Preserve each family's order and suggest each ID once.
    static let alternativesByPreset: [String: [String]] = {
        guard let url = Bundle.module.url(forResource: "ExerciseAlternativeFamilies", withExtension: "json") else {
            preconditionFailure("Missing exercise alternative families")
        }
        do {
            let families = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: url))
            var index: [String: [String]] = [:]
            for (_, family) in families.sorted(by: { $0.key < $1.key }) {
                for id in family {
                    let previous = index[id] ?? []
                    index[id] = previous + family.filter { $0 != id && !previous.contains($0) }
                }
            }
            return index
        } catch {
            preconditionFailure("Invalid exercise alternative families: \(error)")
        }
    }()
}
