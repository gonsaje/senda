import SwiftUI
import UIKit
import SendaDomain
import SendaPersistence
import SendaLogger
import SendaNotebook

@main
struct SendaApp: App {
    @State private var showsLaunchIntro = true

    var body: some Scene {
        WindowGroup {
            JournalRootView(showsLaunchIntro: $showsLaunchIntro)
                .defaultAppStorage(preferences)
        }
    }

    private var preferences: UserDefaults {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["SENDA_UI_TEST_JOURNAL_ID"].flatMap(UUID.init(uuidString:)),
           let defaults = UserDefaults(suiteName: "senda.ui-tests.\(id.uuidString)") {
            return defaults
        }
        #endif
        if ProcessInfo.processInfo.arguments.contains("--sample-data"),
           let defaults = UserDefaults(suiteName: "com.senda.journal.sample-launch-preferences") {
            return defaults
        }
        return .standard
    }
}

private struct JournalRootView: View {
    @Binding var showsLaunchIntro: Bool
    @AppStorage(NotebookAppearance.preferenceKey) private var appearance: NotebookAppearance = .system
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: TrainingSession?
    @State private var automaticBackup: NotebookAutomaticBackup?
    @State private var openingError: String?

    var body: some View {
        ZStack {
            content
                .accessibilityHidden(showsLaunchIntro)
                .allowsHitTesting(!showsLaunchIntro)
            if showsLaunchIntro {
                SendaLaunchIntro(profileName: session?.notebook?.profile.details.name,
                                 isReady: session != nil || openingError != nil) {
                    showsLaunchIntro = false
                }
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .background { WindowAppearance(appearance: appearance).allowsHitTesting(false).accessibilityHidden(true) }
        .task { if session == nil && openingError == nil { openJournal() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { showsLaunchIntro = false }
            if phase != .active { session?.suspend() }
        }
    }

    @ViewBuilder private var content: some View {
        if let session {
            TrainingSessionView(session: session, automaticBackup: automaticBackup)
        } else if let openingError {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your journal couldn’t be opened.")
                    .font(NotebookTypography.heading(34, relativeTo: .largeTitle))
                Text(openingError).font(.body)
                Text("Your saved file has been left untouched.").font(.callout)
                Button("Try again", action: openJournal)
                    .buttonStyle(.borderedProminent)
                    .tint(NotebookStyle.primaryFill)
                    .foregroundStyle(NotebookStyle.onPrimary)
            }
            .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView("Opening journal…")
        }
    }

    private func openJournal() {
        do {
            if ProcessInfo.processInfo.arguments.contains("--sample-data") {
                session = try TrainingSession.sample()
            } else {
                let support = try FileManager.default.url(for: .applicationSupportDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true)
                var journalPath = "Senda/journal-v1.json"
                #if DEBUG
                // A unique test journal uses the real file adapter without touching a person's journal.
                if let rawID = ProcessInfo.processInfo.environment["SENDA_UI_TEST_JOURNAL_ID"],
                   let id = UUID(uuidString: rawID) {
                    journalPath = "Senda/UITests/\(id.uuidString)/journal-v1.json"
                }
                #endif
                let journalURL = support.appendingPathComponent(journalPath)
                let dataDirectory = journalURL.deletingLastPathComponent()
                let profileURL = dataDirectory.appendingPathComponent("profile.json")
                session = TrainingSession(repository: FileJournalRepository(url: journalURL),
                    profileRepository: FileProfileRepository(url: profileURL),
                    restoreStore: FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL),
                    health: AppleHealthBodyMeasurements())
                automaticBackup = NotebookAutomaticBackup(
                    settingsURL: dataDirectory.appendingPathComponent("backup-settings.json")
                )
            }
            openingError = nil
        } catch { openingError = error.localizedDescription }
    }
}

/// Applying the override to this window also updates sheets already presented above the notebook.
private struct WindowAppearance: UIViewRepresentable {
    let appearance: NotebookAppearance

    func makeUIView(context: Context) -> AppearanceView { AppearanceView() }

    func updateUIView(_ view: AppearanceView, context: Context) {
        view.style = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    final class AppearanceView: UIView {
        var style: UIUserInterfaceStyle = .unspecified {
            didSet { applyToWindow() }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyToWindow()
        }

        private func applyToWindow() {
            guard let window, window.overrideUserInterfaceStyle != style else { return }
            window.overrideUserInterfaceStyle = style
        }
    }
}
