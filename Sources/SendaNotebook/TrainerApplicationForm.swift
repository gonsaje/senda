import SwiftUI
import SendaLogger

struct ConnectedTrainerForm: View {
    let model: TrainingNotebookModel
    let account: SendaAccountClient.Connection
    let client: SendaAccountClient
    let disconnected: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TrainerApplicationSubmission
    @State private var lastAttempt: TrainerApplicationSubmission?
    @State private var isSubmitting = false
    @State private var received = false
    @State private var error: String?
    @FocusState private var focusedField: String?

    init(model: TrainingNotebookModel, account: SendaAccountClient.Connection,
         client: SendaAccountClient, disconnected: @escaping () -> Void) {
        self.account = account
        self.client = client
        self.disconnected = disconnected
        self.model = model
        _draft = State(initialValue: TrainerApplicationSubmission(name: model.isSample ? "" : model.profile.details.name, email: account.email))
    }

    var body: some View {
        NavigationStack {
            Form {
                if received {
                    Section {
                        Text("Application received").font(NotebookTypography.heading(24, relativeTo: .title2))
                            .accessibilityAddTraits(.isHeader)
                        Text("We’ll contact you at \(draft.email) after reviewing your application.")
                        Button("Submit another application") {
                            draft = TrainerApplicationSubmission(name: draft.name, email: draft.email)
                            lastAttempt = nil
                            received = false
                            error = nil
                        }.accessibilityIdentifier("trainer-apply-again")
                    }
                } else {
                    Section("Contact") {
                        field("Name on credential", prompt: "Full name", text: $draft.name, id: "name")
                            .textContentType(.name)
                        field("Contact email", prompt: "you@example.com", text: $draft.email, id: "email")
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                            #endif
                    }
                    ForEach($draft.credentials) { $credential in
                        let index = draft.credentials.firstIndex { $0.id == credential.id } ?? 0
                        Section {
                            field("Certification", prompt: "e.g. Certified Personal Trainer", text: $credential.certification,
                                  id: "certification-\(index)")
                            field("Issuing organization", prompt: "e.g. NASM", text: $credential.issuer, id: "issuer-\(index)")
                            field("Verification link or credential number", prompt: "Issuer URL or ID", text: $credential.verification,
                                  id: "verification-\(index)")
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                #endif
                            if draft.credentials.count > 1 {
                                Button("Remove certification", role: .destructive) {
                                    let removed = credential.id
                                    focusedField = nil
                                    draft.credentials.removeAll { $0.id == removed }
                                }
                                .accessibilityLabel("Remove certification \(index + 1)")
                            }
                        } header: {
                            Text("Certification \(index + 1)")
                        }
                    }
                    Section {
                        Button("Add certification") { draft.credentials.append(.init()) }
                            .disabled(draft.credentials.count >= TrainerApplicationSubmission.maximumCredentials)
                            .accessibilityIdentifier("trainer-add-certification")
                    } footer: {
                        Text("Senda uses these details to verify your certifications and reply to your application.")
                    }
                    Section {
                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                Text(isSubmitting ? "Submitting…" : "Submit application").fontWeight(.semibold)
                                if isSubmitting { ProgressView().controlSize(.small) }
                            }.frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(NotebookStyle.clay)
                        }
                        .accessibilityIdentifier("trainer-submit")
                    }
                }
                if let error { Text(error).font(.callout).accessibilityIdentifier("trainer-submission-error") }
                if model.profile.details.trainerApplication != nil || model.isSample {
                    Section {
                        NavigationLink("Local trainer preview") { LocalTrainerPublishing(model: model) }
                    }
                }
                Section {
                    Button("Sign out of Senda") { Task { await signOut() } }
                } header: { Text(verbatim: account.email) }
            }
            .disabled(isSubmitting)
            .scrollDismissesKeyboard(.interactively)
            .formStyle(.grouped).programPageStyle()
            .navigationTitle("Apply as a trainer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(received ? "Done" : "Cancel") { dismiss() }.disabled(isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
        .tint(NotebookStyle.clay)
    }

    private func field(_ title: LocalizedStringKey, prompt: LocalizedStringKey, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.medium)).accessibilityHidden(true)
            TextField(title, text: text, prompt: Text(prompt)).focused($focusedField, equals: id)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .accessibilityIdentifier("trainer-" + id)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = id }
    }

    private func signOut() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await client.signOut()
            disconnected()
        } catch {
            self.error = "Couldn’t sign out. Please try again."
        }
    }

    private func submit() async {
        guard !isSubmitting, !received else { return }
        var form = draft.trimmed
        focusedField = nil
        if let message = form.validationError {
            error = message
            TrainingAccessibility.announce(message)
            return
        }
        if let lastAttempt, form != lastAttempt { form.id = UUID() }
        draft = form
        lastAttempt = form
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        do {
            let current = try await client.connection()
            guard current.id == account.id else { disconnected(); return }
            try await form.submit(using: client, token: current.token)
            received = true
            TrainingAccessibility.announce("Application received")
        } catch SendaAccountClient.Failure.signedOut {
            disconnected()
        } catch {
            let message = (error as? TrainerApplicationSubmission.SubmissionError)?.errorDescription
                ?? "Couldn’t reach Senda. Check your connection and try again."
            self.error = message
            TrainingAccessibility.announce(message)
        }
    }
}
