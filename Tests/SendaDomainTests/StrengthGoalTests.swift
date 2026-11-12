import Foundation
import Testing
@testable import SendaDomain

struct StrengthGoalTests {
    @Test func qualificationUsesSavedSetsWithEnoughRepsAndTheFirstRecordedDay() throws {
        let earlier = try TrainingDay("2026-11-02")
        let achieved = try TrainingDay("2026-11-05")
        let today = try TrainingDay("2026-11-10")
        let future = try TrainingDay("2026-11-11")
        var journal = Journal()
        let initial = try journal.record(DraftBatch(exerciseID: "bench", sets: [
            SetValues(weight: 18_000, reps: 3), SetValues(weight: 14_500, reps: 8)
        ]), at: today.date())
        let first = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 15_500, reps: 9)]), at: today.date())
        let latest = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 16_000, reps: 8)]), at: today.date())
        let later = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 20_000, reps: 10)]), at: today.date())
        var pending = TrainingRow(set: initial.sets[1], unit: .pounds)
        pending.weight = "199."
        pending.pendingCorrection = true
        let workspace = TrainingWorkspace(visibleWeek: try today.week()[0], days: [
            earlier.rawValue: DayWorkout(rows: ["bench": [TrainingRow(set: initial.sets[0], unit: .pounds), pending]], unit: .pounds),
            achieved.rawValue: DayWorkout(rows: ["bench": [TrainingRow(set: first.sets[0], unit: .pounds)]], unit: .pounds),
            today.rawValue: DayWorkout(rows: ["bench": [TrainingRow(set: latest.sets[0], unit: .pounds),
                TrainingRow(weight: "250", reps: "10", unit: .pounds)]], unit: .pounds),
            future.rawValue: DayWorkout(rows: ["bench": [TrainingRow(set: later.sets[0], unit: .pounds)]], unit: .pounds)
        ])
        let goal = StrengthGoal(exerciseID: "bench", target: SetValues(weight: 15_500, reps: 8))
        let snapshot = JournalSnapshot(journal: journal, training: workspace)
        let before = try #require(snapshot.strengthGoalProgress(for: [goal], through: earlier).first)
        #expect(before.best?.id == initial.sets[1].id)
        #expect(!before.isCompleted)
        let progress = try #require(snapshot.strengthGoalProgress(for: [goal], through: today).first)
        #expect(progress.best?.id == latest.sets[0].id)
        #expect(progress.completedDay == achieved)

        _ = try journal.updateSet(first.sets[0].id, values: SetValues(weight: 15_500, reps: 7))
        let corrected = JournalSnapshot(journal: journal, training: workspace)
        #expect(corrected.strengthGoalProgress(for: [goal], through: today).first?.completedDay == today)
    }

    @Test func bodyWeightGoalsQualifyByReps() throws {
        let day = try TrainingDay("2026-11-10")
        var journal = Journal()
        let record = try journal.record(DraftBatch(exerciseID: "pull-up", sets: [SetValues(weight: 0, reps: 10)]), at: day.date())
        let target = StrengthGoal(exerciseID: "pull-up", target: SetValues(weight: 0, reps: 8))
        let progress = try #require(JournalSnapshot(journal: journal).strengthGoalProgress(for: [target], through: day).first)
        #expect(progress.best?.id == record.sets[0].id)
        #expect(progress.isCompleted)
    }
}
