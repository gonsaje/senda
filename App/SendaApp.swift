import SwiftUI
import SendaDomain
import SendaPersistence
import SendaLogger
import SendaNotebook

@main
struct SendaApp: App {
    var body: some Scene {
        WindowGroup {
            JournalRootView().preferredColorScheme(.light)
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
        return .standard
    }
}

private struct JournalRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: TrainingSession?
    @State private var automaticBackup: NotebookAutomaticBackup?
    @State private var openingError: String?

    var body: some View {
        content
            .task { if session == nil && openingError == nil { openJournal() } }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { session?.suspend() }
            }
    }

    @ViewBuilder private var content: some View {
        if let session {
            TrainingSessionView(session: session, automaticBackup: automaticBackup)
        } else if let openingError {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your journal couldn’t be opened.")
                    .font(.system(.largeTitle, design: .serif))
                Text(openingError).font(.body)
                Text("Your saved file has been left untouched.").font(.callout)
                Button("Try again", action: openJournal).buttonStyle(.borderedProminent)
            }
            .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 247 / 255, green: 243 / 255, blue: 235 / 255))
            .tint(Color(red: 169 / 255, green: 78 / 255, blue: 50 / 255))
        } else {
            ProgressView("Opening journal…")
        }
    }

    private func openJournal() {
        do {
            if ProcessInfo.processInfo.arguments.contains("--sample-data") {
                session = try makeSampleSession()
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
                let profileURL = journalURL.deletingLastPathComponent().appendingPathComponent("profile.json")
                session = TrainingSession(repository: FileJournalRepository(url: journalURL),
                    profileRepository: FileProfileRepository(url: profileURL),
                    restoreStore: FileNotebookRestoreStore(journalURL: journalURL, profileURL: profileURL))
                automaticBackup = NotebookAutomaticBackup(
                    settingsURL: journalURL.deletingLastPathComponent().appendingPathComponent("backup-settings.json")
                )
            }
            openingError = nil
        } catch { openingError = error.localizedDescription }
    }

    private func makeSampleSession() throws -> TrainingSession {
        let repository = MemoryJournalRepository(journal: try SampleJournal.makeTwelveWeeks())
        let profile = MemoryProfileRepository()
        try profile.save(ProfileDetails(goals: [
            StrengthGoal(exerciseID: "bench", target: SetValues(weight: 15_500, reps: 8)),
            StrengthGoal(exerciseID: "deadlift", target: SetValues(weight: 21_500, reps: 5))
        ]))
        return TrainingSession(repository: repository, isSample: true, profileRepository: profile)
    }
}
