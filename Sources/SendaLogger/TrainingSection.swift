public enum TrainingSection: String, CaseIterable, Sendable {
    case log = "Log", trends = "Trends", learn = "Learn", profile = "Profile"
    public var symbol: String {
        switch self { case .log: "book.closed"; case .trends: "chart.bar"; case .learn: "book"; case .profile: "person.crop.circle" }
    }
}
