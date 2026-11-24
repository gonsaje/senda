import Foundation

enum SendaSignInProvider: String, CaseIterable, Identifiable {
    case apple, google

    var id: Self { self }

    var name: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        }
    }

    static func providers(in setting: String) -> [Self] {
        let names = Set(setting.lowercased().split { $0 == "," || $0.isWhitespace }.map(String.init))
        return allCases.filter { names.contains($0.rawValue) }
    }

    static var configured: [Self] {
        var setting = Bundle.main.object(forInfoDictionaryKey: "SendaOAuthProviders") as? String ?? ""
        #if DEBUG && targetEnvironment(simulator)
        setting = ProcessInfo.processInfo.environment["SENDA_OAUTH_PROVIDERS"] ?? setting
        #endif
        return providers(in: setting)
    }
}

struct SendaSignInAttempt {
    static let scheme = "com.senda.journal.auth"
    static let verifierName = "neon_auth_session_verifier"
    let id = UUID()

    func callback(at api: URL) -> URL {
        api.appending(path: "v1/auth/mobile/callback")
            .appending(queryItems: [URLQueryItem(name: "attempt", value: id.uuidString)])
    }

    func verifier(from callback: URL) throws -> String {
        guard let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              parts.scheme == Self.scheme, parts.host == "auth", parts.path == "/callback",
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil else {
            throw SendaSocialError.incomplete
        }
        let items = parts.queryItems ?? []
        let attempts = items.filter { $0.name == "attempt" }
        let verifiers = items.filter { $0.name == Self.verifierName }
        guard attempts.count == 1, let attempt = attempts.first?.value, UUID(uuidString: attempt) == id,
              !items.contains(where: { $0.name == "error" }), verifiers.count == 1,
              let verifier = verifiers.first?.value, !verifier.isEmpty else { throw SendaSocialError.incomplete }
        return verifier
    }
}

enum SendaSocialError: LocalizedError {
    case incomplete, providerUnavailable(String)
    var errorDescription: String? {
        switch self {
        case .incomplete: "Sign-in didn’t finish. Try again."
        case .providerUnavailable(let name): "\(name) sign-in is unavailable. Choose another way to continue."
        }
    }
}

extension SendaAccountClient {
    func startSignIn(with provider: SendaSignInProvider, attempt: SendaSignInAttempt) async throws -> URL {
        struct SocialRequest: Encodable {
            let provider: String
            let callbackURL: URL
            let errorCallbackURL: URL
            let disableRedirect = true
        }
        struct SocialResponse: Decodable { let url: URL }
        guard let apiURL else { throw Failure.unavailable }
        let callback = attempt.callback(at: apiURL)
        let payload = SocialRequest(provider: provider.rawValue, callbackURL: callback, errorCallbackURL: callback)
        do {
            let (data, _) = try await auth("sign-in/social", body: JSONEncoder().encode(payload))
            let url = try JSONDecoder().decode(SocialResponse.self, from: data).url
            guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else {
                throw SendaSocialError.incomplete
            }
            return url
        } catch Failure.rejected {
            throw SendaSocialError.providerUnavailable(provider.name)
        }
    }

    func finishSignIn(at callback: URL, attempt: SendaSignInAttempt) async throws -> Connection {
        let verifier = try attempt.verifier(from: callback)
        // The same URLSession that started sign-in holds Neon's challenge cookie.
        return try await connection(verifier: verifier)
    }
}
