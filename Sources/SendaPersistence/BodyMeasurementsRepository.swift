import Foundation
import SendaDomain

/// The pending identifiers and manual readings are committed together, including deletions.
public struct MeasurementSharing: Codable, Equatable, Sendable {
    public struct Change: Codable, Equatable, Sendable {
        public let id: UUID
        public let metric: BodyMetric
        public let version: Int64
    }
    public private(set) var revision: Int64 = 0
    public var pending: [UUID: Change] = [:]
    public var metrics: Set<BodyMetric>
    public init(metrics: Set<BodyMetric>) { self.metrics = metrics }

    public mutating func enqueue(_ reading: BodyMeasurement) {
        guard metrics.contains(reading.metric) else { return }
        revision = max(revision + 1, Int64(Date.now.timeIntervalSince1970 * 1_000_000))
        pending[reading.id] = Change(id: reading.id, metric: reading.metric, version: revision)
    }
}

public struct BodyMeasurementStore: Codable {
    let version: Int
    public var readings: [BodyMeasurement]
    public var sharing: MeasurementSharing?

    public init(readings: [BodyMeasurement] = [], sharing: MeasurementSharing? = nil) {
        version = 1
        self.readings = readings
        self.sharing = sharing
    }
}

@MainActor public protocol BodyMeasurementsRepository {
    func loadStore() throws -> BodyMeasurementStore
    func saveStore(_ state: BodyMeasurementStore) throws
}

public extension BodyMeasurementsRepository {
    func load() throws -> [BodyMeasurement] { try loadStore().readings }

    /// A restored journal never opts the device into exporting its backup to Health.
    func save(_ readings: [BodyMeasurement]) throws {
        try saveStore(BodyMeasurementStore(readings: readings))
    }
}

@MainActor public final class MemoryBodyMeasurementsRepository: BodyMeasurementsRepository {
    private var state = BodyMeasurementStore()
    public init() {}
    public func loadStore() throws -> BodyMeasurementStore { state }

    public func saveStore(_ state: BodyMeasurementStore) throws {
        try validateManualReadings(state.readings)
        self.state = state
    }
}

@MainActor public final class FileBodyMeasurementsRepository: BodyMeasurementsRepository {
    private let url: URL

    /// Use a dedicated directory because the entire parent is excluded from device backups.
    public init(url: URL) { self.url = url }

    public func loadStore() throws -> BodyMeasurementStore {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return BodyMeasurementStore() }
        let state = try JSONDecoder().decode(BodyMeasurementStore.self, from: data)
        guard state.version == 1 else { throw BodyMeasurementError.manualHistoryUnavailable }
        try validateManualReadings(state.readings)
        return state
    }

    public func saveStore(_ state: BodyMeasurementStore) throws {
        try save(state, writer: Self.protectedWrite)
    }

    func save(_ readings: [BodyMeasurement], writer: (Data, URL) throws -> Void) throws {
        try save(BodyMeasurementStore(readings: readings), writer: writer)
    }

    private func save(_ state: BodyMeasurementStore, writer: (Data, URL) throws -> Void) throws {
        try validateManualReadings(state.readings)
        let data = try JSONEncoder().encode(state)
        try Self.preparePrivateDirectory(url.deletingLastPathComponent())
        try writer(data, url)
    }

    static func preparePrivateDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        var excludedDirectory = directory
        try excludedDirectory.setResourceValues(resources)
        #endif
    }

    static func protectedWrite(_ data: Data, _ url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}

func validateManualReadings(_ readings: [BodyMeasurement]) throws {
    guard Set(readings.map(\.id)).count == readings.count,
          readings.allSatisfy({ $0.source == .manual }) else {
        throw BodyMeasurementError.manualHistoryUnavailable
    }
    for reading in readings { try reading.validate() }
}
