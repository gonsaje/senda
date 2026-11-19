import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct WorkoutTemplateWorkflowTests {
    private let today = TrainingDay(rawValue: "2026-11-16")!
    private let plan = ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12)

    @Test func browsingEarlierWorkoutsFromWeekMakesNoDayAndReuseRetriesAsOneWrite() throws {
        let store = FailingWorkoutStore()
        let model = try open(store)
        let prior = try today.adding(days: -2)
        try #require(model.openDay(prior) && model.addExercise("push-up"))
        try #require(model.setPlan(plan, for: "push-up"))
        try #require(model.selectInput(try #require(model.rows.first).id, field: .reps))
        model.typeInput("8", focus: try #require(model.focus))
        try #require(model.showWeek())
        let before = model.snapshot

        #expect(model.reusableWorkouts(before: today).map(\.day) == [prior])
        #expect(model.reusableWorkouts(before: prior).isEmpty)
        #expect(model.snapshot == before && model.selectedDay == nil)
        #expect(model.workspace.days[today.rawValue] == nil)
        store.rejectsWrites = true
        #expect(!model.reuseWorkout(from: prior, on: today))
        #expect(model.canRetrySave && model.snapshot == before)
        store.rejectsWrites = false
        try #require(model.retrySave())

        #expect(model.selectedDay == today && model.tabs.map(\.id) == ["push-up"])
        #expect(model.plan(for: "push-up") == plan && model.summary(for: today).setCount == 0)
        let row = try #require(model.rows.first)
        #expect(row.performedSetID == nil && row.weight.isEmpty && row.reps.isEmpty)
        #expect(model.workspace.days[prior.rawValue] == before.training?.days[prior.rawValue])
        #expect(model.journal == before.journal)
    }

    @Test func applyingAStarterFromWeekMergesIntoTheExplicitDay() throws {
        let model = try open(MemoryJournalRepository())
        let tomorrow = try today.adding(days: 1)
        try #require(model.openDay(tomorrow) && model.addExercise("bench"))
        try #require(model.selectInput(try #require(model.rows.first).id, field: .weight))
        model.typeInput("31.", focus: try #require(model.focus))
        try #require(model.showWeek())
        let rows = model.workspace.days[tomorrow.rawValue]?.rows["bench"]
        let push = try #require(model.starterWorkouts.first { $0.id == "push" })

        try #require(model.applyWorkout(push, on: tomorrow))

        #expect(model.selectedDay == tomorrow)
        #expect(model.tabs.map(\.id) == ["bench", "overhead-press", "lateral-raise", "triceps-extension"])
        #expect(model.workout?.rows["bench"] == rows)
        #expect(model.workspace.days[today.rawValue] == nil)
        #expect(model.journal.batches.isEmpty)
    }

    @Test func importedCustomIDKeepsItsHistoryAndGoalWhenAStarterAddsTheConflictingPreset() throws {
        let personal = Exercise(id: "goblet-squat", name: "Box practice", shortName: "Box", startingWeight: 0,
                                muscleGroup: .core, equipment: .bodyweight)
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: personal.id, sets: [.init(weight: 0, reps: 7)]),
                                       at: today.date())
        struct PreviousJournal: Encodable {
            let version = 3
            let journal: Journal
            let customExercises: [Exercise]
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("senda-old-library-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONEncoder().encode(PreviousJournal(journal: journal, customExercises: [personal])).write(to: url)
        let store = FileJournalRepository(url: url)
        let profile = ProfileDetails(goals: [StrengthGoal(exerciseID: personal.id, target: .init(weight: 0, reps: 7))])
        let profileStore = MemoryProfileRepository()
        try profileStore.save(profile)
        let date = today.date()
        let model = try TrainingNotebookModel(repository: store, now: { date },
                                              profileRepository: profileStore)
        #expect(model.exercise(personal.id).name == "Box practice")
        let preset = try #require(model.exercises.first { $0.name == "Goblet squat" })
        #expect(preset.id != personal.id)
        #expect(model.snapshot.weeklyMuscleTraining(days: [today], through: today).regions.isEmpty)
        try #require(model.openToday())
        let starter = try #require(WorkoutTemplate.catalog.first { $0.id == "dumbbell-basics" })
        try #require(model.applyWorkout(starter))
        #expect(model.tabs.contains { $0.id == preset.id })
        #expect(model.plan(for: preset.id) != nil)
        #expect(model.plan(for: personal.id) == nil)
        let reopened = try TrainingNotebookModel(repository: FileJournalRepository(url: url), now: { date },
                                                profileRepository: profileStore)
        #expect(reopened.exercise(personal.id).name == "Box practice")
        #expect(reopened.exercise(preset.id).name == "Goblet squat")
        let archive = try NotebookBackupCodec.decode(NotebookBackupCodec.encode(reopened.backupArchive()))
        #expect(archive.snapshot.journal.entries(for: personal.id) == [batch])
        #expect(archive.snapshot.journal.entries(for: preset.id).isEmpty)
        #expect(archive.snapshot.strengthGoalProgress(for: archive.profile.goals, through: today).first?.isCompleted == true)
        let csv = String(decoding: try NotebookBackupCodec.csv(snapshot: archive.snapshot), as: UTF8.self)
        #expect(csv.contains("Box practice,goblet-squat"))
    }

    @Test func templateAppendsMissingExercisesAndUsesOnlyItsOwnPlans() throws {
        let model = try open(MemoryJournalRepository())
        let prior = try today.adding(days: -1)
        try #require(model.openDay(prior) && model.addExercise("push-up"))
        try #require(model.setPlan(plan, for: "push-up"))
        try #require(model.selectInput(try #require(model.rows.first).id, field: .reps))
        model.typeInput("12", focus: try #require(model.focus))
        try #require(model.finishEditing())

        try #require(model.openToday() && model.addExercise("row") && model.changeUnit(.kilograms))
        try #require(model.setPlan(plan, for: "row"))
        try #require(model.deleteSet(try #require(model.rows.first).id) && model.removeExercise("row"))
        try #require(model.addExercise("bench"))
        try #require(model.selectInput(try #require(model.rows.first).id, field: .weight))
        model.typeInput("031.", focus: try #require(model.focus))
        let before = model.snapshot
        let workout = WorkoutTemplate(name: "Lifting day", exerciseIDs: ["squat", "row", "bench", "push-up"],
            exercisePlans: ["squat": plan, "bench": plan,
                "row": ExercisePlan(workingSets: 4, minimumReps: 5, maximumReps: 8)])

        try #require(model.applyWorkout(workout))

        #expect(model.tabs.map(\.id) == ["bench", "squat", "row", "push-up"])
        #expect(model.exercise?.id == "squat")
        #expect(model.plan(for: "squat") == plan)
        #expect(model.plan(for: "row") == plan)
        #expect(model.plan(for: "bench") == nil)
        #expect(model.plan(for: "push-up") == nil)
        #expect(model.workout?.rows["bench"] == before.training?.days[today.rawValue]?.rows["bench"])
        #expect(model.workout?.rows["row"] == [])
        let rows = try #require(model.workout?.rows)
        for id in ["squat", "push-up"] {
            let created = try #require(rows[id])
            #expect(created.count == 1)
            let row = try #require(created.first)
            #expect(row.kind == .working && row.unit == .kilograms)
            #expect(row.weight.isEmpty && row.reps.isEmpty && row.performedSetID == nil)
            #expect(row.repsInReserve == nil && row.dropGroupID == nil)
        }
        #expect(model.journal == before.journal)
        #expect(model.workspace.days[prior.rawValue] == before.training?.days[prior.rawValue])
        #expect(model.summary(for: today).setCount == 0)
    }

    @Test func applyingVisibleExercisesKeepsSelectionAndUndo() throws {
        let model = try open(MemoryJournalRepository())
        try #require(model.openToday() && model.addExercises(["bench", "squat"]))
        try #require(model.selectExercise("squat"))
        try #require(model.deleteSet(try #require(model.rows.first).id))
        let before = model.snapshot
        let workout = WorkoutTemplate(name: "Both lifts", exerciseIDs: ["bench", "squat"],
            exercisePlans: ["squat": plan])

        #expect(model.applyWorkout(workout))
        #expect(model.snapshot == before)
        #expect(model.undoChange())
    }

    @Test func workoutEditsSurviveReopeningAndLeaveFocusedInputIntact() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("senda-workouts-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileJournalRepository(url: url)
        let model = try open(store)
        try #require(model.openToday() && model.addExercise("bench"))
        try #require(model.selectInput(try #require(model.rows.first).id, field: .weight))
        model.typeInput("31.", focus: try #require(model.focus))
        let before = model.snapshot
        let workout = WorkoutTemplate(name: "Pressing", exerciseIDs: ["bench"], exercisePlans: ["bench": plan])
        let edited = WorkoutTemplate(id: workout.id, name: "Pressing and legs", exerciseIDs: ["bench", "squat"])

        try #require(model.saveWorkout(workout))
        #expect(try open(FileJournalRepository(url: url)).savedWorkouts == [workout])
        try #require(model.saveWorkout(edited))
        #expect(try open(FileJournalRepository(url: url)).savedWorkouts == [edited])
        #expect(model.workspace.days == before.training?.days && model.focus == before.training?.focus)
        #expect(model.journal == before.journal)

        try #require(model.deleteWorkout(id: workout.id))
        #expect(try open(FileJournalRepository(url: url)).savedWorkouts.isEmpty)
        #expect(model.snapshot == before)
    }

    @Test func failedTemplateSaveKeepsExistingListUntilRetry() throws {
        let store = FailingWorkoutStore()
        let model = try open(store)
        let workout = WorkoutTemplate(name: "Pressing", exerciseIDs: ["bench"])
        let before = model.snapshot

        store.rejectsWrites = true
        #expect(!model.saveWorkout(workout))
        #expect(model.snapshot == before && model.canRetrySave)
        #expect(try open(store).savedWorkouts.isEmpty)

        store.rejectsWrites = false
        try #require(model.retrySave())
        #expect(model.savedWorkouts == [workout])
        #expect(try open(store).savedWorkouts == [workout])
        #expect(model.workspace.days == before.training?.days)
    }

    @Test func failedApplyRetriesExercisesAndPlansAsOneWrite() throws {
        let store = FailingWorkoutStore()
        let model = try open(store)
        try #require(model.openToday() && model.addExercise("row"))
        let before = model.snapshot
        let workout = WorkoutTemplate(name: "Pressing", exerciseIDs: ["bench", "push-up"],
            exercisePlans: ["bench": plan])

        store.rejectsWrites = true
        #expect(!model.applyWorkout(workout))
        #expect(model.snapshot == before && model.canRetrySave)
        #expect(try store.loadSnapshot() == before)
        store.rejectsWrites = false

        try #require(model.retrySave())
        #expect(model.tabs.map(\.id) == ["row", "bench", "push-up"])
        #expect(model.plan(for: "bench") == plan)
        #expect(model.journal == before.journal)
        let saved = model.snapshot
        #expect(model.applyWorkout(workout) && model.snapshot == saved)
        #expect(try open(store).snapshot == saved)
    }

    private func open(_ repository: any JournalRepository) throws -> TrainingNotebookModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return try TrainingNotebookModel(repository: repository, calendar: calendar,
            now: { today.date(in: calendar) })
    }
}

@MainActor private final class FailingWorkoutStore: JournalRepository {
    private var snapshot = JournalSnapshot()
    var rejectsWrites = false

    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ value: JournalSnapshot) throws {
        if rejectsWrites { throw CocoaError(.fileWriteUnknown) }
        snapshot = try value.validated()
    }
}
