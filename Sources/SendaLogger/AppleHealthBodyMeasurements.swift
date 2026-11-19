#if os(iOS)
import Foundation
import HealthKit
import SendaDomain

@MainActor public final class AppleHealthBodyMeasurements: BodyMeasurementsHealthSource {
    private let store: HKHealthStore

    public init?() {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        store = HKHealthStore()
    }

    public func requestAccess() async throws {
        let types = Set<HKObjectType>(BodyMetric.allCases.map { $0.healthType })
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
                return try? BodyMeasurement(id: sample.uuid, metric: metric, value: value,
                    date: sample.startDate, source: .appleHealth(sample.sourceRevision.source.name))
            })
        }
        return readings
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
