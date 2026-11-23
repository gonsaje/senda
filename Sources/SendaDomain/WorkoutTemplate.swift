import Foundation

public struct TrainerWorkoutDetails: Codable, Equatable, Sendable {
    public var minutes: Int?
    public var equipment = ""
    public var notes = ""

    public init(minutes: Int? = nil, equipment: String = "", notes: String = "") {
        self.minutes = minutes
        self.equipment = equipment
        self.notes = notes
    }

    public func validate() throws {
        guard minutes.map({ (1...1440).contains($0) }) ?? true,
              TrainingProgram.validText(equipment, max: 200),
              TrainingProgram.validText(notes, max: 2000) else { throw TrainerPageError.workoutDetails }
    }
}

public struct WorkoutTemplate: Codable, Identifiable, Equatable, Sendable {
    public private(set) var id: String
    public let name: String
    public let exerciseIDs: [String]
    public var exercisePlans: [String: ExercisePlan]
    public var trainerDetails: TrainerWorkoutDetails?
    public var trainerOriginID: String?
    public let trainerCredit: String?
    public let supersets: [SupersetPlan]?

    public init(id: String = UUID().uuidString.lowercased(), name: String, exerciseIDs: [String],
                exercisePlans: [String: ExercisePlan] = [:], supersets: [SupersetPlan]? = nil, trainerCredit: String? = nil,
                trainerDetails: TrainerWorkoutDetails? = nil, trainerOriginID: String? = nil) {
        self.id = id
        self.name = Self.cleanName(name)
        self.trainerCredit = trainerCredit
        self.trainerDetails = trainerDetails
        self.trainerOriginID = trainerOriginID
        self.exerciseIDs = exerciseIDs
        self.exercisePlans = exercisePlans
        self.supersets = supersets?.isEmpty == true ? nil : supersets
    }

    mutating func startNewTrainerVersion() {
        trainerOriginID = trainerOriginID ?? id
        id = UUID().uuidString.lowercased()
    }

    public func validated(against knownExerciseIDs: Set<String>) throws -> Self {
        guard !name.isEmpty, name.count <= 80, name == Self.cleanName(name),
              name.unicodeScalars.allSatisfy({ $0.properties.generalCategory != .control }) else {
            throw WorkoutTemplateError.invalidName
        }
        let selection = Set(exerciseIDs)
        guard !selection.isEmpty else { throw WorkoutTemplateError.noExercises }
        guard selection.count == exerciseIDs.count else { throw WorkoutTemplateError.duplicateExercise }
        guard selection.isSubset(of: knownExerciseIDs) else { throw WorkoutTemplateError.unavailableExercise }
        guard Set(exercisePlans.keys).isSubset(of: selection),
              exercisePlans.values.allSatisfy({ (try? $0.validated()) != nil }) else {
            throw WorkoutTemplateError.invalidPlan
        }
        try trainerDetails?.validate()
        try SupersetPlan.validate(supersets ?? [], order: exerciseIDs)
        return self
    }

    private static func cleanName(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public static let catalog: [WorkoutTemplate] = [
        starter("full-body", "Full body", [
            ("squat", 3, 5...8), ("bench", 3, 6...10), ("cable-row", 3, 8...12), ("romanian-deadlift", 2, 8...12)
        ]),
        starter("upper-body", "Upper body", [
            ("bench", 3, 6...10), ("cable-row", 3, 8...12), ("overhead-press", 2, 6...10), ("lat-pulldown", 2, 8...12)
        ]),
        starter("lower-body", "Lower body", [
            ("squat", 3, 5...8), ("romanian-deadlift", 3, 8...10), ("lunge", 2, 8...12), ("calf-raise", 2, 10...15)
        ]),
        starter("push", "Push", [
            ("bench", 3, 6...10), ("overhead-press", 3, 6...10), ("lateral-raise", 2, 12...15), ("triceps-extension", 2, 10...15)
        ]),
        starter("pull", "Pull", [
            ("row", 3, 6...10), ("lat-pulldown", 3, 8...12), ("biceps-curl", 2, 10...15)
        ]),
        starter("legs", "Legs", [
            ("squat", 3, 5...8), ("hip-thrust", 3, 8...12), ("leg-curl", 2, 10...15), ("calf-raise", 2, 10...15)
        ]),
        starter("dumbbell-basics", "Dumbbell full body", [
            ("goblet-squat", 3, 8...12), ("dumbbell-bench", 3, 8...12), ("one-arm-dumbbell-row", 3, 8...12),
            ("dumbbell-romanian-deadlift", 2, 8...12)
        ]),
        starter("no-equipment", "No-equipment full body", [
            ("bodyweight-squat", 3, 10...15), ("push-up", 3, 6...12), ("glute-bridge", 3, 10...15),
            ("crunch", 2, 10...15)
        ]),
        starter("machine-legs", "Machine legs", [
            ("leg-press", 3, 8...12), ("leg-curl", 3, 10...15), ("leg-extension", 2, 10...15), ("calf-raise", 2, 10...15)
        ]),
        starter("barbell-full-body", "Barbell full body", [
            ("deadlift", 2, 4...6), ("overhead-press", 3, 6...10), ("row", 3, 6...10), ("squat", 2, 6...10)
        ]),
        starter("bodyweight-upper-body", "Bodyweight upper body", [
            ("push-up", 3, 6...12), ("pull-up", 3, 3...8)
        ])
    ]

    private static func starter(_ id: String, _ name: String,
                                _ exercises: [(id: String, sets: Int, reps: ClosedRange<Int>)]) -> Self {
        WorkoutTemplate(id: id, name: name, exerciseIDs: exercises.map { $0.id },
            exercisePlans: Dictionary(uniqueKeysWithValues: exercises.map { exercise in
                (exercise.id, ExercisePlan(workingSets: exercise.sets, minimumReps: exercise.reps.lowerBound,
                                           maximumReps: exercise.reps.upperBound))
            }))
    }
}

public enum WorkoutTemplateError: LocalizedError, Equatable {
    case invalidName, duplicateName, invalidID, noExercises, duplicateExercise, unavailableExercise, invalidPlan

    public var errorDescription: String? {
        switch self {
        case .invalidName: "Enter a workout name of up to 80 characters."
        case .duplicateName: "You already have a workout with this name."
        case .invalidID: "This saved workout couldn’t be identified."
        case .noExercises: "Choose at least one exercise."
        case .duplicateExercise: "Choose each exercise once."
        case .unavailableExercise: "One of these exercises is no longer available."
        case .invalidPlan: "Check the set and rep targets for this workout."
        }
    }
}
