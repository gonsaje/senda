public enum TrainingSection: String, CaseIterable, Sendable {
    case log = "Log", trends = "Trends", learn = "Learn", profile = "Profile"

    /// Keep the original raw section identifier for existing callers.
    public var title: String {
        switch self {
        case .log: "Train"
        case .learn: "Workouts"
        default: rawValue
        }
    }

    public var symbol: String {
        switch self {
        case .log: "dumbbell"
        case .trends: "chart.bar"
        case .learn: "square.2.layers.3d"
        case .profile: "person"
        }
    }
}

public enum LearnExerciseScope: Sendable {
    case library, personal, needsDetails
}

public enum TrainingLibraryArea: String, CaseIterable, Sendable {
    case workouts = "Workouts", exercises = "Exercises", learn = "Learn"
}

public enum TrainingGuideTopic: String, CaseIterable, Sendable {
    case form = "Form guides", muscles = "Muscles worked"
}
