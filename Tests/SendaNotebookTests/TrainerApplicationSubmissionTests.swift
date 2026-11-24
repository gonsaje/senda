import Foundation
import Testing
@testable import SendaNotebook

struct TrainerApplicationSubmissionTests {
    private var form: TrainerApplicationSubmission {
        TrainerApplicationSubmission(name: "  Zoë & Lee  ", email: "trainer+coach@example.test", credentials: [
            .init(certification: "CPT", issuer: "Sample issuer", verification: "ABC-123"),
            .init(certification: " CSCS ", issuer: "Second issuer", verification: "https://example.test/456")
        ])
    }

    @Test func postsEveryCredentialWithTheAuthenticatedSession() throws {
        let clean = form.trimmed
        let url = URL(string: "https://senda.example.test/v1/trainer-applications")!
        let request = try clean.request(to: url, token: "test-session")
        #expect(clean.validationError == nil)
        #expect(clean.name == "Zoë & Lee")
        #expect(request.url == url && request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-session")
        #expect(throws: SendaAccountClient.Failure.self) { try clean.request(to: url, token: "") }
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(Set(json.keys) == ["id", "name", "email", "credentials"])
        let credentials = try #require(json["credentials"] as? [[String: String]])
        #expect(credentials.map { $0["certification"] } == ["CPT", "CSCS"])
        #expect(credentials.map { $0["verification"] } == ["ABC-123", "https://example.test/456"])
    }

    @Test func validatesEveryCredential() {
        var invalid = form
        invalid.credentials[1].issuer = "  "
        #expect(invalid.trimmed.validationError?.contains("certification 2") == true)
        invalid.credentials.removeLast()
        #expect(invalid.trimmed.validationError == nil)
        invalid.email = "no-domain"
        #expect(invalid.trimmed.validationError != nil)
        invalid = form
        invalid.credentials.removeAll()
        #expect(invalid.trimmed.validationError != nil)
    }

    @Test func onlyAMatchingServerReceiptConfirmsSubmission() throws {
        let attempt = form.trimmed
        let receipt = try JSONEncoder().encode(["id": attempt.id])
        try attempt.confirm(receipt, status: 201)
        try attempt.confirm(receipt, status: 200)
        #expect(throws: SendaAccountClient.Failure.self) { try attempt.confirm(receipt, status: 401) }
        #expect(throws: TrainerApplicationSubmission.SubmissionError.self) { try attempt.confirm(receipt, status: 500) }
        #expect(throws: TrainerApplicationSubmission.SubmissionError.self) { try form.confirm(receipt, status: 200) }
        #expect(throws: TrainerApplicationSubmission.SubmissionError.self) { try attempt.confirm(Data(), status: 200) }
    }
}
