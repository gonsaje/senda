import Foundation
import Testing
@testable import SendaDomain

struct TrainingTrendsTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func day(_ value: String) -> TrainingDay { try! TrainingDay(value) }
    @discardableResult private func record(_ journal: inout Journal, on date: String,
        exercise: String = "bench", _ values: [SetValues]) throws -> RecordedBatch {
        try journal.record(DraftBatch(exerciseID: exercise, sets: values), at: day(date).date(in: utc))
    }

    @Test func emptyOverviewHasCalendarWeeksAndComparableElapsedWeek() throws {
        let result = JournalSnapshot().trends(through: day("2026-11-11"), calendar: utc)
        #expect(result.range == .threeMonths)
        #expect(result.startDay.rawValue == "2026-08-11")
        #expect(result.endDay.rawValue == "2026-11-11")
        #expect(result.weeks.count == 14)
        #expect(result.weeks.first?.endDay.rawValue == "2026-08-16")
        #expect(result.thisWeek.startDay.rawValue == "2026-11-09")
        #expect(result.thisWeek.endDay.rawValue == "2026-11-11")
        #expect(result.lastWeekComparable?.startDay.rawValue == "2026-11-02")
        #expect(result.lastWeekComparable?.endDay.rawValue == "2026-11-04")
        #expect(result.weeks.allSatisfy { $0.trainingDayCount == 0 && $0.setCount == 0 })
        #expect(result.lastWeekComparable?.setCount == 0)
        #expect(result.trainingDayCount == 0)
        #expect(result.setCount == 0)
        #expect(result.activeExerciseCount == 0)
        #expect(result.exerciseSummaries.isEmpty)
        #expect(result.recentBests.isEmpty)
    }

    @Test func uniqueTrainingDaysAcrossExercisesAndFairPartialWeek() throws {
        var journal = Journal()
        _ = try record(&journal, on: "2026-11-02", [SetValues(weight: 10_000, reps: 5)])
        _ = try record(&journal, on: "2026-11-04", exercise: "squat", [SetValues(weight: 20_000, reps: 5)])
        _ = try record(&journal, on: "2026-11-08", [SetValues(weight: 10_000, reps: 5)])
        let bench = try record(&journal, on: "2026-11-09", [SetValues(weight: 10_000, reps: 5), SetValues(weight: 10_000, reps: 6)])
        _ = try record(&journal, on: "2026-11-09", exercise: "squat", [SetValues(weight: 20_000, reps: 5)])
        _ = try record(&journal, on: "2026-11-11", exercise: "row", [SetValues(weight: 5_000, reps: 8)])
        _ = try record(&journal, on: "2026-11-12", [SetValues(weight: 90_000, reps: 9)])
        let result = JournalSnapshot(journal: journal).trends(through: day("2026-11-11"), calendar: utc)
        #expect(result.trainingDayCount == 5)
        #expect(result.setCount == 7)
        #expect(result.activeExerciseCount == 3)
        #expect(result.thisWeek.trainingDayCount == 2)
        #expect(result.thisWeek.setCount == 4)
        #expect(result.lastWeekComparable?.trainingDayCount == 2)
        #expect(result.lastWeekComparable?.setCount == 2)
        let previousWeek = try #require(result.weeks.dropLast().last)
        #expect(previousWeek.trainingDayCount == 3)
        #expect(previousWeek.setCount == 3)
        #expect(result.exerciseSummaries.map(\.exerciseID) == ["row", "bench", "squat"])
        #expect(result.exerciseSummaries.first { $0.exerciseID == "bench" }?.latestSession.bestSet.id == bench.sets[1].id)
        #expect(result.exerciseSummaries.first { $0.exerciseID == "row" }?.comparison == .insufficientHistory)
        #expect(result.recentBests.map(\.exerciseID) == ["bench"])
    }

    @Test func comparisonsUseImmediatelyPreviousDayWithoutSearchingForAMatch() throws {
        let cases: [(SetValues, SetValues, TrainingTrendComparison)] = [
            (.init(weight: 12_345, reps: 6), .init(weight: 12_345, reps: 8), .repsAtSameWeight(delta: 2, weight: 12_345)),
            (.init(weight: 12_345, reps: 8), .init(weight: 12_345, reps: 6), .repsAtSameWeight(delta: -2, weight: 12_345)),
            (.init(weight: 12_345, reps: 8), .init(weight: 12_346, reps: 8), .weightAtSameReps(delta: 1, reps: 8)),
            (.init(weight: 12_345, reps: 8), .init(weight: 12_344, reps: 8), .weightAtSameReps(delta: -1, reps: 8)),
            (.init(weight: 12_345, reps: 8), .init(weight: 12_345, reps: 8), .matched),
            (.init(weight: 12_345, reps: 8), .init(weight: 13_000, reps: 6), .differentSets)
        ]
        for (previous, latest, comparison) in cases {
            var journal = Journal()
            _ = try record(&journal, on: "2026-11-01", [latest])
            _ = try record(&journal, on: "2026-11-02", [previous])
            let batch = try record(&journal, on: "2026-11-03", [latest])
            let result = JournalSnapshot(journal: journal).trends(through: day("2026-11-09"), calendar: utc)
            let summary = try #require(result.exerciseSummaries.first)
            #expect(summary.id == "bench")
            #expect(summary.latestSession.bestSet.id == batch.sets[0].id)
            #expect(summary.previousSession?.day.rawValue == "2026-11-02")
            #expect(summary.comparison == comparison)
        }
    }

    @Test func recentBestsUseAllPriorHistoryExcludeFirstAndTiesAndKeepLatestStrictEvent() throws {
        var journal = Journal()
        let baseline = try record(&journal, on: "2026-01-01", [SetValues(weight: 12_345, reps: 8)])
        _ = try record(&journal, on: "2026-09-22", [SetValues(weight: 12_000, reps: 20)])
        let best = try record(&journal, on: "2026-11-03", [SetValues(weight: 12_346, reps: 1)])
        _ = try record(&journal, on: "2026-11-04", [SetValues(weight: 12_346, reps: 1)])
        _ = try record(&journal, on: "2026-11-05", exercise: "squat", [SetValues(weight: 50_000, reps: 5)])
        _ = try record(&journal, on: "2026-11-10", [SetValues(weight: 90_000, reps: 1)])
        let result = JournalSnapshot(journal: journal).trends(range: .oneMonth, through: day("2026-11-09"), calendar: utc)
        let event = try #require(result.recentBests.first)
        #expect(result.recentBests.count == 1)
        #expect(event.id == best.sets[0].id)
        #expect(event.setID == best.sets[0].id)
        #expect(event.exerciseID == "bench")
        #expect(event.day.rawValue == "2026-11-03")
        #expect(event.values == best.sets[0].values)
        #expect(event.previousValues == baseline.sets[0].values)
        #expect(result.exerciseSummaries.first(where: { $0.exerciseID == "bench" })?.recordDays == [day("2026-11-03")])
        #expect(result.exerciseSummaries.first(where: { $0.exerciseID == "squat" })?.recordDays.isEmpty == true)

        let latest = try record(&journal, on: "2026-11-06", [SetValues(weight: 12_346, reps: 2)])
        let next = JournalSnapshot(journal: journal).trends(through: day("2026-11-09"), calendar: utc)
        #expect(next.recentBests.count == 1)
        #expect(next.recentBests.first?.id == latest.sets[0].id)
        #expect(next.recentBests.first?.previousValues == best.sets[0].values)
        #expect(next.exerciseSummaries.first(where: { $0.exerciseID == "bench" })?.recordDays == [day("2026-11-03"), day("2026-11-06")])
    }

    @Test func sameDayBatchesProduceOneDailyTopSetAndNoFirstDayRecord() throws {
        var journal = Journal()
        _ = try record(&journal, on: "2026-11-02", [SetValues(weight: 10_000, reps: 5)])
        _ = try record(&journal, on: "2026-11-02", [SetValues(weight: 12_000, reps: 5)])
        #expect(JournalSnapshot(journal: journal).trends(through: day("2026-11-09"), calendar: utc).recentBests.isEmpty)
        _ = try record(&journal, on: "2026-11-03", [SetValues(weight: 12_001, reps: 1)])
        let final = try record(&journal, on: "2026-11-03", [SetValues(weight: 12_002, reps: 1), SetValues(weight: 12_002, reps: 1)])
        let result = JournalSnapshot(journal: journal).trends(through: day("2026-11-09"), calendar: utc)
        #expect(result.trainingDayCount == 2)
        #expect(result.recentBests.count == 1)
        #expect(result.recentBests.first?.id == final.sets[1].id)
        #expect(result.recentBests.first?.previousValues == SetValues(weight: 12_000, reps: 5))
        #expect(result.exerciseSummaries.first?.progress.setCount == 5)
    }

    @Test func savedCivilDaysUseJournalValuesIgnoreDraftsAndKeepExactSetReferences() throws {
        var journal = Journal()
        let old = try record(&journal, on: "2026-11-09", [SetValues(weight: 12_345, reps: 8)])
        let latest = try record(&journal, on: "2026-01-01", [SetValues(weight: 12_345, reps: 9)])
        let orphan = try record(&journal, on: "2026-11-09", exercise: "squat", [SetValues(weight: 90_000, reps: 9)])
        var pending = TrainingRow(set: latest.sets[0], unit: .kilograms)
        pending.weight = "999"; pending.reps = "999"; pending.weightIsDirty = true; pending.pendingCorrection = true
        let training = TrainingWorkspace(visibleWeek: day("2026-11-02"), days: [
            "2026-11-02": DayWorkout(rows: ["bench": [TrainingRow(set: old.sets[0], unit: .pounds)]]),
            "2026-11-05": DayWorkout(exerciseIDs: [], rows: ["bench": [
                TrainingRow(weight: "999", reps: "999", unit: .kilograms, weightIsDirty: true), pending]]),
            "2026-11-10": DayWorkout(rows: ["squat": [TrainingRow(set: orphan.sets[0], unit: .pounds)]])
        ])
        let snapshot = JournalSnapshot(journal: journal, training: training)
        var tokyo = utc; tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let result = snapshot.trends(through: day("2026-11-09"), calendar: tokyo)
        #expect(result == snapshot.trends(through: day("2026-11-09"), calendar: utc))
        #expect(result.trainingDayCount == 2)
        #expect(result.activeExerciseCount == 1)
        #expect(result.setCount == 2)
        #expect(result.exerciseSummaries.first?.latestSession.day.rawValue == "2026-11-05")
        #expect(result.exerciseSummaries.first?.latestSession.bestSet.position == 2)
        #expect(result.exerciseSummaries.first?.latestSession.bestSet.values == SetValues(weight: 12_345, reps: 9))
        #expect(result.recentBests.first?.id == latest.sets[0].id)
        #expect(result.recentBests.first?.previousValues == old.sets[0].values)
    }

    @Test func customUnknownAndBodyweightExercisesRemainActiveAndUseCanonicalValues() throws {
        let custom = Exercise(id: "custom-chin", name: "Chin-up", shortName: "Chin", startingWeight: 0, equipment: .bodyweight)
        var journal = Journal()
        _ = try record(&journal, on: "2026-11-02", exercise: custom.id, [SetValues(weight: 0, reps: 10)])
        let chin = try record(&journal, on: "2026-11-03", exercise: custom.id, [SetValues(weight: 0, reps: 11)])
        _ = try record(&journal, on: "2026-11-03", exercise: "retired-lift", [SetValues(weight: 123, reps: 8)])
        _ = try record(&journal, on: "2026-11-02", exercise: "push-up", [SetValues(weight: 0, reps: 20)])
        let pushup = try record(&journal, on: "2026-11-03", exercise: "push-up", [SetValues(weight: 1, reps: 2)])
        let result = JournalSnapshot(journal: journal, customExercises: [custom]).trends(through: day("2026-11-09"), calendar: utc)
        #expect(result.activeExerciseCount == 3)
        #expect(result.exerciseSummaries.map(\.exerciseID) == ["custom-chin", "push-up", "retired-lift"])
        let chinSummary = try #require(result.exerciseSummaries.first { $0.exerciseID == custom.id })
        #expect(chinSummary.progress.metric == .reps)
        #expect(chinSummary.comparison == .repsAtSameWeight(delta: 1, weight: 0))
        #expect(chinSummary.progress.bestSet?.id == chin.sets[0].id)
        #expect(result.exerciseSummaries.first { $0.exerciseID == "push-up" }?.progress.metric == .weight)
        #expect(result.exerciseSummaries.first { $0.exerciseID == "push-up" }?.comparison == .differentSets)
        #expect(result.exerciseSummaries.first { $0.exerciseID == "retired-lift" }?.progress.metric == .weight)
        #expect(result.recentBests.map(\.exerciseID) == ["custom-chin", "push-up"])
        #expect(result.recentBests.map(\.id) == [chin.sets[0].id, pushup.sets[0].id])
        let callerExercise = Exercise(id: "retired-lift", name: "Retired", shortName: "Retired", startingWeight: 0, equipment: .bodyweight)
        let supplied = JournalSnapshot(journal: journal).trends(through: day("2026-11-09"), calendar: utc, exercises: [callerExercise])
        #expect(supplied.activeExerciseCount == 3)
    }

    @Test func correctionDeletionUndoAndSnapshotRestoreRecomputeResults() throws {
        var journal = Journal()
        _ = try record(&journal, on: "2026-11-02", [SetValues(weight: 10_000, reps: 5)])
        let latest = try record(&journal, on: "2026-11-03", [SetValues(weight: 11_000, reps: 5)])
        var snapshot = JournalSnapshot(journal: journal)
        let original = snapshot.trends(through: day("2026-11-09"), calendar: utc)
        _ = try snapshot.journal.updateSet(latest.sets[0].id, values: SetValues(weight: 9_000, reps: 5))
        let corrected = snapshot.trends(through: day("2026-11-09"), calendar: utc)
        #expect(corrected.recentBests.isEmpty)
        #expect(corrected.exerciseSummaries.first?.comparison == .weightAtSameReps(delta: -1_000, reps: 5))
        let removal = try snapshot.journal.removeSet(latest.sets[0].id)
        let removed = snapshot.trends(through: day("2026-11-09"), calendar: utc)
        #expect(removed.setCount == 1)
        #expect(removed.exerciseSummaries.first?.comparison == .insufficientHistory)
        _ = try snapshot.journal.restoreSet(removal)
        #expect(snapshot.trends(through: day("2026-11-09"), calendar: utc) == corrected)
        _ = try snapshot.journal.undo(batchID: latest.id, revision: snapshot.journal.batches.first { $0.id == latest.id }!.revision)
        #expect(snapshot.trends(through: day("2026-11-09"), calendar: utc) == removed)
        snapshot = try JSONDecoder().decode(JournalSnapshot.self, from: JSONEncoder().encode(JournalSnapshot(journal: journal)))
        #expect(snapshot.trends(through: day("2026-11-09"), calendar: utc) == original)
    }

    @Test func calendarRangesIncludeExactBoundsAndMatchPerExerciseProgress() throws {
        var journal = Journal()
        for date in ["2025-11-08", "2025-11-09", "2026-05-08", "2026-05-09", "2026-08-08",
                     "2026-08-09", "2026-10-08", "2026-10-09", "2026-11-09", "2026-11-10"] {
            _ = try record(&journal, on: date, [SetValues(weight: 10_000, reps: 5)])
        }
        let snapshot = JournalSnapshot(journal: journal)
        let today = day("2026-11-09")
        let bench = try #require(Exercise.catalog.first { $0.id == "bench" })
        let cases: [(ExerciseProgressRange, String, Int)] = [
            (.oneMonth, "2026-10-09", 2),
            (.threeMonths, "2026-08-09", 4),
            (.sixMonths, "2026-05-09", 6),
            (.oneYear, "2025-11-09", 8)
        ]
        for (range, start, count) in cases {
            let trends = snapshot.trends(range: range, through: today, calendar: utc)
            let summary = try #require(trends.exerciseSummaries.first)
            #expect(trends.startDay == day(start))
            #expect(trends.endDay == today)
            #expect(trends.setCount == count)
            #expect(summary.progress.sessions.first?.day == day(start))
            #expect(summary.latestSession.day == today)
            #expect(summary.progress == snapshot.progress(for: bench, range: range, through: today, calendar: utc))
            #expect(trends.recentBests.isEmpty)
        }
    }

    @Test func olderHistoryProvidesRecordBaselineButNotAnInWindowComparison() throws {
        var journal = Journal()
        _ = try record(&journal, on: "2026-01-01", [SetValues(weight: 10_000, reps: 5)])
        let latest = try record(&journal, on: "2026-11-09", [SetValues(weight: 10_001, reps: 5)])
        let result = JournalSnapshot(journal: journal).trends(range: .oneMonth, through: day("2026-11-09"), calendar: utc)
        #expect(result.exerciseSummaries.first?.comparison == .insufficientHistory)
        #expect(result.exerciseSummaries.first?.previousSession == nil)
        #expect(result.exerciseSummaries.first?.progress.trainingDayCount == 1)
        #expect(result.recentBests.first?.id == latest.sets[0].id)
        #expect(result.recentBests.first?.previousValues == SetValues(weight: 10_000, reps: 5))
    }

    @Test func mondayWeeksSurviveDSTYearRolloverAndCalendarPreferences() throws {
        var local = Calendar(identifier: .buddhist)
        local.timeZone = TimeZone(identifier: "America/New_York")!
        local.firstWeekday = 1
        for (date, start, monday, previousEnd) in [
            ("2026-01-04", "2025-12-04", "2025-12-29", "2025-12-28"),
            ("2026-03-08", "2026-02-08", "2026-03-02", "2026-03-01"),
            ("2026-11-08", "2026-10-08", "2026-11-02", "2026-11-01")
        ] {
            let result = JournalSnapshot().trends(range: .oneMonth, through: day(date), calendar: local)
            #expect(result.startDay.rawValue == start)
            #expect(result.thisWeek.startDay.rawValue == monday)
            #expect(result.thisWeek.endDay.rawValue == date)
            #expect(result.lastWeekComparable?.endDay.rawValue == previousEnd)
        }
    }

    @Test func legacyDatesUseRequestedTimezoneAndRejectUnsupportedEraOrTimestamp() throws {
        var journal = Journal()
        let instant = Date(timeIntervalSince1970: 1_794_186_000)
        let set = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 10_000, reps: 8)]), at: instant)
        var newYork = utc; newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let snapshot = JournalSnapshot(journal: journal)
        #expect(snapshot.trends(through: day("2026-11-09"), calendar: newYork).exerciseSummaries.first?.latestSession.day.rawValue == "2026-11-08")
        #expect(snapshot.trends(through: day("2026-11-09"), calendar: utc).exerciseSummaries.first?.latestSession.bestSet.id == set.sets[0].id)
        var ancient = Journal()
        _ = try record(&ancient, on: "0001-12-30", [SetValues(weight: 100, reps: 8)])
        let bce = utc.date(from: DateComponents(era: 0, year: 1, month: 12, day: 28, hour: 12))!
        for date in [bce, Date(timeIntervalSince1970: -1e300), Date(timeIntervalSince1970: 1e300)] {
            _ = try ancient.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 90_000, reps: 9)]), at: date)
        }
        let result = JournalSnapshot(journal: ancient).trends(through: day("0001-12-31"), calendar: utc)
        #expect(result.setCount == 1)
        #expect(result.recentBests.isEmpty)
    }

    @Test func dateBoundsNeverWrapIntoFutureAndUnavailablePreviousWeekIsNil() throws {
        for date in ["0001-01-01", "0001-01-02", "0001-01-10", "9999-12-31"] {
            var journal = Journal()
            let batch = try record(&journal, on: "2026-11-09", [SetValues(weight: 100, reps: 1)])
            let training = TrainingWorkspace(visibleWeek: day("2026-11-09"), days: [
                date: DayWorkout(rows: ["bench": [TrainingRow(set: batch.sets[0], unit: .pounds)]])])
            let result = JournalSnapshot(journal: journal, training: training).trends(through: day(date), calendar: utc)
            #expect(result.startDay <= result.endDay)
            #expect(result.weeks.allSatisfy { $0.startDay <= $0.endDay && $0.endDay <= day(date) })
            #expect(result.setCount == 1)
            if date < "0001-01-08" { #expect(result.lastWeekComparable == nil) }
            if date.hasPrefix("0001") { #expect(result.startDay.rawValue == "0001-01-01") }
        }
    }
}
