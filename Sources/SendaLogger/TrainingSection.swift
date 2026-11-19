public enum TrainingSection: String, CaseIterable, Sendable {
    case log = "Log", trends = "Trends", learn = "Learn", profile = "Profile"

    /// Keep the original raw section identifier for existing callers.
    public var title: String { self == .learn ? "Library" : rawValue }

    public var symbol: String {
        switch self {
        case .log: "text.book.closed"
        case .trends: "chart.xyaxis.line"
        case .learn: "books.vertical"
        case .profile: "person.text.rectangle"
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
