import Foundation
import Testing
@testable import SendaDomain

struct NextWorkoutGuidanceTests {
    private let bench = Exercise.catalog.first { $0.id == "bench" }!
    private let plan = ExercisePlan(workingSets: 2, minimumReps: 8, maximumReps: 12)
    private var utc: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func day(_ value: String) -> TrainingDay { try! TrainingDay(value) }

    @discardableResult private func session(_ snapshot: inout JournalSnapshot, on date: String,
        reps: [Int] = [12, 12], weights: [Int]? = nil, kinds: [TrainingSetKind?]? = nil,
        effort: [Int?]? = [2, 2], savedPlan: ExercisePlan? = ExercisePlan(workingSets: 2, minimumReps: 8, maximumReps: 12)) throws -> [TrainingRow] {
        let values = reps.enumerated().map { SetValues(weight: weights?[$0.offset] ?? 12_345, reps: $0.element) }
        let batch = try snapshot.journal.record(DraftBatch(exerciseID: "bench", sets: values), at: day(date).date(in: utc))
        let rows = batch.sets.enumerated().map { index, set in
            var row = TrainingRow(set: set, unit: .pounds)
            if let kinds { row.kind = kinds[index] } else { row.kind = .working }
            row.repsInReserve = effort?[index]
            return row
        }
        snapshot.training!.days[date] = DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": rows],
            exercisePlans: savedPlan.map { ["bench": $0] })
        return rows
    }
    private func snapshot() -> JournalSnapshot {
        JournalSnapshot(training: TrainingWorkspace(visibleWeek: day("2026-11-09"), days: [
            "2026-11-09": DayWorkout(rows: ["bench": []], exercisePlans: ["bench": plan])]))
    }
    private func guidance(_ snapshot: JournalSnapshot, on date: String = "2026-11-09", through today: String = "2026-11-09") -> NextWorkoutGuidance {
        snapshot.nextWorkout(for: bench, on: day(date), through: day(today), calendar: utc)
    }

    @Test func regularAndWorkingSetsTogetherCompleteThePlan() throws {
        let regular = try #require(TrainingSetKind(rawValue: "regular"))
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-11-02", kinds: [regular, .working])
        try session(&snapshot, on: "2026-11-09", kinds: [regular, regular])
        let result = guidance(snapshot)
        #expect(result.status == .reviewLoad)
        #expect(result.workingSetCount == 2)
        #expect(result.referenceWeight == 12_345)
        #expect(result.comparableSessionCount == 2)
    }

    @Test func latestDropOnlySessionCannotBeSkippedForOlderQualifyingSessions() throws {
        let drop = try #require(TrainingSetKind(rawValue: "dropSet"))
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-10-26")
        try session(&snapshot, on: "2026-11-02")
        try session(&snapshot, on: "2026-11-09", kinds: [drop, drop])
        let result = guidance(snapshot)
        #expect(result.status == .reviewPlan)
        #expect(result.reason == .dropSets)
        #expect(result.referenceDay == day("2026-11-09"))
        #expect(result.workingSetCount == 0)
        #expect(result.referenceWeight == nil)
        #expect(result.comparableSessionCount == 0)
    }

    @Test func dropSetsDoNotCompleteThePlanOrPromptAnIncrease() throws {
        let drop = try #require(TrainingSetKind(rawValue: "dropSet"))
        for kinds in [[TrainingSetKind.working, drop], [.working, .working, drop]] {
            var snapshot = snapshot()
            try session(&snapshot, on: "2026-11-02")
            try session(&snapshot, on: "2026-11-09", reps: Array(repeating: 12, count: kinds.count),
                weights: kinds.count == 2 ? [12_345, 9_000] : [12_345, 12_345, 9_000],
                kinds: kinds, effort: Array(repeating: 2, count: kinds.count))
            let result = guidance(snapshot)
            #expect(result.status == .reviewPlan)
            #expect(result.reason == .dropSets)
            #expect(result.referenceDay == day("2026-11-09"))
            #expect(result.workingSetCount == kinds.count - 1)
            #expect(result.referenceWeight == 12_345)
            #expect(result.comparableSessionCount == 0)
        }
    }

    @Test func interveningDropOnlyOrMixedSessionBreaksConsecutiveComparison() throws {
        let drop = try #require(TrainingSetKind(rawValue: "dropSet"))
        for kinds in [[drop, drop], [.working, .working, drop]] {
            var snapshot = snapshot()
            try session(&snapshot, on: "2026-10-26")
            try session(&snapshot, on: "2026-11-02", reps: Array(repeating: 12, count: kinds.count),
                kinds: kinds, effort: Array(repeating: 2, count: kinds.count))
            try session(&snapshot, on: "2026-11-09")
            let result = guidance(snapshot)
            #expect(result.status == .repeatLoad)
            #expect(result.reason == .oneQualifyingSession)
            #expect(result.comparableSessionCount == 1)
        }
    }

    @Test func contextRequiresItsOwnPlanAndDoesNotBorrowHistoricalTargets() throws {
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-11-02")
        snapshot.training!.days["2026-11-09"]!.exercisePlans = nil
        #expect(guidance(snapshot).status == .noPlan)
        #expect(guidance(snapshot).reason == .noPlan)
        #expect(guidance(snapshot).referenceDay == nil)
    }

    @Test func plansAndDraftRowsCannotProduceRecordedHistory() throws {
        var snapshot = snapshot()
        snapshot.training!.days["2026-11-09"]!.rows["bench"] = [
            TrainingRow(weight: "999", reps: "12", unit: .pounds, weightIsDirty: true, kind: .working, repsInReserve: 5)]
        let result = guidance(snapshot)
        #expect(result.status == .noHistory)
        #expect(result.reason == .noWorkingHistory)
        #expect(result.workingSetCount == 0)
        #expect(result.referenceWeight == nil)
    }

    @Test func completedContextDayCanInformNextWorkoutWithoutChoosingAnIncrease() throws {
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-11-09")
        let result = guidance(snapshot)
        #expect(result.status == .repeatLoad)
        #expect(result.reason == .oneQualifyingSession)
        #expect(result.referenceDay == day("2026-11-09"))
        #expect(result.referenceWeight == 12_345)
        #expect(result.workingSetCount == 2)
        #expect(result.comparableSessionCount == 1)
    }

    @Test func twoConsecutiveSessionsAtSameCanonicalLoadCanPromptLoadReview() throws {
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-11-02", effort: [5, 3])
        try session(&snapshot, on: "2026-11-09", reps: [12, 13])
        let result = guidance(snapshot)
        #expect(result.status == .reviewLoad)
        #expect(result.reason == .twoQualifyingSessions)
        #expect(result.referenceWeight == 12_345)
        #expect(result.comparableSessionCount == 2)
    }

    @Test func latestUnknownClassificationBlocksOlderQualifyingSessions() throws {
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-10-26")
        try session(&snapshot, on: "2026-11-02")
        try session(&snapshot, on: "2026-11-09", kinds: [.working, nil])
        let result = guidance(snapshot)
        #expect(result.status == .needsClassification)
        #expect(result.reason == .unclassifiedSets)
        #expect(result.referenceDay == day("2026-11-09"))
        #expect(result.workingSetCount == 1)
        #expect(result.comparableSessionCount == 0)
    }

    @Test func warmupsNeverCompleteAPlanAndWarmupOnlyDaysDoNotBreakComparisons() throws {
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-10-26")
        try session(&snapshot, on: "2026-11-02", kinds: [.warmup, .warmup])
        try session(&snapshot, on: "2026-11-09", reps: [1, 12, 12], weights: [90_000, 12_345, 12_345],
                    kinds: [.warmup, .working, .working], effort: [nil, 2, 2])
        let result = guidance(snapshot)
        #expect(result.status == .reviewLoad)
        #expect(result.workingSetCount == 2)
        #expect(result.referenceWeight == 12_345)
        #expect(result.comparableSessionCount == 2)
    }

    @Test func warmupOnlyHistoryDoesNotInventAWorkingSession() throws {
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-11-02", kinds: [.warmup, .warmup])
        #expect(guidance(snapshot).status == .noHistory)
    }

    @Test func latestIncompleteOrExtraWorkingSetsCannotBeSkipped() throws {
        for (reps, status, reason) in [([12], NextWorkoutStatus.incomplete, NextWorkoutReason.incompleteWorkingSets),
                                      ([12, 12, 12], .reviewPlan, .extraWorkingSets)] {
            var snapshot = snapshot()
            try session(&snapshot, on: "2026-10-26")
            try session(&snapshot, on: "2026-11-02")
            try session(&snapshot, on: "2026-11-09", reps: reps, effort: Array(repeating: 2, count: reps.count))
            let result = guidance(snapshot)
            #expect(result.status == status)
            #expect(result.reason == reason)
            #expect(result.referenceDay == day("2026-11-09"))
            #expect(result.comparableSessionCount == 0)
        }
    }

    @Test func latestChangedOrMissingPlanRequiresReview() throws {
        for savedPlan in [nil, ExercisePlan(workingSets: 2, minimumReps: 6, maximumReps: 10)] {
            var snapshot = snapshot()
            try session(&snapshot, on: "2026-11-02", savedPlan: savedPlan)
            let result = guidance(snapshot)
            #expect(result.status == .reviewPlan)
            #expect(result.reason == .planChanged)
            #expect(result.comparableSessionCount == 0)
        }
    }

    @Test func mixedLoadsAndBelowRangeRepsRequireReview() throws {
        var mixed = snapshot()
        try session(&mixed, on: "2026-11-09", weights: [12_345, 12_346])
        #expect(guidance(mixed).status == .reviewPlan)
        #expect(guidance(mixed).reason == .mixedLoads)
        #expect(guidance(mixed).referenceWeight == nil)
        var low = snapshot()
        try session(&low, on: "2026-11-09", reps: [7, 12])
        #expect(guidance(low).status == .reviewPlan)
        #expect(guidance(low).reason == .belowRange)
    }

    @Test func missingEffortStaysUnknownAndLowReserveBlocksReadiness() throws {
        for (effort, reason) in [([2, nil], NextWorkoutReason.missingEffort), ([2, 1], .lowReserve), ([0, 2], .lowReserve)] {
            var snapshot = snapshot()
            try session(&snapshot, on: "2026-11-02")
            try session(&snapshot, on: "2026-11-09", effort: effort)
            #expect(guidance(snapshot).status == .repeatLoad)
            #expect(guidance(snapshot).reason == reason)
        }
    }

    @Test func reportedReserveAllowsBuildingRepsWithinTheSavedRange() throws {
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-11-09", reps: [8, 11], effort: [2, 5])
        #expect(guidance(snapshot).status == .buildReps)
        #expect(guidance(snapshot).reason == .moreReps)
    }

    @Test func interveningUnfavorableSessionsAndDifferentLoadsBlockTwoSessionReadiness() throws {
        for (reps, weight, effort, savedPlan) in [
            ([12, 12], 12_346, [2, 2] as [Int?], plan),
            ([11, 12], 12_345, [2, 2], plan),
            ([12, 12], 12_345, [nil, 2], plan),
            ([12, 12], 12_345, [2, 2], ExercisePlan(workingSets: 2, minimumReps: 6, maximumReps: 10))
        ] {
            var snapshot = snapshot()
            try session(&snapshot, on: "2026-10-26")
            try session(&snapshot, on: "2026-11-02", reps: reps, weights: [weight, weight], effort: effort, savedPlan: savedPlan)
            try session(&snapshot, on: "2026-11-09")
            #expect(guidance(snapshot).status == .repeatLoad)
            #expect(guidance(snapshot).reason == .oneQualifyingSession)
        }
    }

    @Test func savedCivilDaysIgnoreTimestampsTimezoneAndUnfinishedCorrections() throws {
        var snapshot = snapshot()
        let rows = try session(&snapshot, on: "2026-11-09")
        let workout = snapshot.training!.days.removeValue(forKey: "2026-11-09")!
        snapshot.training!.days["2026-11-02"] = workout
        snapshot.training!.days["2026-11-09"] = DayWorkout(rows: ["bench": []], exercisePlans: ["bench": plan])
        snapshot.training!.days["2026-11-02"]!.rows["bench"]![0].weight = "999"
        snapshot.training!.days["2026-11-02"]!.rows["bench"]![0].reps = "1"
        snapshot.training!.days["2026-11-02"]!.rows["bench"]![0].weightIsDirty = true
        snapshot.training!.days["2026-11-02"]!.rows["bench"]![0].pendingCorrection = true
        var tokyo = utc; tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let result = guidance(snapshot)
        #expect(result.referenceDay == day("2026-11-02"))
        #expect(result.referenceWeight == 12_345)
        #expect(result.reason == .oneQualifyingSession)
        #expect(result == snapshot.nextWorkout(for: bench, on: day("2026-11-09"), through: day("2026-11-09"), calendar: tokyo))
        _ = try snapshot.journal.updateSet(rows[0].performedSetID!, values: SetValues(weight: 12_345, reps: 7))
        #expect(guidance(snapshot).reason == .belowRange)
        let removal = try snapshot.journal.removeSet(rows[0].performedSetID!)
        #expect(guidance(snapshot).status == .incomplete)
        _ = try snapshot.journal.restoreSet(removal)
        #expect(guidance(snapshot).reason == .belowRange)
    }

    @Test func observationsAreBoundedByBothContextDayAndToday() throws {
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-11-02")
        try session(&snapshot, on: "2026-11-09", reps: [7, 7])
        try session(&snapshot, on: "2026-11-10", reps: [7, 7])
        let earlierContext = guidance(snapshot, on: "2026-11-02")
        #expect(earlierContext.referenceDay == day("2026-11-02"))
        #expect(earlierContext.reason == .oneQualifyingSession)
        let futureContext = guidance(snapshot, on: "2026-11-10", through: "2026-11-02")
        #expect(futureContext.referenceDay == day("2026-11-02"))
        #expect(futureContext.reason == .oneQualifyingSession)
    }

    @Test func duplicateLinksAndWrongExerciseReferencesCannotCreateWorkingSets() throws {
        var snapshot = snapshot()
        let rows = try session(&snapshot, on: "2026-11-09", reps: [12], effort: [2])
        snapshot.training!.days["2026-11-09"]!.rows["bench"]!.append(rows[0])
        let other = try snapshot.journal.record(DraftBatch(exerciseID: "squat", sets: [SetValues(weight: 12_345, reps: 12)]), at: Date())
        var wrong = TrainingRow(set: other.sets[0], unit: .pounds); wrong.kind = .working; wrong.repsInReserve = 2
        snapshot.training!.days["2026-11-09"]!.rows["bench"]!.append(wrong)
        #expect(guidance(snapshot).workingSetCount == 1)
        #expect(guidance(snapshot).status == .incomplete)
    }

    @Test func bodyweightZeroIsAnObservedCommonLoadAndUnitsDoNotChangeProjection() throws {
        var snapshot = snapshot()
        try session(&snapshot, on: "2026-11-02", weights: [0, 0])
        try session(&snapshot, on: "2026-11-09", weights: [0, 0])
        let result = guidance(snapshot)
        #expect(result.referenceWeight == 0)
        #expect(result.status == .reviewLoad)
        var workout = snapshot.training!.days["2026-11-09"]!
        for index in workout.rows["bench"]!.indices {
            let changed = workout.rows["bench"]![index].changeUnit(to: .kilograms)
            #expect(changed)
        }
        workout.unit = .kilograms
        snapshot.training!.days["2026-11-09"] = workout
        #expect(guidance(snapshot) == result)
    }
}
