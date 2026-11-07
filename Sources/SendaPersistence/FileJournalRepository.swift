import Foundation
import SendaDomain

@MainActor public final class FileJournalRepository: JournalRepository {
    private let url: URL
    private let writer: (Data, URL) throws -> Void
    public convenience init(url: URL) {
        self.init(url: url, writer: { data, url in try data.write(to: url, options: .atomic) })
    }
    init(url: URL, writer: @escaping (Data, URL) throws -> Void) {
        self.url = url; self.writer = writer
    }
    private struct Header: Decodable { let version: Int }
    private struct Envelope: Codable {
        let version: Int
        let journal: Journal
        let workspace: EntryWorkspace?
        let customExercises: [Exercise]?
    }

    public func loadSnapshot() throws -> JournalSnapshot {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return JournalSnapshot() }
        let decoder = JSONDecoder()
        let version = try decoder.decode(Header.self, from: data).version
        guard (1...3).contains(version) else { throw StorageError.unsupportedVersion(version) }
        let envelope = try decoder.decode(Envelope.self, from: data)
        if version == 3, envelope.customExercises == nil { throw StorageError.missingExerciseLibrary }
        return try JournalSnapshot(journal: envelope.journal, workspace: version == 1 ? nil : envelope.workspace,
                                   customExercises: version == 3 ? envelope.customExercises : nil).validated()
    }

    public func saveSnapshot(_ snapshot: JournalSnapshot) throws {
        let snapshot = try snapshot.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(version: 3, journal: snapshot.journal, workspace: snapshot.workspace,
                                               customExercises: snapshot.customExercises ?? []))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writer(data, url)
    }
}

public enum StorageError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case missingExerciseLibrary
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This journal uses format \(version), which this app cannot open. The file has been left untouched."
        case .missingExerciseLibrary:
            "The saved exercise library is missing. The journal file has been left untouched."
        }
    }
}
