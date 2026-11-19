import Foundation
import Observation
import SendaDomain
import SendaPersistence

@MainActor public protocol BodyMeasurementsHealthSource {
    func requestAccess() async throws
    func read() async throws -> [BodyMeasurement]
}

@Observable @MainActor public final class BodyMeasurementsModel {
    private let repository: any BodyMeasurementsRepository
    private let health: (any BodyMeasurementsHealthSource)?
    private var manualReadings: [BodyMeasurement] = []
    private var healthReadings: [BodyMeasurement] = []
    private var healthRefreshID: UUID?

    public private(set) var manualLoadFailed = false
    public private(set) var healthError: String?
    public private(set) var isRequestingHealthAccess = false
    public var supportsAppleHealth: Bool { health != nil }
    public var isRefreshingHealth: Bool { healthRefreshID != nil }

    public init(repository: any BodyMeasurementsRepository, health: (any BodyMeasurementsHealthSource)? = nil) {
        self.repository = repository
        self.health = health
        reloadManual()
    }

    public func reloadManual() {
        do {
            manualReadings = try repository.load()
            manualLoadFailed = false
        } catch { manualLoadFailed = true }
    }

    public func readings(for metric: BodyMetric, calendar: Calendar = .current) -> [BodyMeasurement] {
        (manualReadings + healthReadings)
            .filter { $0.metric == metric }
            .map { (reading: $0, displayDate: $0.displayDate(in: calendar)) }
            .sorted {
                if $0.displayDate != $1.displayDate { return $0.displayDate > $1.displayDate }
                if $0.reading.date != $1.reading.date { return $0.reading.date > $1.reading.date }
                return $0.reading.id.uuidString < $1.reading.id.uuidString
            }
            .map(\.reading)
    }

    public func add(_ values: [BodyMetric: Double], on date: Date) throws {
        guard !values.isEmpty else { throw BodyMeasurementError.noValues }
        let added = try values.map { try BodyMeasurement(metric: $0.key, value: $0.value, date: date) }
        try save(manualReadings + added)
    }

    public func update(_ reading: BodyMeasurement, value: Double, on date: Date) throws {
        var updated = manualReadings
        let index = try manualIndex(for: reading)
        updated[index] = try BodyMeasurement(id: reading.id, metric: reading.metric, value: value, date: date)
        try save(updated)
    }

    public func remove(_ reading: BodyMeasurement) throws {
        var updated = manualReadings
        updated.remove(at: try manualIndex(for: reading))
        try save(updated)
    }

    private func manualIndex(for reading: BodyMeasurement) throws -> Int {
        guard reading.source == .manual, let index = manualReadings.firstIndex(where: { $0.id == reading.id }) else {
            throw BodyMeasurementError.missingManualReading
        }
        return index
    }

    private func save(_ readings: [BodyMeasurement]) throws {
        guard !manualLoadFailed else { throw BodyMeasurementError.manualHistoryUnavailable }
        try repository.save(readings)
        manualReadings = readings
    }

    public func requestHealthAccess() async -> Bool {
        guard let health, !isRequestingHealthAccess else { return false }
        isRequestingHealthAccess = true
        healthError = nil
        defer { isRequestingHealthAccess = false }
        do {
            try await health.requestAccess()
            return true
        } catch {
            healthError = "Couldn’t open Apple Health access. Try again."
            return false
        }
    }

    public func refreshHealth() async {
        guard let health else { return }
        let id = UUID()
        healthRefreshID = id
        healthError = nil
        defer { if id == healthRefreshID { healthRefreshID = nil } }
        do {
            let readings = try await health.read()
            guard id == healthRefreshID, !Task.isCancelled else { return }
            var seen = Set<UUID>()
            healthReadings = readings.filter { seen.insert($0.id).inserted }
        } catch {
            guard id == healthRefreshID, !Task.isCancelled else { return }
            healthReadings = []
            healthError = "Couldn’t read Apple Health measurements. Try again."
        }
    }

    public func disconnectHealth() {
        healthRefreshID = nil
        healthReadings = []
        healthError = nil
    }
}
