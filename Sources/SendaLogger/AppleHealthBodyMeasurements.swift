#if os(iOS)
import Foundation
import HealthKit
import SendaDomain
import SendaPersistence

@MainActor public final class AppleHealthBodyMeasurements: BodyMeasurementsHealthSource {
    private let store: HKHealthStore

    public init?() {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        store = HKHealthStore()
    }

    public func requestAccess() async throws {
        let activityTypes = [HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned)]
        let types = Set<HKObjectType>(BodyMetric.allCases.map(\.healthType) + activityTypes)
        try await store.requestAuthorization(toShare: [], read: types)
    }

    public func read() async throws -> [BodyMeasurement] {
        var readings: [BodyMeasurement] = []
        for metric in BodyMetric.allCases {
            try Task.checkCancellation()
            let query = HKSampleQueryDescriptor(predicates: [.quantitySample(type: metric.healthType)],
                                                sortDescriptors: [])
            let samples = try await query.result(for: store)
            readings.append(contentsOf: samples.compactMap { sample in
                let amount = sample.quantity.doubleValue(for: metric.healthUnit)
                // HealthKit expresses percentages as fractions (0.25 is 25%).
                let value = metric == .bodyFat ? amount * 100 : amount
                let localID = sample.sourceRevision.source == HKSource.default()
                    ? (sample.metadata?[HKMetadataKeySyncIdentifier] as? String).flatMap(UUID.init(uuidString:)) : nil
                return try? BodyMeasurement(id: localID ?? sample.uuid, metric: metric, value: value,
                    date: sample.startDate, source: .appleHealth(sample.sourceRevision.source.name))
            })
        }
        return readings
    }

    public func activity(on day: Date) async throws -> DailyHealthActivity {
        guard let interval = Calendar.current.dateInterval(of: .day, for: day) else {
            throw BodyMeasurementError.invalidValue
        }
        let steps = try await dailyTotal(.stepCount, unit: .count(), interval: interval)
        let energy = try await dailyTotal(.activeEnergyBurned, unit: .kilocalorie(), interval: interval)
        return DailyHealthActivity(steps: steps, activeCalories: energy)
    }

    // Construct and execute the descriptor together, outside the UI actor.
    nonisolated private func dailyTotal(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
                                        interval: DateInterval) async throws -> Double? {
        let bounds = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(identifier), predicate: bounds),
            options: .cumulativeSum, anchorDate: interval.start, intervalComponents: DateComponents(day: 1))
        do {
            let days = try await query.result(for: store)
            return days.statistics(for: interval.start)?.sumQuantity()?.doubleValue(for: unit)
        } catch let error as HKError where [.errorNoData, .errorAuthorizationDenied, .errorAuthorizationNotDetermined].contains(error.code) {
            return nil
        }
    }

    public func addActivity(_ activity: DailyHealthActivity, date: Date, id: UUID) async throws {
        let entries: [(HKQuantityType, HKUnit, Double?)] = [
            (HKQuantityType(.stepCount), .count(), activity.steps),
            (HKQuantityType(.activeEnergyBurned), .kilocalorie(), activity.activeCalories)
        ]
        let types = Set<HKSampleType>(entries.compactMap { $0.2 == nil ? nil : $0.0 })
        try await store.requestAuthorization(toShare: types, read: [])
        guard types.allSatisfy({ store.authorizationStatus(for: $0) == .sharingAuthorized }) else {
            throw HealthWriteError.activityAccess
        }
        let samples = entries.compactMap { type, unit, value -> HKQuantitySample? in
            guard let value else { return nil }
            return HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: value),
                start: date, end: date, metadata: [HKMetadataKeyWasUserEntered: true,
                    HKMetadataKeySyncIdentifier: "\(id.uuidString).\(type.identifier)", HKMetadataKeySyncVersion: 1])
        }
        try await store.save(samples)
    }

    public func requestMeasurementSharing() async throws -> Set<BodyMetric> {
        let types = Set<HKSampleType>(BodyMetric.allCases.map(\.healthType))
        try await store.requestAuthorization(toShare: types, read: [])
        return Set(BodyMetric.allCases.filter { store.authorizationStatus(for: $0.healthType) == .sharingAuthorized })
    }

    public func write(_ change: MeasurementSharing.Change, reading: BodyMeasurement?) async throws {
        let type = change.metric.healthType
        guard store.authorizationStatus(for: type) == .sharingAuthorized else { throw HealthWriteError.measurementAccess }
        if let reading {
            let amount = reading.metric == .bodyFat ? reading.value / 100 : reading.value
            let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: reading.metric.healthUnit, doubleValue: amount),
                start: reading.date, end: reading.date, metadata: [HKMetadataKeyWasUserEntered: true,
                    HKMetadataKeySyncIdentifier: reading.id.uuidString, HKMetadataKeySyncVersion: NSNumber(value: change.version)])
            try await store.save(sample)
        } else {
            let match = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [change.id.uuidString])
            let owned = HKQuery.predicateForObjects(from: .default())
            _ = try await store.deleteObjects(of: type, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [owned, match]))
        }
    }
}

private enum HealthWriteError: LocalizedError {
    case activityAccess, measurementAccess
    var errorDescription: String? {
        switch self {
        case .activityAccess: "Allow Senda to write the activity you entered in Apple Health."
        case .measurementAccess: "Allow Senda to write this measurement in Apple Health."
        }
    }
}

private extension BodyMetric {
    var healthType: HKQuantityType {
        switch self {
        case .weight: HKQuantityType(.bodyMass)
        case .waist: HKQuantityType(.waistCircumference)
        case .bodyFat: HKQuantityType(.bodyFatPercentage)
        }
    }

    var healthUnit: HKUnit {
        switch self {
        case .weight: .gramUnit(with: .kilo)
        case .waist: .meterUnit(with: .centi)
        case .bodyFat: .percent()
        }
    }
}
#endif
