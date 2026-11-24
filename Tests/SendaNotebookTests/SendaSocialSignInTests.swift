import Foundation
import Testing
@testable import SendaNotebook

struct SendaSocialSignInTests {
    @Test func providerListIncludesOnlyRecognizedEnabledProvidersOnce() {
        #expect(SendaSignInProvider.providers(in: "Microsoft, apple GOOGLE,google,github") == [.apple, .google])
        #expect(SendaSignInProvider.providers(in: "").isEmpty)
        #expect(SendaSignInProvider.providers(in: "discord microsoft vercel").isEmpty)
    }

    @Test func acceptsOnlyTheCurrentBrowserAttempt() throws {
        let attempt = SendaSignInAttempt()
        let root = URL(string: "com.senda.journal.auth://auth/callback")!
        let parameters = [URLQueryItem(name: "attempt", value: attempt.id.uuidString.lowercased()),
                          URLQueryItem(name: SendaSignInAttempt.verifierName, value: "verification+value/=")]
        let callback = root.appending(queryItems: parameters)
        #expect(try attempt.verifier(from: callback) == "verification+value/=")
        #expect(throws: SendaSocialError.self) { try SendaSignInAttempt().verifier(from: callback) }
        #expect(throws: SendaSocialError.self) { try attempt.verifier(from: root.appending(queryItems: [parameters[0]])) }
        #expect(throws: SendaSocialError.self) { try attempt.verifier(from: callback.appending(queryItems: [parameters[1]])) }
        #expect(throws: SendaSocialError.self) {
            try attempt.verifier(from: callback.appending(queryItems: [URLQueryItem(name: "error", value: "denied")]))
        }
        #expect(throws: SendaSocialError.self) {
            try attempt.verifier(from: URL(string: "com.senda.journal.auth://other/callback")!.appending(queryItems: parameters))
        }
        let target = attempt.callback(at: URL(string: "https://senda.example.test")!)
        #expect(target.path == "/v1/auth/mobile/callback")
        #expect(target.host == "senda.example.test")
    }
}
