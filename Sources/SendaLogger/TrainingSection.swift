public enum TrainingSection: String, CaseIterable, Sendable {
    case log = "Log", learn = "Learn", profile = "Profile"
    public var symbol: String {
        switch self { case .log: "book.closed"; case .learn: "book"; case .profile: "person.crop.circle" }
    }
}
