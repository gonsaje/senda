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
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            print("Usage: swift run senda-preview /absolute/output/directory")
            return
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let date = ISO8601DateFormatter().date(from: "2026-11-06T17:00:00Z")!
        let model = try LoggerModel(repository: MemoryJournalRepository(journal: SampleJournal.make(relativeTo: date)),
                                    isSample: true, now: { date })
        try render(model, to: directory.appendingPathComponent("senda-draft.png"))
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        _ = model.confirmSetEdits()
        try render(model, to: directory.appendingPathComponent("senda-exception.png"))
        _ = model.record()
        try render(model, to: directory.appendingPathComponent("senda-recorded.png"))
        print("Rendered the actual SwiftUI notebook in three states to \(directory.path).")
    }

    private static func render(_ model: LoggerModel, to url: URL) throws {
        let view = NotebookView(model: model)
            .frame(width: 393, height: 820)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
        // ImageRenderer omits platform-backed ScrollView/TextField content. Host the
        // real view in an off-screen window so those controls are captured, too.
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 393, height: 820),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        window.orderOut(nil)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }
}
#else
@main struct SendaPreview {
    static func main() { print("Run this preview renderer on macOS.") }
}
#endif
