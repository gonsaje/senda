import Foundation

public struct ProfileDetails: Codable, Equatable, Sendable {
    public var name: String
    public var email: String
    public var goals: [StrengthGoal]

    public init(name: String = "", email: String = "", goals: [StrengthGoal] = []) {
        self.name = name
        self.email = email
        self.goals = goals
    }

    private enum CodingKeys: String, CodingKey { case name, email, goals }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        name = try box.decode(String.self, forKey: .name)
        email = try box.decode(String.self, forKey: .email)
        goals = box.contains(.goals) ? try box.decode([StrengthGoal].self, forKey: .goals) : []
    }

    public func validated() throws -> ProfileDetails {
        let name = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count <= 80, name.unicodeScalars.allSatisfy({ $0.properties.generalCategory != .control }) else { throw ProfileDetailsError.invalidName }
        if !email.isEmpty {
            let parts = email.split(separator: "@", omittingEmptySubsequences: false)
            guard email.count <= 254, parts.count == 2, parts.allSatisfy({ !$0.isEmpty }),
                  email.unicodeScalars.allSatisfy({ !$0.properties.isWhitespace && $0.properties.generalCategory != .control }) else { throw ProfileDetailsError.invalidEmail }
        }
        guard Set(goals.map(\.id)).count == goals.count else { throw StrengthGoalError.duplicateGoal }
        for goal in goals { try goal.validate() }
        return ProfileDetails(name: name, email: email, goals: goals)
    }
}
public enum ProfileDetailsError: LocalizedError {
    case invalidName, invalidEmail
    public var errorDescription: String? {
        switch self { case .invalidName: "Use a name of up to 80 characters."; case .invalidEmail: "Enter an email address or leave it blank." }
    }
}
