import Foundation
import Testing
@testable import SendaDomain

struct WeeklyMuscleTrainingTests {
    private let monday = TrainingDay(rawValue: "2026-11-09")!
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func savedSetsCountForPrimaryMusclesAndDropsAreGrouped() throws {
        var journal = Journal()
        let bench = try record(&journal, "bench", sets: 6)
        let dumbbell = try record(&journal, "dumbbell-bench", sets: 1)
        let squat = try record(&journal, "squat", sets: 2)
        let custom = try record(&journal, "custom-press", sets: 1)
        let group = UUID()
        var benchRows = bench.sets.map { TrainingRow(set: $0, unit: .pounds) }
        benchRows[0].kind = .working
        benchRows[0].reps = ""
        benchRows[0].pendingCorrection = true
        benchRows[1].kind = .warmup
        for index in 2...3 {
            benchRows[index].kind = .dropSet
            benchRows[index].dropGroupID = group
        }
        benchRows.insert(TrainingRow(unit: .pounds, kind: .dropSet, dropGroupID: group), at: 4)
        benchRows[5].kind = .regular
        benchRows.append(TrainingRow(weight: "95", reps: "", unit: .pounds, canonicalWeight: 9_500, kind: .working))
        let entries = ["bench": benchRows, "dumbbell-bench": dumbbell.sets.map { TrainingRow(set: $0, unit: .pounds) },
                       "squat": squat.sets.map { TrainingRow(set: $0, unit: .pounds) },
                       "custom-press": custom.sets.map { TrainingRow(set: $0, unit: .pounds) }]
        let workout = DayWorkout(exerciseIDs: ["bench", "dumbbell-bench", "squat", "custom-press"],
                                 selectedExerciseID: "bench", rows: entries)
        let snapshot = try JournalSnapshot(journal: journal, training: TrainingWorkspace(visibleWeek: monday,
            days: [monday.rawValue: workout])).validated()

        let result = try snapshot.weeklyMuscleTraining(days: monday.week(), through: monday, calendar: utc)
        #expect(result.counts == [.chest: 5, .quadriceps: 2, .glutes: 2])
        let chest = try #require(result.regions.first { $0.muscle == .chest })
        #expect(chest.lifts.map(\.exerciseID) == ["bench", "dumbbell-bench"])
        #expect(chest.lifts.map(\.count) == [4, 1])
    }

    @Test func savedCivilDaysWinOverLaterTimezoneAndFutureEntriesStayOut() throws {
        var journal = Journal()
        let otherWeek = try monday.adding(days: -1)
        let tomorrow = try monday.adding(days: 1)
        let bench = try record(&journal, "bench", sets: 1)
        let future = try record(&journal, "squat", on: tomorrow, sets: 1)
        _ = try record(&journal, "deadlift", on: otherWeek, sets: 1)
        let workspace = try TrainingWorkspace.migrate(JournalSnapshot(journal: journal), today: monday, calendar: utc)
        let snapshot = try JournalSnapshot(journal: journal, training: workspace).validated()
        var pacific = utc
        pacific.timeZone = TimeZone(secondsFromGMT: -8 * 3_600)!
        #expect(TrainingDay(bench.recordedAt, calendar: pacific) == otherWeek)
        #expect(TrainingDay(future.recordedAt, calendar: pacific) == monday)
        let week = try monday.week()
        #expect(snapshot.weeklyMuscleTraining(days: week + [monday], through: monday, calendar: pacific).counts == [.chest: 1])
        #expect(snapshot.weeklyMuscleTraining(days: week, through: otherWeek, calendar: pacific).regions.isEmpty)
    }

    @Test(arguments: [false, true])
    func trainingDaysAreDistinctAcrossExercises(workspaceBacked: Bool) throws {
        var journal = Journal()
        let wednesday = try monday.adding(days: 2)
        let friday = try monday.adding(days: 4)
        _ = try record(&journal, "bench", sets: 2)
        _ = try record(&journal, "dumbbell-bench", sets: 1)
        _ = try record(&journal, "bench", on: wednesday, sets: 1)
        _ = try record(&journal, "bench", on: friday, sets: 1)
        let legacy = JournalSnapshot(journal: journal)
        let workspace = workspaceBacked ? try TrainingWorkspace.migrate(legacy, today: wednesday, calendar: utc) : nil
        let snapshot = try JournalSnapshot(journal: journal, training: workspace).validated()
        let week = try monday.week()

        let firstDay = try #require(snapshot.weeklyMuscleTraining(days: week, through: monday, calendar: utc).regions.first)
        #expect(firstDay.muscle == .chest)
        #expect(firstDay.count == 3)
        #expect(firstDay.dayCount == 1)

        let midweek = try #require(snapshot.weeklyMuscleTraining(days: week, through: wednesday, calendar: utc).regions.first)
        #expect(midweek.muscle == .chest)
        #expect(midweek.count == 4)
        #expect(midweek.dayCount == 2)
    }

    @Test func unmigratedJournalUsesTheRequestedCalendarAndHasNoSetKinds() throws {
        var journal = Journal()
        _ = try record(&journal, "bench", sets: 2)
        let snapshot = JournalSnapshot(journal: journal)
        var pacific = utc
        pacific.timeZone = TimeZone(secondsFromGMT: -8 * 3_600)!
        let week = try monday.week()
        #expect(snapshot.weeklyMuscleTraining(days: week, through: monday, calendar: utc).counts == [.chest: 2])
        #expect(snapshot.weeklyMuscleTraining(days: week, through: monday, calendar: pacific).regions.isEmpty)
    }

    private func record(_ journal: inout Journal, _ exerciseID: String, on day: TrainingDay? = nil,
                        sets: Int) throws -> RecordedBatch {
        try journal.record(DraftBatch(exerciseID: exerciseID, sets: Array(
            repeating: SetValues(weight: 10_000, reps: 8), count: sets)),
            at: (day ?? monday).date(in: utc).addingTimeInterval(-10 * 3_600))
    }
}
