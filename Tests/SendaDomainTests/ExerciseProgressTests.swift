import Foundation
import Testing
@testable import SendaDomain

struct ExerciseProgressTests {
    private let bench = Exercise.catalog.first { $0.id == "bench" }!
    private let pushup = Exercise.catalog.first { $0.id == "push-up" }!
    private var utc: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func day(_ value: String) -> TrainingDay { try! TrainingDay(value) }
    @Test func allRecordedDaysStayAvailableOutsideRecentChartWindows() throws {
        var journal = Journal()
        let old = try record(&journal, on: "2025-10-05", [SetValues(weight: 10_000, reps: 8)])
        let recent = try record(&journal, on: "2026-11-09", [SetValues(weight: 13_500, reps: 10)])
        let future = try record(&journal, on: "2026-12-01", [SetValues(weight: 15_000, reps: 5)])
        _ = try record(&journal, on: "2026-01-06", exercise: "squat", [SetValues(weight: 20_000, reps: 5)])
        let snapshot = JournalSnapshot(journal: journal)
        let sessions = snapshot.recordedSessions(for: bench, calendar: utc)
        #expect(sessions.map(\.day.rawValue) == ["2025-10-05", "2026-11-09", "2026-12-01"])
        #expect(sessions.flatMap(\.sets).map(\.id) == [old.sets[0].id, recent.sets[0].id, future.sets[0].id])
        for range in ExerciseProgressRange.allCases {
            let chart = snapshot.progress(for: bench, range: range, through: day("2026-11-09"), calendar: utc)
            #expect(chart.sessions.map(\.day.rawValue) == ["2026-11-09"])
            #expect(chart.setCount == 1)
        }
    }

    @Test func allRecordedDaysUseSavedCivilDatesAndLastValidValues() throws {
        var journal = Journal()
        let batch = try record(&journal, on: "2026-11-09", [SetValues(weight: 12_345, reps: 8), SetValues(weight: 10_000, reps: 10)])
        let group = UUID()
        var first = TrainingRow(set: batch.sets[0], unit: .kilograms)
        first.kind = .dropSet; first.dropGroupID = group; first.weight = "999."; first.pendingCorrection = true
        var second = TrainingRow(set: batch.sets[1], unit: .kilograms)
        second.kind = .dropSet; second.dropGroupID = group
        let training = TrainingWorkspace(visibleWeek: day("2026-01-05"), days: [
            "2026-01-05": DayWorkout(rows: ["bench": [first, second, TrainingRow(weight: "99.", reps: "8", unit: .kilograms)]], unit: .kilograms)
        ])
        var tokyo = utc; tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let snapshot = JournalSnapshot(journal: journal, training: training)
        let sessions = snapshot.recordedSessions(for: bench, calendar: tokyo)
        let session = try #require(sessions.first)
        #expect(session.day == day("2026-01-05") && session.setCount == 1)
        #expect(session.sets.map(\.id) == batch.sets.map(\.id))
        #expect(session.sets.map(\.values) == batch.sets.map(\.values))
        #expect(sessions == snapshot.recordedSessions(for: bench, calendar: utc))
    }
    @discardableResult private func record(_ journal: inout Journal, on value: String,
                                           exercise: String = "bench", _ sets: [SetValues]) throws -> RecordedBatch {
        try journal.record(DraftBatch(exerciseID: exercise, sets: sets), at: day(value).date(in: utc))
    }

    @Test func emptyHistoryContainsRealWeekBoundsWithoutStrengthObservations() throws {
        let result = JournalSnapshot().progress(for: bench, through: day("2026-11-09"), calendar: utc)
        #expect(result.exerciseID == "bench")
        #expect(result.range == .threeMonths)
        #expect(result.startDay.rawValue == "2026-08-09")
        #expect(result.endDay.rawValue == "2026-11-09")
        #expect(result.weeks.count == 15)
        #expect(result.weeks.first?.endDay.rawValue == "2026-08-09")
        #expect(result.weeks.last?.startDay.rawValue == "2026-11-09")
        #expect(result.weeks.last?.endDay.rawValue == "2026-11-09")
        #expect(result.weeks.allSatisfy { $0.trainingDayCount == 0 && $0.setCount == 0 })
        #expect(result.metric == .weight)
        #expect(result.sessions.isEmpty)
        #expect(result.setCount == 0)
        #expect(result.trainingDayCount == 0)
        #expect(result.latestSession == nil)
        #expect(result.bestSet == nil)
    }

    @Test func rangesIncludeTheirExactStartAndTodayButExcludeOlderAndFutureSets() throws {
        var journal = Journal()
        _ = try record(&journal, on: "2026-08-08", [SetValues(weight: 99_000, reps: 1)])
        let first = try record(&journal, on: "2026-08-09", [SetValues(weight: 10_000, reps: 5)])
        _ = try record(&journal, on: "2026-10-08", [SetValues(weight: 11_000, reps: 5)])
        let monthFirst = try record(&journal, on: "2026-10-09", [SetValues(weight: 12_000, reps: 5)])
        let latest = try record(&journal, on: "2026-11-09", [SetValues(weight: 13_000, reps: 5)])
        _ = try record(&journal, on: "2026-11-10", [SetValues(weight: 99_000, reps: 10)])
        let snapshot = JournalSnapshot(journal: journal)
        let threeMonths = snapshot.progress(for: bench, through: day("2026-11-09"), calendar: utc)
        let oneMonth = snapshot.progress(for: bench, range: .oneMonth, through: day("2026-11-09"), calendar: utc)
        #expect(threeMonths.sessions.map(\.day.rawValue) == ["2026-08-09", "2026-10-08", "2026-10-09", "2026-11-09"])
        #expect(threeMonths.sessions.first?.sets.first?.id == first.sets[0].id)
        #expect(threeMonths.setCount == 4)
        #expect(threeMonths.trainingDayCount == 4)
        #expect(oneMonth.startDay.rawValue == "2026-10-09")
        #expect(oneMonth.weeks.map(\.startDay.rawValue) == ["2026-10-09", "2026-10-12", "2026-10-19", "2026-10-26", "2026-11-02", "2026-11-09"])
        #expect(oneMonth.weeks.first?.endDay.rawValue == "2026-10-11")
        #expect(oneMonth.sessions.map(\.day.rawValue) == ["2026-10-09", "2026-11-09"])
        #expect(oneMonth.sessions.first?.sets.first?.id == monthFirst.sets[0].id)
        #expect(oneMonth.latestSession?.day.rawValue == "2026-11-09")
        #expect(oneMonth.bestSet?.id == latest.sets[0].id)
        #expect(oneMonth.weeks.first?.setCount == 1)
        #expect(oneMonth.weeks.last?.trainingDayCount == 1)
        #expect(oneMonth.weeks.dropFirst().dropLast().allSatisfy { $0.setCount == 0 && $0.trainingDayCount == 0 })
    }

    @Test func calendarRangesClampToTheLastDayOfShorterMonths() {
        let cases: [(ExerciseProgressRange, String, String)] = [
            (.oneMonth, "2024-03-31", "2024-02-29"),
            (.threeMonths, "2025-05-31", "2025-02-28"),
            (.sixMonths, "2024-08-31", "2024-02-29"),
            (.oneYear, "2024-02-29", "2023-02-28")
        ]
        for (range, end, start) in cases {
            let result = JournalSnapshot().progress(for: bench, range: range, through: day(end), calendar: utc)
            #expect(result.startDay == day(start))
            #expect(result.endDay == day(end))
            #expect(result.weeks.first?.startDay == day(start))
            #expect(result.weeks.last?.endDay == day(end))
        }
    }

    @Test func linkedDaysAndNotebookRowNumbersSurviveTimezoneChangesAndMultipleBatches() throws {
        var journal = Journal()
        let first = try record(&journal, on: "2026-11-09", [SetValues(weight: 12_345, reps: 8), SetValues(weight: 12_345, reps: 10)])
        let second = try record(&journal, on: "2026-08-01", [SetValues(weight: 12_345, reps: 10)])
        _ = try record(&journal, on: "2026-11-05", [SetValues(weight: 90_000, reps: 10)])
        var pending = TrainingRow(set: first.sets[1], unit: .kilograms)
        pending.weight = "999"; pending.reps = "999"; pending.weightIsDirty = true; pending.pendingCorrection = true
        let rows = [TrainingRow(set: second.sets[0], unit: .kilograms),
                    TrainingRow(weight: "999", reps: "999", unit: .kilograms, weightIsDirty: true),
                    pending, TrainingRow(set: first.sets[0], unit: .kilograms)]
        let training = TrainingWorkspace(visibleWeek: day("2026-11-02"), days: [
            "2026-11-05": DayWorkout(exerciseIDs: [], rows: ["bench": rows], unit: .kilograms)
        ])
        let snapshot = JournalSnapshot(journal: journal, training: training)
        var tokyo = utc; tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let result = snapshot.progress(for: bench, through: day("2026-11-05"), calendar: tokyo)
        #expect(result.trainingDayCount == 1)
        #expect(result.sessions.map(\.day.rawValue) == ["2026-11-05"])
        let session = try #require(result.sessions.first)
        #expect(session.sets.map(\.id) == [second.sets[0].id, first.sets[1].id, first.sets[0].id])
        #expect(session.sets.map(\.position) == [1, 3, 4])
        #expect(session.sets.map(\.values) == [SetValues(weight: 12_345, reps: 10), SetValues(weight: 12_345, reps: 10), SetValues(weight: 12_345, reps: 8)])
        #expect(session.sets.first?.batchID == second.id)
        #expect(session.sets.first?.recordedAt == second.recordedAt)
        #expect(result.bestSet?.id == first.sets[1].id)
        #expect(result.weeks.last?.trainingDayCount == 1)
        #expect(result.weeks.last?.setCount == 3)
        #expect(result == snapshot.progress(for: bench, through: day("2026-11-05"), calendar: utc))
    }

    @Test func legacySnapshotsUseTheRequestedTimezoneAndStableBatchOrder() throws {
        var journal = Journal()
        let date = Date(timeIntervalSince1970: 1_794_186_000) // 2026-11-09 01:00 UTC.
        let first = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 15_000, reps: 6), SetValues(weight: 15_000, reps: 8)]), at: date)
        let second = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 15_000, reps: 8)]), at: date)
        var newYork = utc; newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let snapshot = JournalSnapshot(journal: journal)
        let local = snapshot.progress(for: bench, through: day("2026-11-09"), calendar: newYork)
        let universal = snapshot.progress(for: bench, through: day("2026-11-09"), calendar: utc)
        #expect(local.sessions.map(\.day.rawValue) == ["2026-11-08"])
        #expect(universal.sessions.map(\.day.rawValue) == ["2026-11-09"])
        let session = try #require(local.sessions.first)
        #expect(session.sets.map(\.position) == [1, 2, 3])
        #expect(session.sets.map(\.id) == first.sets.map(\.id) + second.sets.map(\.id))
        #expect(session.bestSet.id == second.sets[0].id)
        #expect(local.bestSet?.id == second.sets[0].id)
    }

    @Test func bodyweightHistoryUsesRepsUntilAnIncludedAddedWeightExists() throws {
        var journal = Journal()
        let highestReps = try record(&journal, on: "2026-11-02", exercise: "push-up", [SetValues(weight: 0, reps: 20), SetValues(weight: 0, reps: 12)])
        let recent = try record(&journal, on: "2026-11-03", exercise: "push-up", [SetValues(weight: 0, reps: 15)])
        _ = try record(&journal, on: "2026-08-01", exercise: "push-up", [SetValues(weight: 10_000, reps: 1)])
        _ = try record(&journal, on: "2026-11-10", exercise: "push-up", [SetValues(weight: 10_000, reps: 1)])
        let before = JournalSnapshot(journal: journal).progress(for: pushup, through: day("2026-11-09"), calendar: utc)
        #expect(before.metric == .reps)
        #expect(before.bestSet?.id == highestReps.sets[0].id)
        #expect(before.latestSession?.bestSet.id == recent.sets[0].id)
        let loaded = try record(&journal, on: "2026-11-09", exercise: "push-up", [SetValues(weight: 1, reps: 2)])
        let after = JournalSnapshot(journal: journal).progress(for: pushup, through: day("2026-11-09"), calendar: utc)
        #expect(after.metric == .weight)
        #expect(after.bestSet?.id == loaded.sets[0].id)
        #expect(after.sessions.map { $0.bestSet.values.weight } == [0, 0, 1])
        #expect(after.setCount == 4)
    }

    @Test func weightedExercisesUseCanonicalWeightThenRepsAndLatestExactTie() throws {
        var journal = Journal()
        let heavy = try record(&journal, on: "2026-11-02", [SetValues(weight: 10_001, reps: 1), SetValues(weight: 10_000, reps: 999)])
        let higherReps = try record(&journal, on: "2026-11-03", [SetValues(weight: 10_001, reps: 2)])
        let latestTie = try record(&journal, on: "2026-11-04", [SetValues(weight: 10_001, reps: 2)])
        _ = try record(&journal, on: "2026-11-05", exercise: "squat", [SetValues(weight: 90_000, reps: 9)])
        let result = JournalSnapshot(journal: journal).progress(for: bench, through: day("2026-11-09"), calendar: utc)
        #expect(result.metric == .weight)
        #expect(result.sessions.first?.bestSet.id == heavy.sets[0].id)
        try #require(result.sessions.count == 3)
        #expect(result.sessions[1].bestSet.id == higherReps.sets[0].id)
        #expect(result.bestSet?.id == latestTie.sets[0].id)
        #expect(result.weeks.dropLast().last?.trainingDayCount == 3)
        #expect(result.weeks.dropLast().last?.setCount == 4)
        #expect(result.weeks.last?.setCount == 0)
    }

    @Test func committedCorrectionsDeletionAndUndoRecomputeExactSetReferences() throws {
        var journal = Journal()
        let batch = try record(&journal, on: "2026-11-09", [SetValues(weight: 10_000, reps: 8), SetValues(weight: 15_000, reps: 5)])
        var snapshot = JournalSnapshot(journal: journal)
        #expect(snapshot.progress(for: bench, through: day("2026-11-09"), calendar: utc).bestSet?.id == batch.sets[1].id)
        _ = try snapshot.journal.updateSet(batch.sets[0].id, values: SetValues(weight: 20_000, reps: 8))
        let corrected = snapshot.progress(for: bench, through: day("2026-11-09"), calendar: utc)
        #expect(corrected.bestSet?.id == batch.sets[0].id)
        #expect(corrected.bestSet?.values == SetValues(weight: 20_000, reps: 8))
        let removal = try snapshot.journal.removeSet(batch.sets[0].id)
        #expect(snapshot.progress(for: bench, through: day("2026-11-09"), calendar: utc).bestSet?.id == batch.sets[1].id)
        _ = try snapshot.journal.restoreSet(removal)
        #expect(snapshot.progress(for: bench, through: day("2026-11-09"), calendar: utc) == corrected)
        _ = try snapshot.journal.undo(batchID: batch.id, revision: snapshot.journal.batches[0].revision)
        let empty = snapshot.progress(for: bench, through: day("2026-11-09"), calendar: utc)
        #expect(empty.sessions.isEmpty)
        #expect(empty.bestSet == nil)
        #expect(empty.weeks.allSatisfy { $0.setCount == 0 && $0.trainingDayCount == 0 })
    }

    @Test func unknownAndCustomExercisesUseTheirOwnSavedRows() throws {
        let custom = Exercise(id: "custom-chin", name: "Chin-up", shortName: "Chin", startingWeight: 0, equipment: .bodyweight)
        let unknown = Exercise(id: "retired-lift", name: "Retired lift", shortName: "Retired", startingWeight: 0)
        var journal = Journal()
        let bodyweight = try record(&journal, on: "2026-11-02", exercise: custom.id, [SetValues(weight: 0, reps: 9)])
        let retired = try record(&journal, on: "2026-11-02", exercise: unknown.id, [SetValues(weight: 0, reps: 12)])
        let training = TrainingWorkspace(visibleWeek: day("2026-11-02"), days: ["2026-11-02": DayWorkout(rows: [
            custom.id: [TrainingRow(set: bodyweight.sets[0], unit: .pounds)],
            unknown.id: [TrainingRow(set: retired.sets[0], unit: .pounds)]
        ])])
        let snapshot = JournalSnapshot(journal: journal, customExercises: [custom], training: training)
        let customResult = snapshot.progress(for: custom, through: day("2026-11-09"), calendar: utc)
        #expect(customResult.metric == .reps)
        #expect(customResult.bestSet?.id == bodyweight.sets[0].id)
        #expect(customResult.sessions.first?.id == "2026-11-02")
        let unknownResult = snapshot.progress(for: unknown, through: day("2026-11-09"), calendar: utc)
        #expect(unknownResult.metric == .weight)
        #expect(unknownResult.bestSet?.id == retired.sets[0].id)
    }

    @Test func civilWeekBoundsIgnoreDSTCalendarFirstWeekdayAndYearRollover() throws {
        var newYork = Calendar(identifier: .buddhist)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        newYork.firstWeekday = 1
        let january = JournalSnapshot().progress(for: bench, range: .oneMonth, through: day("2026-01-04"), calendar: newYork)
        #expect(january.startDay.rawValue == "2025-12-04")
        #expect(january.weeks.last?.startDay.rawValue == "2025-12-29")
        #expect(january.weeks.last?.endDay.rawValue == "2026-01-04")
        let spring = JournalSnapshot().progress(for: bench, range: .oneMonth, through: day("2026-03-08"), calendar: newYork)
        #expect(spring.startDay.rawValue == "2026-02-08")
        #expect(spring.weeks.last?.startDay.rawValue == "2026-03-02")
        #expect(spring.weeks.last?.endDay.rawValue == "2026-03-08")
        let fall = JournalSnapshot().progress(for: bench, range: .oneMonth, through: day("2026-11-08"), calendar: newYork)
        #expect(fall.startDay.rawValue == "2026-10-08")
        #expect(fall.weeks.last?.startDay.rawValue == "2026-11-02")
        #expect(fall.weeks.last?.endDay.rawValue == "2026-11-08")
    }

    @Test func supportedDateBoundsNeverWrapAWindowIntoTheFuture() throws {
        for value in ["0001-01-02", "0001-01-10", "9999-12-31"] {
            var journal = Journal()
            let batch = try record(&journal, on: "2026-11-09", [SetValues(weight: 100, reps: 1)])
            let training = TrainingWorkspace(visibleWeek: day("2026-11-09"), days: [
                value: DayWorkout(rows: ["bench": [TrainingRow(set: batch.sets[0], unit: .pounds)]])
            ])
            let result = JournalSnapshot(journal: journal, training: training).progress(for: bench, through: day(value), calendar: utc)
            #expect(result.startDay <= result.endDay)
            #expect(result.weeks.allSatisfy { $0.startDay <= $0.endDay && $0.endDay <= day(value) })
            #expect(result.bestSet?.id == batch.sets[0].id)
            #expect(result.setCount == 1)
            if value.hasPrefix("0001") { #expect(result.startDay.rawValue == "0001-01-01") }
        }
    }

    @Test func linkedFutureAndOutOfRangeDaysAreExcludedEvenWithRecentTimestamps() throws {
        var journal = Journal()
        let today = try record(&journal, on: "2026-11-09", [SetValues(weight: 100, reps: 8)])
        let old = try record(&journal, on: "2026-11-09", [SetValues(weight: 90_000, reps: 8)])
        let future = try record(&journal, on: "2026-11-09", [SetValues(weight: 90_000, reps: 9)])
        let training = TrainingWorkspace(visibleWeek: day("2026-11-09"), days: [
            "2026-11-09": DayWorkout(rows: ["bench": [TrainingRow(set: today.sets[0], unit: .pounds)]]),
            "2026-08-08": DayWorkout(rows: ["bench": [TrainingRow(set: old.sets[0], unit: .pounds)]]),
            "2026-11-10": DayWorkout(rows: ["bench": [TrainingRow(set: future.sets[0], unit: .pounds)]])
        ])
        let result = JournalSnapshot(journal: journal, training: training).progress(for: bench, through: day("2026-11-09"), calendar: utc)
        #expect(result.setCount == 1)
        #expect(result.bestSet?.id == today.sets[0].id)
        #expect(result.sessions.map(\.day.rawValue) == ["2026-11-09"])
    }

    @Test func unsupportedLegacyDatesCannotMasqueradeAsAnIncludedCivilDay() throws {
        var journal = Journal()
        let supported = try record(&journal, on: "0001-12-30", [SetValues(weight: 100, reps: 8)])
        let bce = utc.date(from: DateComponents(era: 0, year: 1, month: 12, day: 28, hour: 12))!
        _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 90_000, reps: 9)]), at: bce)
        for interval in [-1e300, 1e300] {
            _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 90_000, reps: 9)]),
                                   at: Date(timeIntervalSince1970: interval))
        }
        let result = JournalSnapshot(journal: journal).progress(for: bench, through: day("0001-12-31"), calendar: utc)
        #expect(result.setCount == 1)
        #expect(result.bestSet?.id == supported.sets[0].id)
        #expect(result.sessions.map(\.day.rawValue) == ["0001-12-30"])
    }
}
