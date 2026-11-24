import Foundation

struct SendaAccountRegistration {
    enum Field: Hashable, CaseIterable {
        case firstName, lastName, email, password, confirmation
    }

    enum Strength: Int {
        case weak = 1, fair, strong

        var label: String {
            switch self {
            case .weak: "Weak"
            case .fair: "Fair"
            case .strong: "Strong"
            }
        }
    }

    var firstName = ""
    var lastName = ""
    var email = ""
    var password = ""
    var confirmation = ""

    var address: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var displayName: String {
        [firstName, lastName].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " ")
    }

    var firstInvalidField: Field? { Field.allCases.first { error(for: $0) != nil } }

    func error(for field: Field) -> String? {
        switch field {
        case .firstName:
            return firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter your first name." : nil
        case .lastName:
            return lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter your last name." : nil
        case .email:
            return Self.validEmail(address) ? nil : "Enter an email like name@example.com."
        case .password:
            return password.count >= 8 ? nil : "Use at least 8 characters."
        case .confirmation:
            if confirmation.isEmpty { return "Enter your password again." }
            return password.utf8.elementsEqual(confirmation.utf8) ? nil : "Passwords don’t match."
        }
    }

    private static func validEmail(_ address: String) -> Bool {
        guard let at = address.firstIndex(of: "@") else { return false }
        let local = address[..<at]
        let domain = address[address.index(after: at)...]
        guard !local.isEmpty, local.utf8.count <= 64, address.utf8.count <= 254,
              !local.hasPrefix("."), !local.hasSuffix("."), !local.contains(".."),
              local.range(of: #"[^\p{L}\p{M}\p{N}.!#$%&'*+/=?^_`{|}~-]"#, options: .regularExpression) == nil
        else { return false }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        return labels.count > 1 && labels.allSatisfy { label in
            !label.isEmpty && label.utf8.count <= 63 && !label.hasPrefix("-") && !label.hasSuffix("-")
                && label.range(of: #"[^\p{L}\p{M}\p{N}-]"#, options: .regularExpression) == nil
        }
    }

    // A local estimate for the meter. Meeting the service's length requirement is independent of the rating.
    var strength: Strength {
        let sample = String(password.prefix(128)).lowercased()
        guard sample.count >= 8, Set(sample).count >= 5,
              !["password", "p@ssw0rd", "qwerty", "123456", "abcdefgh", "letmein"].contains(where: sample.contains),
              sample.range(of: #"^(.{1,8})\1+$"#, options: .regularExpression) == nil else { return .weak }
        let words = Set(sample.split(whereSeparator: { !$0.isLetter }))
        let mixed = password.contains(where: \.isNumber) || password.contains { !$0.isLetter && !$0.isWhitespace }
        if sample.count >= 16 && (words.count >= 3 || (mixed && Set(sample).count >= 8)) { return .strong }
        return sample.count >= 12 || mixed ? .fair : .weak
    }
}
