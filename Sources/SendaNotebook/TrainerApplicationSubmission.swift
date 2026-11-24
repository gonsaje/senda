import Foundation

struct TrainerApplicationSubmission: Encodable, Equatable, Sendable {
    struct Credential: Encodable, Equatable, Identifiable, Sendable {
        let id = UUID()
        var certification = ""
        var issuer = ""
        var verification = ""
        private enum CodingKeys: String, CodingKey { case certification, issuer, verification }
    }

    static let maximumCredentials = 25
    var id = UUID()
    var name = ""
    var email = ""
    var credentials = [Credential()]

    var trimmed: Self {
        var form = self
        form.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        form.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        for index in form.credentials.indices {
            for key in [\Credential.certification, \.issuer, \.verification] {
                form.credentials[index][keyPath: key] = credentials[index][keyPath: key].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return form
    }

    var validationError: String? {
        guard (1...Self.maximumCredentials).contains(credentials.count) else {
            return "Include between 1 and \(Self.maximumCredentials) certifications."
        }
        var fields = [(name, "name on your credential", 160), (email, "contact email", 254)]
        for (index, item) in credentials.enumerated() {
            let suffix = credentials.count > 1 ? " for certification \(index + 1)" : ""
            fields += [(item.certification, "certification name" + suffix, 160),
                       (item.issuer, "issuing organization" + suffix, 160),
                       (item.verification, "verification link or credential number" + suffix, 1024)]
        }
        for (value, label, limit) in fields {
            if value.isEmpty { return "Enter your \(label)." }
            if value.utf16.count > limit || value.rangeOfCharacter(from: .controlCharacters) != nil {
                return "Keep your \(label) on one line and within \(limit) characters."
            }
        }
        let emailPattern = #"^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$"#
        return email.range(of: emailPattern, options: .regularExpression) == nil ? "Enter a valid contact email." : nil
    }

    func request(to endpoint: URL, token: String) throws -> URLRequest {
        guard !token.isEmpty else { throw SendaAccountClient.Failure.signedOut }
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(self)
        return request
    }

    func submit(using client: SendaAccountClient, token: String) async throws {
        guard let endpoint = client.apiURL?.appending(path: "v1/trainer-applications") else { throw SubmissionError.unavailable }
        let (data, response) = try await client.session.data(for: request(to: endpoint, token: token), delegate: DirectSubmission())
        try confirm(data, status: (response as? HTTPURLResponse)?.statusCode)
    }

    func confirm(_ data: Data, status: Int?) throws {
        struct Receipt: Decodable { let id: UUID }
        if status == 401 || status == 403 { throw SendaAccountClient.Failure.signedOut }
        if status == 400 { throw SubmissionError.invalid }
        guard status == 200 || status == 201, let receipt = try? JSONDecoder().decode(Receipt.self, from: data),
              receipt.id == id else { throw SubmissionError.unconfirmed }
    }

    enum SubmissionError: LocalizedError {
        case unavailable, invalid, unconfirmed

        var errorDescription: String? {
            switch self {
            case .unavailable: "Trainer applications are temporarily unavailable. Please try again later."
            case .invalid: "Check your contact and certification details, then submit again."
            case .unconfirmed: "We couldn’t confirm your submission. Your entries are still here. Try again."
            }
        }
    }
}

final class DirectSubmission: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? { nil }
}
