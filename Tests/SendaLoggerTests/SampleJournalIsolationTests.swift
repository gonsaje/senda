import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct SampleJournalIsolationTests {
    @Test func demoEditsAndBackupsNeverChangeTheOriginalJournalOrItsExistingSamples() throws {
        let journal = try SampleJournal.makeWeek()
        let repository = MemoryJournalRepository(journal: journal)
        let profile = MemoryProfileRepository()
        let health = DemoHealthProbe()
        let session = TrainingSession(repository: repository, profileRepository: profile, health: health)
        let real = try #require(session.notebook)
        #expect(real.profile.saveName("My journal"))
        try real.bodyMeasurements.add([.weight: 75], on: .now)
        #expect(real.setTrackedStrengthExercises(["deadlift"]))
        let original = try real.backupArchive()
        let stored = try repository.loadSnapshot()
        let previousCopy = try real.previousBackupData()

        try session.openDemo()
        defer { session.closeDemo() }
        let demo = try #require(session.demo)
        let sample = try #require(demo.session.notebook)
        #expect(sample.isSample && !sample.journal.batches.isEmpty && !sample.bodyMeasurements.supportsAppleHealth)
        #expect(sample.trackedStrengthExerciseIDs.isEmpty && !sample.bodyMeasurements.hasReadings(for: .weight))
        #expect(sample.profile.saveName("Sample changes") && sample.setTrackedStrengthExercises(["bench"]))
        try sample.bodyMeasurements.add([.waist: 80], on: .now)
        #expect(sample.openToday() && sample.addExercise("squat"))
        session.suspend()
        #expect(sample.restoreBackup(try sample.backupArchive()))
        #expect(try sample.previousBackupData() != nil)
        demo.preferences.set(true, forKey: "senda.bodyMeasurements.readAppleHealth")
        try session.openDemo()
        #expect(session.demo?.session === demo.session)
        session.closeDemo()

        #expect(session.demo == nil && session.notebook === real)
        #expect(real.snapshot == original.snapshot && real.profile.details == original.profile)
        #expect(try real.backupArchive().manualMeasurements == original.manualMeasurements)
        #expect(try repository.loadSnapshot() == stored)
        #expect(try real.previousBackupData() == previousCopy)
        #expect(real.journal == journal && real.bodyMeasurements.supportsAppleHealth)
        #expect(health.calls == 0)

        try session.openDemo()
        let fresh = try #require(session.demo)
        #expect(fresh.session !== demo.session && fresh.session.notebook?.profile.details.name != "Sample changes")
        #expect(fresh.session.notebook?.trackedStrengthExerciseIDs == [])
        #expect(fresh.session.notebook?.bodyMeasurements.hasReadings(for: .waist) == false)
        #expect(fresh.preferences.object(forKey: "senda.bodyMeasurements.readAppleHealth") == nil)
    }
}

@MainActor private final class DemoHealthProbe: BodyMeasurementsHealthSource {
    var calls = 0
    func requestAccess() async throws { calls += 1 }
    func activity(on day: Date) async throws -> DailyHealthActivity {
        calls += 1
        return DailyHealthActivity()
    }
    func addActivity(_ activity: DailyHealthActivity, date: Date, id: UUID) async throws { calls += 1 }
    func requestMeasurementSharing() async throws -> Set<BodyMetric> {
        calls += 1
        return []
    }
    func write(_ change: MeasurementSharing.Change, reading: BodyMeasurement?) async throws { calls += 1 }
    func read() async throws -> [BodyMeasurement] { calls += 1; return [] }
}
