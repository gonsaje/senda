import Foundation

public enum ExerciseLibrary {
    public static let initialWorkoutIDs = ["bench", "deadlift", "squat"]

    public static func custom(named name: String, existing: [Exercise] = Exercise.catalog, muscleGroup: MuscleGroup? = nil,
                              equipment: ExerciseEquipment? = nil, customSetup: CustomExerciseSetup = .init(),
                              customMuscleTags: [MuscleRegion] = []) throws -> Exercise {
        let name = try availableName(name, in: existing)
        return Exercise(id: "custom-\(UUID().uuidString.lowercased())", name: name, shortName: name, startingWeight: 0,
                        muscleGroup: muscleGroup, equipment: equipment, customSetup: customSetup, customMuscleTags: customMuscleTags)
    }

    /// Callers must also confirm this record belongs to the notebook's saved custom library.
    public static func canManageCustom(_ exercise: Exercise) -> Bool {
        if case .alternatePreset = exercise.origin { return false }
        let name = matchingKey(exercise.name)
        guard !originalIDs.contains(exercise.id), GymExerciseCatalog.newIDByName[name] == nil else { return false }
        // An older custom record can independently own an ID that a later catalog introduced.
        guard let position = presetIndex[exercise.id] else { return true }
        return matchingKey(Exercise.catalog[position].name) != name
    }

    public static func editCustom(_ exercise: Exercise, named name: String, existing: [Exercise],
                                  muscleGroup: MuscleGroup? = nil, equipment: ExerciseEquipment? = nil,
                                  customSetup: CustomExerciseSetup = .init(), customMuscleTags: [MuscleRegion]? = nil) throws -> Exercise {
        guard canManageCustom(exercise) else { throw ExerciseLibraryError.protectedExercise }
        let preservedName = cleaned(name) == exercise.name
        let name = preservedName ? exercise.name : try availableName(name, in: existing, excluding: exercise.id)
        return Exercise(id: exercise.id, name: name, shortName: preservedName ? exercise.shortName : name,
                        startingWeight: exercise.startingWeight, muscleGroup: muscleGroup, equipment: equipment,
                        customSetup: customSetup, isArchived: exercise.isArchived,
                        customMuscleTags: customMuscleTags ?? exercise.customMuscleTags)
    }

    private static let originalIDs = Set(Exercise.originalCatalog.map(\.id))
    private static let originalNames = Set(Exercise.originalCatalog.flatMap(keys))
    static let presetIDs = Set(Exercise.catalog.map(\.id))
    private static let presetIndex = Dictionary(uniqueKeysWithValues: Exercise.catalog.enumerated().map { ($0.element.id, $0.offset) })
    private static let presetNames = Set(Exercise.catalog.map { searchKey($0.name) })

    public static func validated(custom: [Exercise]) throws -> [Exercise] {
        var ids = originalIDs
        var activeNames = Set<String>()
        for exercise in custom {
            let namesForExercise = keys(exercise)
            guard !exercise.id.isEmpty, exercise.id.count <= 80,
                  exercise.id.unicodeScalars.allSatisfy({ !$0.properties.isWhitespace && $0.properties.generalCategory != .control }),
                  ids.insert(exercise.id).inserted,
                  validName(exercise.name), exercise.name == cleaned(exercise.name),
                  validName(exercise.shortName), exercise.shortName == cleaned(exercise.shortName),
                  NumericField.weight.range.contains(exercise.startingWeight),
                  Set(exercise.customMuscleTags).count == exercise.customMuscleTags.count,
                  originalNames.isDisjoint(with: namesForExercise) else { throw ExerciseLibraryError.invalidLibrary }
            if !exercise.isArchived {
                guard activeNames.isDisjoint(with: namesForExercise) else { throw ExerciseLibraryError.invalidLibrary }
                activeNames.formUnion(namesForExercise)
            }
        }
        return resolved(custom: custom)
    }

    /// Old custom IDs keep their meaning in recorded history, drafts, goals and backups.
    /// Only a preset introduced later needs an alternate ID in that particular notebook.
    public static func resolved(custom: [Exercise]) -> [Exercise] {
        guard !custom.isEmpty else { return Exercise.catalog }
        let customIDs = Set(custom.map(\.id))
        var presets = Exercise.catalog
        for id in customIDs {
            guard let position = presetIndex[id] else { continue }
            let preset = presets[position]
            var index = 1
            var alternateID = "preset:\(index):\(preset.id)"
            while customIDs.contains(alternateID) {
                index += 1
                alternateID = "preset:\(index):\(preset.id)"
            }
            var alternate = Exercise(id: alternateID, name: preset.name, shortName: preset.shortName,
                                     startingWeight: preset.startingWeight, muscleGroup: preset.group, equipment: preset.equipmentType)
            alternate.origin = .alternatePreset(preset.id)
            presets[position] = alternate
        }
        let personal = custom.map { exercise in
            if let id = GymExerciseCatalog.newIDByName[matchingKey(exercise.name)], let position = presetIndex[id] {
                if !exercise.isArchived { presets[position].isLibraryChoice = false }
                var result = exercise
                result.origin = .custom(sharesName: false)
                result.catalogAliasID = id
                return result
            }
            let sharesName = presetNames.contains(searchKey(exercise.name))
            guard sharesName || presetIDs.contains(exercise.id) else { return exercise }
            var result = exercise
            result.origin = .custom(sharesName: sharesName)
            return result
        }
        return presets + personal
    }

    public static func matchingKey(_ text: String) -> String {
        let key = searchKey(text)
        let compact = key.unicodeScalars.filter {
            !$0.properties.isWhitespace && $0.properties.generalCategory != .dashPunctuation && $0 != "'" && $0 != "’"
        }
        return compact.isEmpty ? key : String(compact)
    }

    public static func searchKey(_ name: String) -> String {
        cleaned(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    private static func availableName(_ input: String, in exercises: [Exercise], excluding id: String? = nil) throws -> String {
        let name = cleaned(input)
        guard validName(name) else { throw ExerciseLibraryError.invalidName }
        let key = matchingKey(name)
        guard !exercises.contains(where: { exercise in
            !exercise.isArchived && exercise.id != id && exercise.searchNames.contains { matchingKey($0) == key }
        }) else {
            throw ExerciseLibraryError.duplicateName(name)
        }
        return name
    }

    private static func cleaned(_ name: String) -> String { name.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    private static func validName(_ name: String) -> Bool {
        (1...80).contains(name.count) && name.unicodeScalars.allSatisfy { $0.properties.generalCategory != .control }
    }
    private static func keys(_ exercise: Exercise) -> Set<String> { [searchKey(exercise.name), searchKey(exercise.shortName)] }
}

public extension Exercise {
    func matchingMuscleTags(query: String) -> [MuscleRegion] {
        let key = ExerciseLibrary.matchingKey(query)
        guard !key.isEmpty else { return [] }
        return taggedMuscles.filter { $0.matchesCatalogSearch(key: key) }
    }

    func matchesCatalogSearch(key: String) -> Bool {
        if matchesExerciseName(key: key) { return true }
        if taggedMuscles.contains(where: { $0.matchesCatalogSearch(key: key) }) { return true }
        var terms = [group.rawValue, equipmentType.rawValue]
        if let required = customSetup.requiredEquipment {
            if required.contains(where: { $0.matchesSearch(key: key) }) { return true }
        } else if let id = catalogAliasID ?? presetID, let setup = GymExerciseCatalog.entriesByID[id]?.setup {
            terms.append(setup)
        }
        return terms.contains { ExerciseLibrary.matchingKey($0).contains(key) }
    }

    var searchNames: [String] {
        var names = [name]
        if shortName != name { names.append(shortName) }
        // Several long-established notebook names use “bench” for the bench press.
        if name.lowercased().split(separator: " ").last == "bench" { names.append(name + " press") }
        if let id = catalogAliasID, let entry = GymExerciseCatalog.entriesByID[id] { names.append(entry.name) }
        if let id = catalogAliasID ?? presetID { names.append(contentsOf: GymExerciseCatalog.aliases(for: id)) }
        return names
    }

    func matchesExerciseName(key: String) -> Bool {
        searchNames.contains { ExerciseLibrary.matchingKey($0).contains(key) }
    }
}

/// A file carrying either kind of custom anatomy data needs a reader that preserves both.
package struct CustomMuscleMetadata: Codable, Equatable {
    let tags: Int
    let neckExercises: Int

    package init?(_ exercises: [Exercise]) {
        tags = exercises.reduce(0) { $0 + $1.customMuscleTags.count }
        neckExercises = exercises.count { $0.muscleGroup == .neck }
        guard tags > 0 || neckExercises > 0 else { return nil }
    }
}

public enum ExerciseLibraryError: LocalizedError, Equatable {
    case invalidName, invalidLibrary, duplicateName(String), protectedExercise
    public var errorDescription: String? {
        switch self {
        case .invalidName: "Use an exercise name with 1–80 characters."
        case .protectedExercise: "This exercise belongs to the built-in library."
        case .invalidLibrary: "The exercise library could not be restored. The saved file has been left untouched."
        case .duplicateName(let name): "An exercise named “\(name)” already exists. Choose it from the list."
        }
    }
}

private extension MuscleRegion {
    static let searchKeys: [Self: [String]] = {
        let aliases: [Self: [String]] = [
            .spinalErectors: ["lower back", "low back"],
            .quadriceps: ["quads"], .abdominals: ["abs"], .chest: ["pecs"],
            .frontShoulders: ["front delts"], .sideShoulders: ["side delts"], .rearShoulders: ["rear delts"]
        ]
        return Dictionary(uniqueKeysWithValues: allCases.map { region in
            let names = [region.name, region.anatomicalName, region.group.rawValue] + (aliases[region] ?? [])
            return (region, names.map(ExerciseLibrary.matchingKey))
        })
    }()

    func matchesCatalogSearch(key: String) -> Bool {
        Self.searchKeys[self]?.contains(where: { $0.contains(key) }) == true
    }
}
