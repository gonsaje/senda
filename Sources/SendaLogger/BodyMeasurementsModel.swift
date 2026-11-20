import Foundation
import Observation
import SendaDomain
import SendaPersistence

@MainActor public protocol BodyMeasurementsHealthSource {
    func requestAccess() async throws
    func read() async throws -> [BodyMeasurement]
}

public struct BodyMeasurementPeriod {
    public let readings: [BodyMeasurement]
    public let precedingWeight: BodyMeasurement?
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

    /// Newest first. Manual entries retain their chosen civil date when the reader travels.
    public func readings(for metric: BodyMetric, in days: ClosedRange<TrainingDay>? = nil,
                         calendar: Calendar = .current) -> [BodyMeasurement] {
        period(for: metric, in: days, calendar: calendar).readings
    }

    /// Only an actual weigh-in before the first day can seed the weight chart.
    /// History always contains just the readings taken during the requested period.
    public func period(for metric: BodyMetric, in days: ClosedRange<TrainingDay>?,
                       calendar: Calendar = .current) -> BodyMeasurementPeriod {
        typealias Entry = (reading: BodyMeasurement, displayDate: Date)
        func newer(_ lhs: Entry, than rhs: Entry) -> Bool {
            if lhs.displayDate != rhs.displayDate { return lhs.displayDate > rhs.displayDate }
            if lhs.reading.date != rhs.reading.date { return lhs.reading.date > rhs.reading.date }
            return lhs.reading.id.uuidString < rhs.reading.id.uuidString
        }

        let firstDay = days.map { calendar.startOfDay(for: $0.lowerBound.date(in: calendar)) }
        let endDay = days.map { $0.upperBound.date(in: calendar) }
        var visible: [Entry] = []
        var previous: Entry?
        for reading in manualReadings + healthReadings where reading.metric == metric {
            let entry: Entry = (reading, reading.displayDate(in: calendar))
            if let endDay, calendar.compare(entry.displayDate, to: endDay, toGranularity: .day) == .orderedDescending { continue }
            if let firstDay, entry.displayDate < firstDay {
                if metric == .weight && (previous.map { newer(entry, than: $0) } ?? true) { previous = entry }
            } else {
                visible.append(entry)
            }
        }
        return BodyMeasurementPeriod(readings: visible.sorted(by: newer).map(\.reading), precedingWeight: previous?.reading)
    }

    public func hasReadings(for metric: BodyMetric) -> Bool {
        manualReadings.contains { $0.metric == metric } || hasHealthReadings(for: metric)
    }

    public func hasHealthReadings(for metric: BodyMetric) -> Bool {
        healthReadings.contains { $0.metric == metric }
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
