import Foundation
import Testing
@testable import SendaNotebook

struct TrainerApplicationEmailTests {
    @Test func mailDraftAndManualCopyContainTheSameApplication() throws {
        let draft = TrainerApplicationEmail(name: "Zoë + Lee & Co?bcc=elsewhere@example.com")
        let url = try #require(draft.mailURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "mailto")
        #expect(components.path == "hello@dontsweat.tech")
        #expect(components.queryItems == [
            URLQueryItem(name: "subject", value: draft.subject),
            URLQueryItem(name: "body", value: draft.body.replacingOccurrences(of: "\n", with: "\r\n"))
        ])
        #expect(url.absoluteString.contains("%2B"))
        #expect(draft.copyText.contains(draft.name))
        #expect(draft.copyText.contains(draft.body))
        #expect(TrainerApplicationEmail(name: "").mailURL != nil)
    }
}
