import SwiftUI
import SendaLogger
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum SendaContact {
    static let email = "hello@dontsweat.tech"
    static let mailURL = URL(string: "mailto:" + email)!
}

struct TrainerApplicationEmail {
    let name: String
    let subject = "Senda trainer application"

    var body: String {
        """
        Hi Senda,

        I'd like to apply for a trainer account.

        Name on my credential: \(name)
        Certification and issuer:
        Issuer verification link or credential number:

        """
    }

    var mailURL: URL? {
        var components = URLComponents(url: SendaContact.mailURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body.replacingOccurrences(of: "\n", with: "\r\n"))
        ]
        // Some mail clients decode a literal plus in the query as a space.
        let query = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components?.percentEncodedQuery = query
        return components?.url
    }

    var copyText: String {
        "To: \(SendaContact.email)\nSubject: \(subject)\n\n\(body)"
    }
}

struct TrainerPublishing: View {
    let model: TrainingNotebookModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var feedback: String?

    private var application: TrainerApplicationEmail {
        TrainerApplicationEmail(name: model.isSample ? "" : model.profile.details.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Review inbox") {
                        Text(verbatim: SendaContact.email).textSelection(.enabled)
                    }
                    Text("Include the name on your credential, the certification and issuer, and an issuer verification link or credential number.")
                    Button("Draft application email") {
                        feedback = nil
                        guard let url = application.mailURL else { showMailFallback(); return }
                        openURL(url) { opened in
                            if !opened { showMailFallback() }
                        }
                    }
                    .accessibilityIdentifier("trainer-draft-email")
                    Button("Copy email details") {
                        #if os(iOS)
                        UIPasteboard.general.string = application.copyText
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(application.copyText, forType: .string)
                        #endif
                        feedback = "Copied the recipient, subject, and application to your clipboard."
                    }
                    .accessibilityIdentifier("trainer-copy-email")
                    if let feedback { Text(feedback).font(.footnote) }
                } footer: {
                    Text("Send the application from the email address where you want to hear from us. We’ll reply there after review.")
                }
                if model.profile.details.trainerApplication != nil || model.isSample {
                    Section {
                        NavigationLink("Local trainer preview") { LocalTrainerPublishing(model: model) }
                    }
                }
            }
            .formStyle(.grouped).programPageStyle()
            .navigationTitle("Apply as a trainer")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .tint(NotebookStyle.clay)
    }

    private func showMailFallback() {
        feedback = "Couldn’t open your email app. Copy the email details and paste them into a new message."
    }
}
