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

    @Test func eachWorkingSetAndDropGroupCountsOncePerTrackedMuscle() throws {
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
        #expect(result.counts[.chest] == 5)
        #expect(result.counts[.triceps] == 5)
        #expect(result.counts[.frontShoulders] == 5)
        #expect(result.counts[.quadriceps] == 2)
        #expect(result.counts[.glutes] == 2)
        #expect(!result.regions.contains { $0.lifts.contains { $0.exerciseID == "custom-press" } })
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
        #expect(snapshot.weeklyMuscleTraining(days: week + [monday], through: monday, calendar: pacific).counts[.triceps] == 1)
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
        #expect(snapshot.weeklyMuscleTraining(days: week, through: monday, calendar: utc).counts[.triceps] == 2)
        #expect(snapshot.weeklyMuscleTraining(days: week, through: monday, calendar: pacific).regions.isEmpty)
    }

    @Test(arguments: [true, false])
    func historicalDeadliftCreditsBackAndLegsWithoutExtraJournalSets(workspaceBacked: Bool) throws {
        var journal = Journal()
        _ = try record(&journal, "deadlift", sets: 1)
        let legacy = JournalSnapshot(journal: journal)
        let migrated = workspaceBacked ? try TrainingWorkspace.migrate(legacy, today: monday, calendar: utc) : nil
        let snapshot = try JournalSnapshot(journal: journal, training: migrated).validated()
        let week = snapshot.weeklyMuscleTraining(days: [monday], through: monday, calendar: utc)
        for muscle in [MuscleRegion.glutes, .hamstrings, .quadriceps, .spinalErectors] {
            #expect(week.counts[muscle] == 1)
        }
        #expect(snapshot.journal.batches.flatMap(\.sets).count == 1)
    }

    @Test func stretchingAndIncompleteRowsDoNotContributeMuscleSets() throws {
        var journal = Journal()
        _ = try record(&journal, "standing-quadriceps-stretch", sets: 2)
        let legacy = JournalSnapshot(journal: journal)
        var workspace = try TrainingWorkspace.migrate(legacy, today: monday, calendar: utc)
        workspace.days[monday.rawValue]?.rows["squat"] = [TrainingRow(weight: "135", reps: "", unit: .pounds)]
        let snapshot = JournalSnapshot(journal: journal, training: workspace)
        #expect(snapshot.weeklyMuscleTraining(days: [monday], through: monday, calendar: utc).regions.isEmpty)
    }

    @Test func primaryAndSupportingCreditsStaySeparateForWeeklyTargets() throws {
        var journal = Journal()
        _ = try record(&journal, "bench", sets: 2)
        _ = try record(&journal, "triceps-extension", sets: 1)
        let snapshot = JournalSnapshot(journal: journal)
        let week = snapshot.weeklyMuscleTraining(days: [monday], through: monday, calendar: utc)
        let triceps = try #require(week.regions.first { $0.muscle == .triceps })
        #expect(triceps.count == 3 && triceps.dayCount == 1)
        #expect(triceps.primaryCount == 1 && triceps.supportingCount == 2)
        #expect(triceps.lifts.filter(\.isPrimary).map(\.exerciseID) == ["triceps-extension"])
    }

    @Test func archivedCustomExerciseKeepsItsChosenRegionsAndPrimaryCreditInHistory() throws {
        let custom = Exercise(id: "my-hinge", name: "Home hinge", shortName: "Hinge", startingWeight: 0,
            muscleGroup: .back, isArchived: true, customMuscleTags: [.spinalErectors, .glutes])
        var journal = Journal()
        _ = try record(&journal, custom.id, sets: 2)
        let snapshot = try JournalSnapshot(journal: journal, customExercises: [custom]).validated()
        let week = snapshot.weeklyMuscleTraining(days: [monday], through: monday, calendar: utc)
        let back = try #require(week.regions.first { $0.muscle == .spinalErectors })
        let glutes = try #require(week.regions.first { $0.muscle == .glutes })
        #expect(back.primaryCount == 2 && back.supportingCount == 0)
        #expect(glutes.primaryCount == 0 && glutes.supportingCount == 2)
        #expect(week.regions.count == 2)
    }

    @Test func fullBodyCustomCreditsOnlyChosenMusclesAndUntaggedLegacyCustomKeepsItsSets() throws {
        let carry = Exercise(id: "loaded-march", name: "Loaded march", shortName: "March", startingWeight: 0,
            muscleGroup: .fullBody, customMuscleTags: [.glutes, .abdominals])
        let legacy = Exercise(id: "old-carry", name: "Carry practice", shortName: "Carry", startingWeight: 0,
            muscleGroup: .fullBody)
        var journal = Journal()
        _ = try record(&journal, carry.id, sets: 1)
        _ = try record(&journal, legacy.id, sets: 1)
        let snapshot = try JournalSnapshot(journal: journal, customExercises: [carry, legacy]).validated()
        let week = snapshot.weeklyMuscleTraining(days: [monday], through: monday, calendar: utc)
        #expect(week.counts == [.glutes: 1, .abdominals: 1])
        #expect(week.regions.allSatisfy { $0.primaryCount == 1 && $0.lifts.map(\.exerciseID) == [carry.id] })
        #expect(snapshot.journal.batches.flatMap(\.sets).count == 2)
    }

    private func record(_ journal: inout Journal, _ exerciseID: String, on day: TrainingDay? = nil,
                        sets: Int) throws -> RecordedBatch {
        try journal.record(DraftBatch(exerciseID: exerciseID, sets: Array(
            repeating: SetValues(weight: 10_000, reps: 8), count: sets)),
            at: (day ?? monday).date(in: utc).addingTimeInterval(-10 * 3_600))
    }
}
