import Foundation

/// The auth service owns the session cookie. The Senda API receives only its short-lived bearer token.
struct SendaAccountClient: Sendable {
    struct Connection: Sendable {
        let id: UUID
        let email: String
        let token: String
    }

    enum Failure: LocalizedError {
        case unavailable, signedOut, verificationRequired, rejected, offline, tooManyAttempts

        var errorDescription: String? {
            switch self {
            case .unavailable: "Account access is temporarily unavailable."
            case .signedOut: "Sign in to your Senda account to continue."
            case .verificationRequired: "Check your email to verify your account."
            case .rejected: "Check the details you entered and try again."
            case .offline: "Couldn’t connect to Senda. Please try again."
            case .tooManyAttempts: "Too many attempts. Wait a few minutes and try again."
            }
        }
    }

    let authURL: URL?
    let apiURL: URL?
    let session: URLSession

    static var configured: Self {
        let auth = configuredURL("SendaAuthURL", setting: "NEON_AUTH_BASE_URL")
        var api = configuredURL("SendaAPIURL", setting: "SENDA_API_URL")
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["SENDA_API_URL"] == nil,
           (Bundle.main.object(forInfoDictionaryKey: "SendaAPIURL") as? String ?? "").isEmpty {
            api = URL(string: "http://127.0.0.1:18764")
        }
        #endif
        return Self(authURL: auth, apiURL: api, session: .shared)
    }

    private static func configuredURL(_ key: String, setting: String) -> URL? {
        var raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        #if DEBUG && targetEnvironment(simulator)
        raw = ProcessInfo.processInfo.environment[setting] ?? raw
        #endif
        guard let url = URL(string: raw), url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return nil }
        #if DEBUG && targetEnvironment(simulator)
        if url.scheme == "http", url.host == "127.0.0.1" { return url }
        #endif
        return url.scheme == "https" ? url : nil
    }

    private func auth(_ path: String, fields: [String: String]) async throws -> (Data, HTTPURLResponse) {
        try await auth(path, body: JSONEncoder().encode(fields))
    }

    func auth(_ path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let authURL, let apiURL else { throw Failure.unavailable }
        let endpoint = authURL.appending(path: path)
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
            let encoded = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            components?.percentEncodedQuery = encoded
        }
        guard let url = components?.url else { throw Failure.unavailable }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue(apiURL.origin, forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        let (data, response) = try await session.data(for: request, delegate: DirectSubmission())
        guard let http = response as? HTTPURLResponse else { throw Failure.offline }
        if http.statusCode == 429 { throw Failure.tooManyAttempts }
        if !(200..<300).contains(http.statusCode) {
            struct AuthError: Decodable { let code: String? }
            if (try? JSONDecoder().decode(AuthError.self, from: data))?.code == "EMAIL_NOT_VERIFIED" {
                throw Failure.verificationRequired
            }
            if (path == "get-session" || path == "token"), http.statusCode == 401 { throw Failure.signedOut }
            throw http.statusCode >= 500 ? Failure.offline : Failure.rejected
        }
        return (data, http)
    }

    func connection(verifier: String? = nil) async throws -> Connection {
        struct User: Decodable { let email: String }
        struct ProviderSession: Decodable { let user: User }
        struct Account: Decodable { let id: UUID }

        guard let apiURL else { throw Failure.unavailable }
        var query = [URLQueryItem(name: "disableCookieCache", value: "true")]
        if let verifier { query.append(URLQueryItem(name: SendaSignInAttempt.verifierName, value: verifier)) }
        let (body, authResponse) = try await auth("get-session", query: query)
        guard let identity = try JSONDecoder().decode(ProviderSession?.self, from: body) else { throw Failure.signedOut }
        let token: String
        if let jwt = authResponse.value(forHTTPHeaderField: "set-auth-jwt"), !jwt.isEmpty {
            token = jwt
        } else {
            struct TokenResponse: Decodable { let token: String }
            let (data, _) = try await auth("token")
            token = try JSONDecoder().decode(TokenResponse.self, from: data).token
            guard !token.isEmpty else { throw Failure.signedOut }
        }
        var request = URLRequest(url: apiURL.appending(path: "v1/me"), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpShouldHandleCookies = false
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request, delegate: DirectSubmission())
        let status = (response as? HTTPURLResponse)?.statusCode
        if status == 401 || status == 403 { throw Failure.signedOut }
        guard status == 200 else { throw Failure.offline }
        let account = try JSONDecoder().decode(Account.self, from: data)
        return Connection(id: account.id, email: identity.user.email, token: token)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await auth("sign-in/email", fields: ["email": email, "password": password])
    }

    func createAccount(name: String, email: String, password: String) async throws {
        _ = try await auth("sign-up/email", fields: ["name": name, "email": email, "password": password])
    }

    func verify(email: String, code: String) async throws {
        _ = try await auth("email-otp/verify-email", fields: ["email": email, "otp": code])
    }

    func resendVerification(email: String) async throws {
        _ = try await auth("send-verification-email", fields: ["email": email])
    }

    func signOut() async throws { _ = try await auth("sign-out", fields: [:]) }
}

private extension URL {
    var origin: String? {
        guard var parts = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        parts.path = ""
        return parts.string
    }
}
