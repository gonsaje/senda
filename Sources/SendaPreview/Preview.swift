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
        let model = try LoggerModel(repository: MemoryJournalRepository(journal: SampleJournal.make(relativeTo: date)),
                                    isSample: true, now: { date })
        try render(model, to: directory.appendingPathComponent("senda-draft.png"))
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        _ = model.confirmSetEdits()
        model.selectSet(3, field: .weight, unit: .kilograms)
        try render(model, to: directory.appendingPathComponent("senda-exception.png"))
        try render(model, to: directory.appendingPathComponent("senda-compact.png"), width: 320, height: 568)
        _ = model.record()
        try render(model, to: directory.appendingPathComponent("senda-recorded.png"))
        print("Rendered the actual SwiftUI notebook and compact-phone check to \(directory.path).")
    }

    private static func openLivePreview() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("senda-live-preview/journal.json")
        let repository = FileJournalRepository(url: url)
        if !FileManager.default.fileExists(atPath: url.path) {
            try repository.save(SampleJournal.make())
        }
        let model = try LoggerModel(repository: repository, isSample: true)
        let host = NSHostingView(rootView: NotebookView(model: model)
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

    private static func render(_ model: LoggerModel, to url: URL, width: CGFloat = 393, height: CGFloat = 820) throws {
        let view = NotebookView(model: model)
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
