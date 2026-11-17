import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct SampleWorkoutSeedingTests {
    private let today = TrainingDay(rawValue: "2026-11-18")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    @Test func sampleWorkoutsStayWithinThePreviousThirtyLocalDaysAndDoNotDuplicate() throws {
        let store = SampleWorkoutStore()
        let model = try model(using: store)
        let added = try #require(model.addSampleWorkouts())
        let days = try model.workspace.days.keys.map { try TrainingDay($0) }.sorted()
        #expect(added == days.count)
        #expect(days.first == (try today.adding(days: -30)))
        #expect(days.last == (try today.adding(days: -2)))
        for day in days {
            let weekday = calendar.component(.weekday, from: day.date(in: calendar))
            #expect([2, 4, 6].contains(weekday))
            #expect(model.summary(for: day).setCount > 0)
        }
        let seeded = model.snapshot
        #expect(store.writeCount == 1)
        #expect(try self.model(using: store).snapshot == seeded)
        #expect(model.addSampleWorkouts() == 0)
        #expect(store.writeCount == 1)
        #expect(model.snapshot == seeded)
    }

    @Test func existingWorkoutsAndDraftsStayIntactAndEmptyVisitedDaysCanBeFilled() throws {
        let recordedDay = try TrainingDay("2026-10-19")
        let undoDay = try TrainingDay("2026-11-02")
        let draftDay = try TrainingDay("2026-11-04")
        let planDay = try TrainingDay("2026-10-26")
        let visitedDay = try TrainingDay("2026-11-09")
        let values = SetValues(weight: 12_000, reps: 10)
        var journal = Journal()
        let recorded = try journal.record(DraftBatch(exerciseID: "bench", sets: [values]), at: recordedDay.date(in: calendar))
        let draft = TrainingRow(weight: "031.25", reps: "8", unit: .pounds, weightIsDirty: true, kind: .working)
        let focus = TrainingFocus(day: draftDay, exerciseID: "squat", rowID: draft.id, field: .weight)
        let undo = TrainingUndo.deleted(day: undoDay, exerciseID: "row", index: 0,
                                        row: TrainingRow(unit: .pounds), removal: nil)
        let originalDays: [String: DayWorkout] = [
            recordedDay.rawValue: DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench",
                rows: ["bench": [TrainingRow(set: recorded.sets[0], unit: .pounds)]]),
            draftDay.rawValue: DayWorkout(exerciseIDs: ["squat"], selectedExerciseID: "squat",
                rows: ["squat": [draft]]),
            planDay.rawValue: DayWorkout(exerciseIDs: ["deadlift"], selectedExerciseID: "deadlift",
                rows: ["deadlift": []], exercisePlans: ["deadlift": ExercisePlan(workingSets: 3, minimumReps: 6, maximumReps: 8)]),
            undoDay.rawValue: DayWorkout(rows: ["row": []]),
            visitedDay.rawValue: DayWorkout(unit: .kilograms)
        ]
        let workspace = TrainingWorkspace(visibleWeek: try draftDay.week()[0], selectedDay: draftDay,
            days: originalDays, focus: focus, undo: undo)
        let store = SampleWorkoutStore(snapshot: JournalSnapshot(journal: journal, training: workspace))
        let model = try model(using: store)

        #expect((model.addSampleWorkouts() ?? 0) > 0)
        for day in [recordedDay, draftDay, planDay, undoDay] {
            #expect(model.workspace.days[day.rawValue] == originalDays[day.rawValue])
        }
        #expect(model.workspace.undo == undo)
        #expect(model.journal.batches.prefix(journal.batches.count).elementsEqual(journal.batches))
        #expect(model.summary(for: visitedDay).setCount > 0)
        #expect(model.workspace.days[visitedDay.rawValue]?.unit == .kilograms)
        #expect(model.selectedDay == draftDay && model.focus == focus && model.workspace.visibleWeek == workspace.visibleWeek)
    }

    @Test func failedInsertionKeepsTheNotebookIntactAndCanRetryOnce() throws {
        let store = SampleWorkoutStore()
        let model = try model(using: store)
        let before = model.snapshot
        store.reject = true
        #expect(model.addSampleWorkouts() == nil)
        #expect(model.canRetrySave && model.snapshot == before)
        #expect(store.writeCount == 1)
        #expect(model.addSampleWorkouts() == nil)
        #expect(store.writeCount == 1)

        store.reject = false
        #expect(model.retrySave())
        #expect(!model.canRetrySave && !model.journal.batches.isEmpty)
        #expect(model.addSampleWorkouts() == 0 && store.writeCount == 2)
    }

    private func model(using store: SampleWorkoutStore) throws -> TrainingNotebookModel {
        try TrainingNotebookModel(repository: store, calendar: calendar, now: {
            today.date(in: calendar).addingTimeInterval(11 * 60 * 60)
        })
    }
}

@MainActor private final class SampleWorkoutStore: JournalRepository {
    private var snapshot: JournalSnapshot
    private(set) var writeCount = 0
    var reject = false
    init(snapshot: JournalSnapshot = JournalSnapshot()) { self.snapshot = snapshot }

    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ value: JournalSnapshot) throws {
        writeCount += 1
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try value.validated()
    }
}
