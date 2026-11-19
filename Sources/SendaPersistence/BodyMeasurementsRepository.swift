import Foundation
import SendaDomain

/// Manual measurements are stored separately from the workout journal and its exports.
@MainActor public protocol BodyMeasurementsRepository {
    func load() throws -> [BodyMeasurement]
    func save(_ readings: [BodyMeasurement]) throws
}

@MainActor public final class MemoryBodyMeasurementsRepository: BodyMeasurementsRepository {
    private var readings: [BodyMeasurement] = []
    public init() {}
    public func load() throws -> [BodyMeasurement] { readings }

    public func save(_ readings: [BodyMeasurement]) throws {
        try validateManualReadings(readings)
        self.readings = readings
    }
}

@MainActor public final class FileBodyMeasurementsRepository: BodyMeasurementsRepository {
    private let url: URL

    private struct Envelope: Codable {
        var version: Int = 1
        let readings: [BodyMeasurement]
    }

    /// Use a dedicated directory because the entire parent is excluded from device backups.
    public init(url: URL) { self.url = url }

    public func load() throws -> [BodyMeasurement] {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return [] }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.version == 1 else { throw BodyMeasurementError.manualHistoryUnavailable }
        try validateManualReadings(envelope.readings)
        return envelope.readings
    }

    public func save(_ readings: [BodyMeasurement]) throws {
        try validateManualReadings(readings)
        let data = try JSONEncoder().encode(Envelope(readings: readings))
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        var excludedDirectory = directory
        try excludedDirectory.setResourceValues(resources)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}

private func validateManualReadings(_ readings: [BodyMeasurement]) throws {
    guard Set(readings.map(\.id)).count == readings.count,
          readings.allSatisfy({ $0.source == .manual }) else {
        throw BodyMeasurementError.manualHistoryUnavailable
    }
    for reading in readings { try reading.validate() }
}
