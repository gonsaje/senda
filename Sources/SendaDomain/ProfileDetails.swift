import Foundation

public struct ProfileDetails: Codable, Equatable, Sendable {
    public var name: String
    public var email: String
    public init(name: String = "", email: String = "") { self.name = name; self.email = email }
    public func validated() throws -> ProfileDetails {
        let name = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count <= 80, name.unicodeScalars.allSatisfy({ $0.properties.generalCategory != .control }) else { throw ProfileDetailsError.invalidName }
        if !email.isEmpty {
            let parts = email.split(separator: "@", omittingEmptySubsequences: false)
            guard email.count <= 254, parts.count == 2, parts.allSatisfy({ !$0.isEmpty }),
                  email.unicodeScalars.allSatisfy({ !$0.properties.isWhitespace && $0.properties.generalCategory != .control }) else { throw ProfileDetailsError.invalidEmail }
        }
        return ProfileDetails(name: name, email: email)
    }
}
public enum ProfileDetailsError: LocalizedError {
    case invalidName, invalidEmail
    public var errorDescription: String? {
        switch self { case .invalidName: "Use a name of up to 80 characters."; case .invalidEmail: "Enter an email address or leave it blank." }
    }
}
