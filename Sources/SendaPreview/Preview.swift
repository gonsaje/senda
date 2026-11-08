#if os(macOS)
import AppKit
import SwiftUI
import SendaDomain
import SendaLogger
import SendaPersistence
import SendaNotebook

/// Renders the real SwiftUI view on macOS; these are not iOS simulator screenshots.
@main @MainActor
struct SendaPreview {
    private static var liveWindow: NSWindow?
    static func main() throws {
        if CommandLine.arguments.contains("--live") {
            try openLivePreview()
            return
        }
        guard CommandLine.arguments.count == 2 else {
            print("Usage: swift run senda-preview /absolute/output/directory")
            return
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let date = Date()
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: SampleJournal.makeWeek(relativeTo: date)), isSample: true, now: { date })
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week.png"))
        _ = model.openDay(model.today)
        for id in ["cable-row", "lat-pulldown", "overhead-press", "lateral-raise", "biceps-curl", "triceps-extension", "push-up"] {
            _ = model.addExercise(id)
        }
        _ = model.selectExercise("bench")
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-day.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-draft.png"))
        try render(TrainingDayExerciseList(model: model, day: model.today, close: {}, add: {}),
                   to: directory.appendingPathComponent("senda-day-exercises.png"))
        try render(TrainingDayExerciseList(model: model, day: model.today, close: {}, add: {}),
                   to: directory.appendingPathComponent("senda-day-exercises-compact.png"), width: 320, height: 568)
        try render(TrainingExercisePicker(model: model, close: {}), to: directory.appendingPathComponent("senda-picker.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-compact.png"), width: 320, height: 568)
        _ = model.repeatLastSet()
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-exception.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-recorded.png"))
        print("Rendered actual SwiftUI week, day, picker and compact-phone states to \(directory.path).")
    }

    private static func openLivePreview() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("senda-weekly-live-preview/journal.json")
        let repository = FileJournalRepository(url: url)
        if !FileManager.default.fileExists(atPath: url.path) {
            try repository.save(SampleJournal.makeWeek())
        }
        let session = TrainingSession(repository: repository, isSample: true)
        let host = NSHostingView(rootView: TrainingSessionView(session: session)
            .environment(\.colorScheme, .light)
            .frame(minWidth: 320, minHeight: 568))
        let height = max(640, min(820, (NSScreen.main?.visibleFrame.height ?? 890) - 70))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 393, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Senda — Live preview"
        window.contentMinSize = NSSize(width: 320, height: 568)
        window.contentView = host
        window.isReleasedWhenClosed = false
        liveWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        FileHandle.standardOutput.write(Data("Senda live preview visible: \(window.isVisible)\n".utf8))
        NSApp.run()
    }

    private static func render<Content: View>(_ content: Content, to url: URL, width: CGFloat = 393, height: CGFloat = 820) throws {
        let view = content
            .frame(width: width, height: height)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
        // ImageRenderer omits platform-backed ScrollView/TextField content. Host the
        // real view in an off-screen window so those controls are captured, too.
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: width, height: height),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }
}
#else
@main struct SendaPreview {
    static func main() { print("Run this preview renderer on macOS.") }
}
#endif
