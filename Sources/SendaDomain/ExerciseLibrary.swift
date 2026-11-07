import Foundation

public enum ExerciseLibrary {
    public static let initialWorkoutIDs = ["bench", "deadlift", "squat"]

    public static func custom(named name: String, existing: [Exercise] = Exercise.catalog) throws -> Exercise {
        let name = cleaned(name)
        guard validName(name) else { throw ExerciseLibraryError.invalidName }
        guard !existing.contains(where: { keys($0).contains(searchKey(name)) }) else {
            throw ExerciseLibraryError.duplicateName(name)
        }
        return Exercise(id: "custom-\(UUID().uuidString.lowercased())", name: name, shortName: name, startingWeight: 0)
    }

    public static func validated(custom: [Exercise]) throws -> [Exercise] {
        let exercises = Exercise.catalog + custom
        var ids = Set<String>()
        var names = Set<String>()
        for exercise in exercises {
            let namesForExercise = keys(exercise)
            guard !exercise.id.isEmpty, exercise.id.count <= 80,
                  exercise.id.unicodeScalars.allSatisfy({ !$0.properties.isWhitespace && $0.properties.generalCategory != .control }),
                  ids.insert(exercise.id).inserted,
                  validName(exercise.name), exercise.name == cleaned(exercise.name),
                  validName(exercise.shortName), exercise.shortName == cleaned(exercise.shortName),
                  NumericField.weight.range.contains(exercise.startingWeight),
                  names.isDisjoint(with: namesForExercise) else { throw ExerciseLibraryError.invalidLibrary }
            names.formUnion(namesForExercise)
        }
        return exercises
    }

    public static func searchKey(_ name: String) -> String {
        cleaned(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    private static func cleaned(_ name: String) -> String { name.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    private static func validName(_ name: String) -> Bool {
        (1...80).contains(name.count) && name.unicodeScalars.allSatisfy { $0.properties.generalCategory != .control }
    }
    private static func keys(_ exercise: Exercise) -> Set<String> { [searchKey(exercise.name), searchKey(exercise.shortName)] }
}

public enum ExerciseLibraryError: LocalizedError, Equatable {
    case invalidName, invalidLibrary, duplicateName(String)
    public var errorDescription: String? {
        switch self {
        case .invalidName: "Use an exercise name with 1–80 characters."
        case .invalidLibrary: "The exercise library could not be restored. The saved file has been left untouched."
        case .duplicateName(let name): "An exercise named “\(name)” already exists. Choose it from the list."
        }
    }
}
