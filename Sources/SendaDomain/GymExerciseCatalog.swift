import Foundation

/// The offline exercise library. Saved workouts refer to the explicit IDs in the resource.
enum GymExerciseCatalog {
    struct Entry: Decodable {
        let id: String
        let name: String
        let group: MuscleGroup
        let equipment: ExerciseEquipment
        let setup: String
        let aliases: [String]?
        let primary: [MuscleRegion]?
        let supporting: [MuscleRegion]?
        let optionalLoad: Bool?

        var muscleMap: ExerciseMuscleMap? {
            guard let primary, !primary.isEmpty else { return nil }
            return ExerciseMuscleMap(primary: primary, supporting: supporting ?? [], stabilizing: [], variation: name)
        }
    }

    private struct Catalog: Decodable {
        let additions: [Entry]
        let existingAliases: [String: [String]]
    }

    private static let catalog: Catalog = {
        guard let url = Bundle.module.url(forResource: "GymExercises", withExtension: "json") else {
            preconditionFailure("Missing built-in exercise catalog")
        }
        do { return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url)) }
        catch { preconditionFailure("Invalid built-in exercise catalog: \(error)") }
    }()

    static let exercises = catalog.additions.map {
        Exercise(id: $0.id, name: $0.name, shortName: $0.name, startingWeight: 0,
                 muscleGroup: $0.group, equipment: $0.equipment)
    }
    static let entriesByID = Dictionary(uniqueKeysWithValues: catalog.additions.map { ($0.id, $0) })

    static func aliases(for id: String) -> [String] {
        entriesByID[id]?.aliases ?? catalog.existingAliases[id] ?? []
    }

    // Only presets introduced by this import can supersede a custom choice during this upgrade.
    static let newIDByName: [String: String] = {
        var ids = [String: String]()
        for entry in catalog.additions {
            for name in [entry.name] + (entry.aliases ?? []) {
                let key = ExerciseLibrary.matchingKey(name)
                precondition(ids[key] == nil || ids[key] == entry.id, "Ambiguous built-in exercise name: \(name)")
                ids[key] = entry.id
            }
        }
        return ids
    }()
}
