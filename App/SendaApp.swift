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
        }
    }
}

private struct JournalRootView: View {
    @State private var model: LoggerModel?
    @State private var openingError: String?

    var body: some View {
        Group {
            if let model {
                NotebookView(model: model)
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
        .task { if model == nil && openingError == nil { openJournal() } }
    }

    private func openJournal() {
        do {
            let sample = ProcessInfo.processInfo.arguments.contains("--sample-data")
            let repository: any JournalRepository
            if sample {
                repository = MemoryJournalRepository(journal: try SampleJournal.make())
            } else {
                let support = try FileManager.default.url(for: .applicationSupportDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true)
                repository = FileJournalRepository(url: support.appendingPathComponent("Senda/journal-v1.json"))
            }
            model = try LoggerModel(repository: repository, isSample: sample)
            openingError = nil
        } catch { openingError = error.localizedDescription }
    }
}
