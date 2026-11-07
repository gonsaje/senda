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
        let trainingEnabled: Bool?
        let training: TrainingWorkspace?
    }

    public func loadSnapshot() throws -> JournalSnapshot {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return JournalSnapshot() }
        let decoder = JSONDecoder()
        let version = try decoder.decode(Header.self, from: data).version
        guard (1...4).contains(version) else { throw StorageError.unsupportedVersion(version) }
        let envelope = try decoder.decode(Envelope.self, from: data)
        if version >= 3, envelope.customExercises == nil { throw StorageError.missingExerciseLibrary }
        if version == 4 {
            guard let enabled = envelope.trainingEnabled, enabled == (envelope.training != nil) else { throw StorageError.missingTrainingWorkspace }
        }
        return try JournalSnapshot(journal: envelope.journal, workspace: version == 1 ? nil : envelope.workspace,
            customExercises: version >= 3 ? envelope.customExercises : nil, training: version == 4 ? envelope.training : nil).validated()
    }

    public func saveSnapshot(_ snapshot: JournalSnapshot) throws {
        let snapshot = try snapshot.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(version: 4, journal: snapshot.journal, workspace: snapshot.workspace,
                                               customExercises: snapshot.customExercises ?? [],
                                               trainingEnabled: snapshot.training != nil, training: snapshot.training))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writer(data, url)
    }
}

public enum StorageError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case missingExerciseLibrary
    case missingTrainingWorkspace
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This journal uses format \(version), which this app cannot open. The file has been left untouched."
        case .missingTrainingWorkspace:
            "The saved notebook is missing or inconsistent. The journal file has been left untouched."
        case .missingExerciseLibrary:
            "The saved exercise library is missing. The journal file has been left untouched."
        }
    }
}
