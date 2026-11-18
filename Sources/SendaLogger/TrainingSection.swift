public enum TrainingSection: String, CaseIterable, Sendable {
    case log = "Log", trends = "Trends", learn = "Learn", profile = "Profile"

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
