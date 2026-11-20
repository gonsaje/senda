import Foundation
import SendaDomain
import SendaLogger
import SendaPersistence
import Testing

@MainActor
struct BodyMeasurementsTests {
    private let today = Date(timeIntervalSince1970: 1_794_996_000)

    @Test func periodKeepsOnlyTheMostRecentPriorWeightOutOfHistory() throws {
        let model = BodyMeasurementsModel(repository: InMemoryBodyRepository())
        let calendar = Calendar.current
        let start = try TrainingDay("2026-11-10")
        let end = try start.adding(days: 5)
        let prior = try start.adding(days: -1)
        try model.add([.weight: 72], on: try prior.adding(days: -1).date(in: calendar))
        try model.add([.weight: 74, .waist: 87], on: prior.date(in: calendar))
        try model.add([.weight: 75], on: end.date(in: calendar))
        try model.add([.weight: 80], on: try end.adding(days: 1).date(in: calendar))
        let window = model.period(for: .weight, in: start...end, calendar: calendar)
        #expect(window.readings.map(\.value) == [75])
        #expect(window.precedingWeight?.value == 74)
        #expect(model.period(for: .waist, in: start...end, calendar: calendar).precedingWeight == nil)
        let before = try prior.adding(days: -5)
        let empty = model.period(for: .weight, in: before...before, calendar: calendar)
        #expect(empty.readings.isEmpty && empty.precedingWeight == nil)
    }

    @Test func parsesMeasurementsAndConvertsBetweenEntryUnits() throws {
        let weight = try #require(BodyMetric.weight.canonicalValue(from: "180.25", unit: .pounds))
        let waist = try #require(BodyMetric.waist.canonicalValue(from: "32,5", unit: .pounds))
        let fat = try #require(BodyMetric.bodyFat.canonicalValue(from: "23.4", unit: .kilograms))
        #expect(abs(weight - 81.7600246925) < 0.0001)
        #expect(abs(waist - 82.55) < 0.0001)
        #expect(fat == 23.4)
        #expect(abs(BodyMetric.weight.displayValue(weight, unit: .pounds) - 180.25) < 0.0001)
        #expect(BodyMetric.waist.displayValue(waist, unit: .kilograms) == waist)
        #expect(BodyMetric.bodyFat.canonicalValue(from: "100.01", unit: .pounds) == nil)
        #expect(BodyMetric.waist.canonicalValue(from: "0", unit: .pounds) == nil)
        #expect(BodyMetric.weight.canonicalValue(from: "170lb", unit: .pounds) == nil)
        #expect(BodyMetric.weight.canonicalValue(from: "1e2", unit: .pounds) == nil)
    }

    @Test func acceptsDecimalDigitsAndSeparatorFromAnArabicKeyboard() {
        #expect(BodyMetric.bodyFat.canonicalValue(from: "٢٣٫٤", unit: .kilograms) == 23.4)
        #expect(BodyMetric.weight.canonicalValue(from: "٨٠٫٢٥", unit: .kilograms) == 80.25)
        #expect(BodyMetric.weight.canonicalValue(from: "٨٠٬٢٥", unit: .kilograms) == nil)
        #expect(BodyMetric.bodyFat.canonicalValue(from: "٢٣٫٤٥٦", unit: .kilograms) == nil)
    }

    @Test func manualCalendarDayStaysStableAfterTravel() throws {
        var origin = Calendar(identifier: .gregorian)
        origin.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        var destination = origin
        destination.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let selected = try #require(origin.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 1)))
        let manual = try BodyMeasurement(metric: .weight, value: 80, date: selected, calendar: origin)
        let imported = try BodyMeasurement(metric: .weight, value: 80, date: selected, source: .appleHealth("Health"))
        #expect(TrainingDay(manual.displayDate(in: destination), calendar: destination).rawValue == "2026-11-18")
        #expect(TrainingDay(imported.displayDate(in: destination), calendar: destination).rawValue == "2026-11-17")
    }

    @Test func intervalUsesManualCivilDaysAndLocalHealthTimestampsAcrossDST() async throws {
        var origin = Calendar(identifier: .gregorian)
        origin.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        var destination = Calendar(identifier: .gregorian)
        destination.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let instant = try #require(origin.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1)))
        let day = try TrainingDay("2026-03-08")
        let late = try #require(destination.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23, minute: 59)))
        let tomorrow = try #require(destination.date(from: DateComponents(year: 2026, month: 3, day: 9)))
        let manual = try BodyMeasurement(metric: .weight, value: 72, date: instant, calendar: origin)
        let previousInLA = try BodyMeasurement(metric: .weight, value: 74, date: instant, source: .appleHealth("Health"))
        let endOfDay = try BodyMeasurement(metric: .weight, value: 73, date: late, source: .appleHealth("Health"))
        let nextDay = try BodyMeasurement(metric: .weight, value: 75, date: tomorrow, source: .appleHealth("Health"))
        let repository = InMemoryBodyRepository(), health = FixtureHealth()
        repository.readings = [manual]
        health.readings = [previousInLA, nextDay, endOfDay]
        let model = BodyMeasurementsModel(repository: repository, health: health)
        await model.refreshHealth()

        #expect(model.readings(for: .weight, in: day...day, calendar: destination) == [endOfDay, manual])
        #expect(model.readings(for: .weight, calendar: destination).count == 4)
        #expect(model.hasHealthReadings(for: .weight) && !model.hasHealthReadings(for: .waist))
    }

    @Test func intervalIncludesEveryReadingInStableOrderEvenWhenThereAreMoreThanThirty() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let end = try TrainingDay("2024-03-31")
        let interval = ExerciseProgressRange.oneMonth.days(through: end)
        let start = try TrainingDay("2024-02-29")
        let repository = InMemoryBodyRepository()
        let observations = try (0..<35).map { index in
            try BodyMeasurement(metric: .waist, value: Double(70 + index), date: start.date(in: calendar), calendar: calendar)
        }
        let last = try BodyMeasurement(metric: .waist, value: 91, date: end.date(in: calendar), calendar: calendar)
        let excluded = try [start.adding(days: -1), end.adding(days: 1)].map { day in
            try BodyMeasurement(metric: .waist, value: 90, date: day.date(in: calendar), calendar: calendar)
        }
        repository.readings = excluded + [last] + observations.reversed()
        let model = BodyMeasurementsModel(repository: repository)

        #expect(interval == start...end)
        #expect(model.readings(for: .waist, in: interval, calendar: calendar) ==
                    [last] + observations.sorted { $0.id.uuidString < $1.id.uuidString })
        #expect(model.readings(for: .weight, in: interval, calendar: calendar).isEmpty)
    }

    @Test func manualReadingsPersistAndCanBeEditedOrDeleted() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("BodyMeasurements/measurements.json")
        let model = BodyMeasurementsModel(repository: FileBodyMeasurementsRepository(url: url))
        try model.add([.weight: 80.25, .waist: 81.75, .bodyFat: 24.1], on: today)
        let reopened = BodyMeasurementsModel(repository: FileBodyMeasurementsRepository(url: url))
        let weight = try #require(reopened.readings(for: .weight).first)
        #expect(weight.value == 80.25)
        #expect(weight.source == .manual)
        #expect(reopened.readings(for: .waist).first?.value == 81.75)
        #expect(reopened.readings(for: .bodyFat).first?.value == 24.1)

        let yesterday = today.addingTimeInterval(-86_400)
        try reopened.update(weight, value: 82, on: yesterday)
        #expect(reopened.readings(for: .weight).first?.id == weight.id)
        #expect(reopened.readings(for: .weight).first?.date == yesterday)
        try reopened.remove(weight)
        let final = BodyMeasurementsModel(repository: FileBodyMeasurementsRepository(url: url))
        #expect(final.readings(for: .weight).isEmpty)
        #expect(final.readings(for: .waist).count == 1)
    }

    @Test func invalidOrFailedSaveDoesNotPublishPartialMeasurements() throws {
        let repo = InMemoryBodyRepository()
        let model = BodyMeasurementsModel(repository: repo)
        #expect(throws: BodyMeasurementError.self) {
            try model.add([.weight: 80, .bodyFat: 102], on: today)
        }
        #expect(model.readings(for: .weight).isEmpty)
        repo.fail = true
        #expect(throws: CocoaError.self) {
            try model.add([.weight: 80, .waist: 92], on: today)
        }
        #expect(model.readings(for: .waist).isEmpty)
        repo.fail = false
        try model.add([.weight: 80, .waist: 92], on: today)
        #expect(model.readings(for: .weight).count == 1)
    }

    @Test func unreadableManualFileStaysUntouched() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("unreadable.json")
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: url)
        let model = BodyMeasurementsModel(repository: FileBodyMeasurementsRepository(url: url))
        #expect(model.manualLoadFailed)
        #expect(throws: BodyMeasurementError.self) { try model.add([.weight: 80], on: today) }
        #expect(try Data(contentsOf: url) == corrupt)
    }

    @Test func healthHistoryMergesByMetricAndNeverWritesToManualStorage() async throws {
        let repo = InMemoryBodyRepository()
        let health = FixtureHealth()
        let model = BodyMeasurementsModel(repository: repo, health: health)
        let old = try BodyMeasurement(metric: .weight, value: 72, date: today.addingTimeInterval(-86_400),
                                      source: .appleHealth("RENPHO Health"))
        let fat = try BodyMeasurement(metric: .bodyFat, value: 22.5, date: today,
                                      source: .appleHealth("RENPHO Health"))
        health.readings = [old, old, fat]
        try model.add([.weight: 73], on: today)
        #expect(await model.requestHealthAccess())
        await model.refreshHealth()
        #expect(model.readings(for: .weight).map(\.value) == [73, 72])
        #expect(model.readings(for: .bodyFat) == [fat])
        #expect(repo.readings.map(\.source) == [.manual])
        #expect(throws: BodyMeasurementError.self) { try model.remove(old) }

        health.readings = []
        await model.refreshHealth()
        #expect(model.readings(for: .weight).map(\.value) == [73])
        #expect(model.readings(for: .bodyFat).isEmpty)
        health.readings = [old]
        await model.refreshHealth()
        model.disconnectHealth()
        #expect(model.readings(for: .weight).map(\.source) == [.manual])
    }

    @Test func disconnectedRefreshCannotPublishStaleResults() async throws {
        let health = FixtureHealth()
        let model = BodyMeasurementsModel(repository: InMemoryBodyRepository(), health: health)
        health.readings = [try BodyMeasurement(metric: .waist, value: 82, date: today, source: .appleHealth("RENPHO"))]
        health.pause = true
        let refresh = Task { await model.refreshHealth() }
        while health.pausedRead == nil { await Task.yield() }
        model.disconnectHealth()
        health.pausedRead?.resume()
        await refresh.value
        #expect(model.readings(for: .waist).isEmpty)
    }
}

@MainActor
private final class InMemoryBodyRepository: BodyMeasurementsRepository {
    var readings: [BodyMeasurement] = []
    var fail = false
    func load() throws -> [BodyMeasurement] { readings }
    func save(_ readings: [BodyMeasurement]) throws {
        if fail { throw CocoaError(.fileWriteOutOfSpace) }
        self.readings = readings
    }
}

@MainActor
private final class FixtureHealth: BodyMeasurementsHealthSource {
    var readings: [BodyMeasurement] = []
    var pause = false
    var pausedRead: CheckedContinuation<Void, Never>?
    func requestAccess() async throws {}
    func read() async throws -> [BodyMeasurement] {
        if pause { await withCheckedContinuation { pausedRead = $0 } }
        return readings
    }
}
