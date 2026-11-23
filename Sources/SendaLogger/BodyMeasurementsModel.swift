import Foundation
import Observation
import SendaDomain
import SendaPersistence

public struct DailyHealthActivity: Equatable, Sendable {
    public var steps: Double?
    public var activeCalories: Double?
    public init(steps: Double? = nil, activeCalories: Double? = nil) {
        self.steps = steps
        self.activeCalories = activeCalories
    }
}

@MainActor public protocol BodyMeasurementsHealthSource {
    func requestAccess() async throws
    func read() async throws -> [BodyMeasurement]
    func activity(on day: Date) async throws -> DailyHealthActivity
    func addActivity(_ activity: DailyHealthActivity, date: Date, id: UUID) async throws
    func requestMeasurementSharing() async throws -> Set<BodyMetric>
    func write(_ change: MeasurementSharing.Change, reading: BodyMeasurement?) async throws
}

public struct BodyMeasurementPeriod {
    public let readings: [BodyMeasurement]
    public let precedingWeight: BodyMeasurement?
}

@Observable @MainActor public final class BodyMeasurementsModel {
    private let repository: any BodyMeasurementsRepository
    private let health: (any BodyMeasurementsHealthSource)?
    private(set) var manualReadings: [BodyMeasurement] = []
    private var healthReadings: [BodyMeasurement] = []
    private var healthRefreshID: UUID?
    private var activityRefreshID: UUID?
    private var sharing: MeasurementSharing?
    private var sendingChanges = false
    public var sharesMeasurements: Bool { sharing != nil }
    public private(set) var sharingError: String?
    public private(set) var activityError: String?
    public private(set) var activity = DailyHealthActivity()

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
            let state = try repository.loadStore()
            manualReadings = state.readings
            sharing = state.sharing
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
        let localIDs = Set(manualReadings.map(\.id)).union(sharing?.pending.keys.map { $0 } ?? [])
        let imported = healthReadings.filter { !localIDs.contains($0.id) }
        for reading in manualReadings + imported where reading.metric == metric {
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
        try save(manualReadings + added, changed: added)
    }

    public func update(_ reading: BodyMeasurement, value: Double, on date: Date) throws {
        var updated = manualReadings
        let index = try manualIndex(for: reading)
        updated[index] = try BodyMeasurement(id: reading.id, metric: reading.metric, value: value, date: date)
        try save(updated, changed: [updated[index]])
    }

    public func remove(_ reading: BodyMeasurement) throws {
        var updated = manualReadings
        updated.remove(at: try manualIndex(for: reading))
        try save(updated, changed: [reading])
    }

    private func manualIndex(for reading: BodyMeasurement) throws -> Int {
        guard reading.source == .manual, let index = manualReadings.firstIndex(where: { $0.id == reading.id }) else {
            throw BodyMeasurementError.missingManualReading
        }
        return index
    }

    private func save(_ readings: [BodyMeasurement], changed: [BodyMeasurement]) throws {
        var next = sharing
        for reading in changed { next?.enqueue(reading) }
        try persist(readings, sharing: next)
        if next != nil { Task { await syncPendingMeasurements() } }
    }

    private func persist(_ readings: [BodyMeasurement], sharing next: MeasurementSharing?) throws {
        guard !manualLoadFailed else { throw BodyMeasurementError.manualHistoryUnavailable }
        try repository.saveStore(BodyMeasurementStore(readings: readings, sharing: next))
        manualReadings = readings
        sharing = next
    }

    public func enableMeasurementSharing() async {
        guard let health, !isRequestingHealthAccess else { return }
        isRequestingHealthAccess = true
        defer { isRequestingHealthAccess = false }
        do {
            let metrics = try await health.requestMeasurementSharing()
            guard !metrics.isEmpty else {
                sharingError = "Allow Senda to write at least one measurement in Apple Health."
                return
            }
            var next = sharing ?? MeasurementSharing(metrics: metrics)
            let newlyEnabled = metrics.subtracting(sharing?.metrics ?? [])
            next.metrics = metrics
            for reading in manualReadings where newlyEnabled.contains(reading.metric) { next.enqueue(reading) }
            try persist(manualReadings, sharing: next)
            await syncPendingMeasurements()
        } catch { sharingError = "Couldn’t turn on measurement sharing. Try again." }
    }

    @discardableResult public func stopMeasurementSharing() -> Bool {
        do {
            if sharing != nil { try persist(manualReadings, sharing: nil) }
            sharingError = nil
            return true
        } catch {
            sharingError = "Couldn’t save your sharing preference. Try again."
            return false
        }
    }

    public func syncPendingMeasurements() async {
        guard let health, sharing != nil, !manualLoadFailed, !sendingChanges else { return }
        sendingChanges = true
        defer { sendingChanges = false }
        sharingError = nil
        var attempted = Set<Int64>()
        while let change = sharing?.pending.values.first(where: { !attempted.contains($0.version) }) {
            attempted.insert(change.version)
            let reading = manualReadings.first { $0.id == change.id }
            do {
                try await health.write(change, reading: reading)
                guard var next = sharing, next.pending[change.id] == change else { continue }
                if reading == nil {
                    healthRefreshID = nil
                    healthReadings.removeAll { $0.id == change.id }
                }
                next.pending[change.id] = nil
                try persist(manualReadings, sharing: next)
            } catch {
                if sharing?.pending[change.id] == change {
                    sharingError = "Some changes are waiting to sync. Check write access in Apple Health and retry."
                }
            }
        }
        if sharing?.pending.isEmpty == true { sharingError = nil }
    }

    public func refreshActivity(on date: Date = .now) async {
        guard let health else { return }
        let id = UUID()
        activityRefreshID = id
        do {
            let totals = try await health.activity(on: date)
            guard activityRefreshID == id, !Task.isCancelled else { return }
            activity = totals
            activityError = nil
        } catch {
            guard activityRefreshID == id, !Task.isCancelled else { return }
            activity = DailyHealthActivity()
            activityError = "Couldn’t read today’s activity from Apple Health."
        }
    }

    public func addActivity(_ entry: DailyHealthActivity, date: Date, id: UUID) async throws {
        guard let health else { throw BodyMeasurementError.manualHistoryUnavailable }
        let values = [entry.steps, entry.activeCalories].compactMap { $0 }
        guard !values.isEmpty, values.allSatisfy({ $0.isFinite && $0 > 0 }),
              entry.steps.map({ $0.rounded() == $0 }) ?? true else { throw BodyMeasurementError.invalidValue }
        try await health.addActivity(entry, date: date, id: id)
        await refreshActivity()
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
        activityRefreshID = nil
        activity = DailyHealthActivity()
        activityError = nil
        healthRefreshID = nil
        healthReadings = []
        healthError = nil
    }
}
