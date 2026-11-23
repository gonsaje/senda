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
    static func portableRecoveryData(_ data: Data) -> Data? {
        struct RecoveryProfile: Decodable {
            let version: Int
            let details: ProfileDetails
            private enum CodingKeys: CodingKey { case version, details }

            init(from decoder: any Decoder) throws {
                let box = try decoder.container(keyedBy: CodingKeys.self)
                version = try box.decode(Int.self, forKey: .version)
                details = try ProfileDetails(from: box.superDecoder(forKey: .details), includesTrainerApplication: false)
            }
        }
        guard let profile = try? JSONDecoder().decode(RecoveryProfile.self, from: data), (1...3).contains(profile.version) else { return nil }
        return try? JSONEncoder().encode(Envelope(version: profile.version, details: profile.details))
    }

    public convenience init(url: URL) { self.init(url: url, writer: { try $0.write(to: $1, options: .atomic) }) }
    init(url: URL, writer: @escaping (Data, URL) throws -> Void) { self.url = url; self.writer = writer }
    public func load() throws -> ProfileDetails {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return ProfileDetails() }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard (1...3).contains(envelope.version) else { throw ProfileStorageError.unsupportedVersion }
        return try envelope.details.validated()
    }
    public func save(_ details: ProfileDetails) throws {
        let profile = try details.validated()
        let version = if !profile.weeklyMuscleTargets.isEmpty { 3 } else if !profile.goals.isEmpty { 2 } else { 1 }
        let data = try JSONEncoder().encode(Envelope(version: version, details: profile))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writer(data, url)
    }
}
public enum ProfileStorageError: LocalizedError {
    case unsupportedVersion
    public var errorDescription: String? { "This profile uses a newer format. Its file has been left untouched." }
}
