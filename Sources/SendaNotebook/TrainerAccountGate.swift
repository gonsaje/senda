import SwiftUI
import AuthenticationServices
import SendaLogger

@MainActor @Observable
final class SendaAccountSession {
    let client: SendaAccountClient
    private(set) var account: SendaAccountClient.Connection?
    private(set) var checking = true
    private(set) var checkError: String?
    var authenticating = false
    private var revision = 0

    init(client: SendaAccountClient = .configured) { self.client = client }

    var profileDetail: String? {
        if let account { return account.email }
        if checking { return nil }
        return checkError ?? "Sign in or create an account"
    }

    func setAccount(_ connection: SendaAccountClient.Connection?) {
        revision += 1
        account = connection
        checkError = nil
        checking = false
    }

    func refresh() async {
        revision += 1
        let request = revision
        guard client.authURL != nil, client.apiURL != nil else { setAccount(nil); return }
        do {
            let connected = try await client.connection()
            guard !Task.isCancelled, revision == request else { return }
            setAccount(connected)
        } catch {
            guard !Task.isCancelled, revision == request else { return }
            setAccount(nil)
            if (error as? SendaAccountClient.Failure) != .signedOut {
                checkError = "Couldn’t check your Senda account."
            }
        }
    }
}

struct SendaAccountSheet: View {
    enum Purpose {
        case profile, trainer(TrainingNotebookModel)

        var title: LocalizedStringKey {
            switch self {
            case .profile: "Senda account"
            case .trainer: "Apply as a trainer"
            }
        }
    }

    @Bindable var session: SendaAccountSession
    let purpose: Purpose
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var signOutError: String?

    var body: some View {
        Group {
            if case .trainer(let model) = purpose, let account = session.account {
                ConnectedTrainerForm(model: model, account: account, client: session.client) { session.setAccount(nil) }
                    .id(account.id)
            } else if let account = session.account {
                AccountPage(title: purpose.title, close: { dismiss() }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Signed in as").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        Text(verbatim: account.email).font(.headline).textSelection(.enabled)
                    }
                    Divider()
                    Button { Task { await signOut() } } label: {
                        Text("Sign out of Senda").foregroundStyle(NotebookStyle.clay)
                            .frame(minHeight: 48).contentShape(Rectangle())
                    }
                    if session.authenticating { ProgressView() }
                    if let signOutError { Text(signOutError).font(.callout) }
                }
                .disabled(session.authenticating)
            } else if session.checking {
                AccountPage(title: purpose.title, close: { dismiss() }) {
                    ProgressView("Checking account…")
                }
            } else {
                SendaAccountPrompt(client: session.client, purpose: purpose, checkError: session.checkError,
                                   retry: session.refresh, busy: $session.authenticating, connected: session.setAccount)
            }
        }
        .tint(NotebookStyle.clay)
        .interactiveDismissDisabled(session.authenticating)
        .task(id: phase) {
            if phase == .active, !session.authenticating { await session.refresh() }
        }
    }

    private func signOut() async {
        guard !session.authenticating else { return }
        session.authenticating = true
        defer { session.authenticating = false }
        signOutError = nil
        do {
            try await session.client.signOut()
            session.setAccount(nil)
        } catch {
            signOutError = "Couldn’t sign out. Please try again."
        }
    }
}

private struct SendaAccountPrompt: View {
    enum Step { case choose, create, signIn, verify }
    let client: SendaAccountClient
    let purpose: SendaAccountSheet.Purpose
    let checkError: String?
    let retry: () async -> Void
    @Binding var busy: Bool
    let connected: (SendaAccountClient.Connection) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var browser

    @State private var step = Step.choose
    @State private var registration = SendaAccountRegistration()
    @State private var code = ""
    @State private var message: String?
    private let providers = SendaSignInProvider.configured
    private var configured: Bool { client.authURL != nil && client.apiURL != nil }
    private var address: String { registration.address }

    private enum Field { case email, password, code }
    @FocusState private var focus: Field?

    var body: some View {
        AccountPage(title: title, detail: detail, back: step == .choose ? nil : { move(to: .choose) },
                    close: { dismiss() }) {
            if step == .choose {
                options
            } else if step == .create {
                SendaCreateAccountForm(form: $registration, configured: configured) {
                    run { try await authenticate() }
                }
            } else {
                emailForm
            }
            if busy { ProgressView("Connecting…").font(.callout) }
            if let message {
                Text(message).font(.callout).foregroundStyle(NotebookStyle.clay)
            }
        }
        .disabled(busy)
        .onChange(of: message) { _, value in
            if let value { TrainingAccessibility.announce(value) }
        }
    }

    private var title: LocalizedStringKey {
        switch step {
        case .choose: purpose.title
        case .create: "Create an account"
        case .signIn: "Sign in with email"
        case .verify: "Check your email"
        }
    }

    private var detail: LocalizedStringKey? {
        if step == .verify { return "Enter the verification code sent to \(address)." }
        if step == .choose, case .trainer = purpose {
            return "Sign in or create an account to submit your trainer certifications."
        }
        return nil
    }

    @ViewBuilder private var options: some View {
        VStack(spacing: 10) {
            ForEach(providers) { provider in
                Button {
                    run { try await socialSignIn(with: provider) }
                } label: {
                    HStack(spacing: 10) {
                        if provider == .apple {
                            Image(systemName: "apple.logo").accessibilityHidden(true)
                        } else if let logo = ExerciseArtwork.image(named: "google-sign-in", maximumPixelSize: 80) {
                            Image(decorative: logo, scale: 1).resizable().scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                        Text("Continue with \(provider.name)")
                    }
                }
                .buttonStyle(AccountButtonStyle(treatment: provider == .apple ? .apple : .google))
                .accessibilityIdentifier("trainer-continue-" + provider.rawValue)
            }
            if !providers.isEmpty {
                HStack(spacing: 12) {
                    Rectangle().fill(NotebookStyle.rule).frame(height: 1)
                    Text("or").font(.footnote).foregroundStyle(NotebookStyle.quiet)
                    Rectangle().fill(NotebookStyle.rule).frame(height: 1)
                }.padding(.vertical, 2).accessibilityHidden(true)
            }
            Button { move(to: .create) } label: {
                Label("Create account with email", systemImage: "envelope")
            }
            .buttonStyle(AccountButtonStyle(treatment: .email))
            .accessibilityIdentifier("trainer-create-account")
            Button { move(to: .signIn) } label: {
                Text("Sign in with email").font(.subheadline.weight(.semibold))
                    .foregroundStyle(NotebookStyle.clay)
                    .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
            }
            .accessibilityIdentifier("trainer-sign-in")
        }
        if let checkError {
            Text(checkError).font(.callout)
            Button { run { await retry() } } label: {
                Text("Try again").foregroundStyle(NotebookStyle.clay)
                    .frame(minHeight: 48).contentShape(Rectangle())
            }
        }
    }

    @ViewBuilder private var emailForm: some View {
        if step == .verify {
            field("Verification code", id: .code) {
                TextField("Verification code", text: $code, prompt: Text("Enter code").foregroundStyle(NotebookStyle.quiet))
                    .textContentType(.oneTimeCode)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .submitLabel(.go).onSubmit(submit)
            }
        } else {
            field("Email address", id: .email) {
                TextField("Email address", text: $registration.email, prompt: Text(verbatim: "you@example.com").foregroundStyle(NotebookStyle.quiet))
                    .textContentType(.emailAddress).autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    #endif
                    .submitLabel(.next).onSubmit { focus = .password }
            }
            field("Password", id: .password) {
                SecureField("Password", text: $registration.password,
                            prompt: Text("Enter your password").foregroundStyle(NotebookStyle.quiet))
                    .textContentType(.password)
                    .submitLabel(.go).onSubmit(submit)
            }
        }
        if !configured { Text("Account access is temporarily unavailable.").font(.callout).foregroundStyle(NotebookStyle.quiet) }
        Button(actionTitle, action: submit)
            .buttonStyle(AccountButtonStyle(treatment: .primary))
            .disabled(!canSubmit)
        if step == .verify {
            Button {
                run { try await client.resendVerification(email: address); message = "Check your email." }
            } label: {
                Text("Resend verification email").foregroundStyle(NotebookStyle.clay)
                    .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
            }
        }
    }

    private func field(_ title: LocalizedStringKey, id: Field, @ViewBuilder input: () -> some View) -> some View {
        AccountTextInput(title: title, focused: focus == id, select: { focus = id }) {
            input().focused($focus, equals: id).accessibilityLabel(title)
        }
    }

    private var canSubmit: Bool {
        configured && !address.isEmpty && (step == .verify ? !code.isEmpty : !registration.password.isEmpty)
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        run { try await authenticate() }
    }

    private var actionTitle: LocalizedStringKey {
        switch step {
        case .create: "Create account"
        case .verify: "Verify email"
        default: "Sign in"
        }
    }

    private func move(to next: Step) {
        focus = nil
        registration.password = ""
        registration.confirmation = ""
        code = ""
        message = nil
        step = next
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        message = nil
        Task {
            defer { busy = false }
            do { try await action() }
            catch SendaAccountClient.Failure.verificationRequired { move(to: .verify) }
            catch let error as SendaSocialError { message = error.errorDescription }
            catch {
                message = (error as? SendaAccountClient.Failure)?.errorDescription ?? "Couldn’t connect to Senda. Please try again."
            }
        }
    }

    private func socialSignIn(with provider: SendaSignInProvider) async throws {
        let attempt = SendaSignInAttempt()
        let url = try await client.startSignIn(with: provider, attempt: attempt)
        do {
            let callback = try await browser.authenticate(using: url, callbackURLScheme: SendaSignInAttempt.scheme,
                                                          preferredBrowserSession: .shared)
            connected(try await client.finishSignIn(at: callback, attempt: attempt))
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        }
    }

    private func authenticate() async throws {
        switch step {
        case .create: try await client.createAccount(name: registration.displayName, email: address, password: registration.password)
        case .signIn: try await client.signIn(email: address, password: registration.password)
        case .verify: try await client.verify(email: address, code: code)
        case .choose: return
        }
        do {
            let session = try await client.connection()
            registration.password = ""
            registration.confirmation = ""
            connected(session)
        } catch SendaAccountClient.Failure.signedOut where step == .create {
            move(to: .verify)
        } catch SendaAccountClient.Failure.signedOut where step == .verify {
            move(to: .signIn)
            message = "Email verified. Sign in to continue."
        }
    }
}
