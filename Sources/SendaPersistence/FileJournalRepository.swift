import Foundation
import SendaDomain

@MainActor public final class FileJournalRepository: JournalRepository {
    private let url: URL
    private let writer: (Data, URL) throws -> Void

    public convenience init(url: URL) {
        self.init(url: url, writer: { data, url in try data.write(to: url, options: .atomic) })
    }

    init(url: URL, writer: @escaping (Data, URL) throws -> Void) {
        self.url = url
        self.writer = writer
    }

    private struct Envelope: Codable {
        let version: Int
        let journal: Journal
    }
    private struct FormatHeader: Decodable { let version: Int }

    public func load() throws -> Journal {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return Journal()
        }
        let decoder = JSONDecoder()
        let header = try decoder.decode(FormatHeader.self, from: data)
        guard header.version == 1 else { throw StorageError.unsupportedVersion(header.version) }
        let envelope = try decoder.decode(Envelope.self, from: data)
        return try envelope.journal.validated()
    }

    public func save(_ journal: Journal) throws {
        let validated = try journal.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(version: 1, journal: validated))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writer(data, url)
    }
}

public enum StorageError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This journal uses format \(version), which this app cannot open. The file has been left untouched."
        }
    }
}
