import Foundation
import SendaDomain

@MainActor public protocol ProfileRepository {
    func load() throws -> ProfileDetails
    func save(_ details: ProfileDetails) throws
}
@MainActor public final class MemoryProfileRepository: ProfileRepository {
    private var details = ProfileDetails()
    public init() {}
    public func load() throws -> ProfileDetails { details }
    public func save(_ details: ProfileDetails) throws { self.details = try details.validated() }
}
@MainActor public final class FileProfileRepository: ProfileRepository {
    private let url: URL
    private let writer: (Data, URL) throws -> Void
    private struct Envelope: Codable { let version: Int; let details: ProfileDetails }
    public convenience init(url: URL) { self.init(url: url, writer: { try $0.write(to: $1, options: .atomic) }) }
    init(url: URL, writer: @escaping (Data, URL) throws -> Void) { self.url = url; self.writer = writer }
    public func load() throws -> ProfileDetails {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return ProfileDetails() }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.version == 1 else { throw ProfileStorageError.unsupportedVersion }
        return try envelope.details.validated()
    }
    public func save(_ details: ProfileDetails) throws {
        let data = try JSONEncoder().encode(Envelope(version: 1, details: details.validated()))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writer(data, url)
    }
}
public enum ProfileStorageError: LocalizedError {
    case unsupportedVersion
    public var errorDescription: String? { "This profile uses a newer format. Its file has been left untouched." }
}
