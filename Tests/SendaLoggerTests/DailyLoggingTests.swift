import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct DailyLoggingTests {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private var day: TrainingDay { try! TrainingDay("2026-11-07") }
    private func model(_ store: any JournalRepository = MemoryJournalRepository()) throws -> TrainingNotebookModel {
        try TrainingNotebookModel(repository: store, calendar: calendar, now: { self.day.date(in: self.calendar) })
    }

    @Test func newSetReusesUntouchedBlankRowAndKeepsItBlank() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        let original = try #require(m.rows.first)
        #expect(m.newSet()); #expect(m.newSet())
        #expect(m.rows == [original])
        #expect(m.focus?.rowID == original.id && m.focus?.field == .weight)
        #expect(m.journal.batches.isEmpty)
    }

    @Test func nextWeightedSetKeepsTypingAndPreservesTheRecordedSet() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "00135", reps: "0010")
        let first = try #require(m.rows.first), setID = try #require(first.performedSetID)
        #expect(m.focus?.field == .reps && m.focus?.keyboard == true)

        #expect(m.newSet(keyboard: true))

        try #require(m.rows.count == 2)
        #expect(m.rows[0].id == first.id)
        #expect(m.rows[0].weight == "135" && m.rows[0].reps == "10")
        #expect(m.rows[0].performedSetID == setID)
        #expect(m.recordedValues(for: m.rows[0]) == SetValues(weight: 13_500, reps: 10))
        #expect(m.rows[1].weight.isEmpty && m.rows[1].reps.isEmpty && m.rows[1].kind == .working)
        #expect(m.focus?.rowID == m.rows[1].id && m.focus?.field == .weight && m.focus?.keyboard == true)
        #expect(m.summary(for: day).setCount == 1 && m.journal.batches.flatMap(\.sets).count == 1)
        let reopened = try model(store)
        #expect(reopened.rows == m.rows && reopened.focus == m.focus)
    }

    @Test func unspecifiedNewSetKeyboardKeepsWeightedDialAndBodyweightTyping() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        #expect(m.newSet(keyboard: nil))
        #expect(m.focus?.field == .weight && m.focus?.keyboard == false)
        #expect(m.addExercise("push-up"))
        #expect(m.newSet(keyboard: nil))
        #expect(m.focus?.field == .reps && m.focus?.keyboard == true)
        #expect(m.summary(for: day).setCount == 0)
    }

    @Test(arguments: [true, false]) func reusedBlankSetHonorsKeyboardPreference(keyboard: Bool) throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        let weighted = try #require(m.rows.first)
        #expect(m.newSet(keyboard: keyboard)); #expect(m.newSet(keyboard: keyboard))
        #expect(m.rows == [weighted] && m.focus?.rowID == weighted.id)
        #expect(m.focus?.field == .weight && m.focus?.keyboard == keyboard)

        #expect(m.addExercise("push-up"))
        let bodyweight = try #require(m.rows.first)
        #expect(m.newSet(keyboard: keyboard)); #expect(m.newSet(keyboard: keyboard))
        #expect(m.rows == [bodyweight] && m.focus?.rowID == bodyweight.id)
        #expect(m.focus?.field == .reps && m.focus?.keyboard == keyboard)
        #expect(m.journal.batches.isEmpty)
    }

    @Test func failedNextSetPreservesCurrentInputAndFocusUntilOneSuccessfulRetry() throws {
        let store = DailyFailureStore(), m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "00135", reps: "0010")
        let before = m.snapshot, setID = try #require(m.rows.first?.performedSetID)
        store.reject = true

        #expect(!m.newSet(keyboard: true))

        #expect(m.snapshot == before && m.canRetrySave)
        #expect(try store.loadSnapshot() == before)
        #expect(m.rows[0].weight == "00135" && m.rows[0].reps == "0010")
        #expect(m.focus?.rowID == m.rows[0].id && m.focus?.field == .reps)
        #expect(!m.retrySave() && m.snapshot == before)
        store.reject = false
        #expect(m.retrySave())

        try #require(m.rows.count == 2)
        #expect(m.rows[0].performedSetID == setID)
        #expect(m.rows[0].weight == "135" && m.rows[0].reps == "10")
        #expect(m.focus?.rowID == m.rows[1].id && m.focus?.field == .weight && m.focus?.keyboard == true)
        #expect(m.rows[1].weight.isEmpty && m.rows[1].reps.isEmpty)
        #expect(m.journal.batches.flatMap(\.sets).count == 1 && !m.canRetrySave)
        let saved = m.snapshot
        #expect(m.retrySave() && m.snapshot == saved)
        #expect(try model(store).snapshot == saved)
    }

    private func enter(_ m: TrainingNotebookModel, weight: String, reps: String) throws {
        let row = try #require(m.rows.last)
        #expect(m.selectInput(row.id, field: .weight)); m.typeInput(weight, focus: try #require(m.focus))
        #expect(m.selectInput(row.id, field: .reps)); m.typeInput(reps, focus: try #require(m.focus))
    }
    private func record(_ m: TrainingNotebookModel, exercise: String = "bench", weight: String = "135", reps: String = "10") throws {
        #expect(m.addExercise(exercise))
        if m.rows.last?.performedSetID != nil { #expect(m.newSet()) }
        try enter(m, weight: weight, reps: reps); #expect(m.finishEditing())
    }

    @Test func newSetPreservesPartialAndExplicitZeroRowsAndUsesBodyweightFocus() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        try enter(m, weight: "0", reps: "")
        let zero = m.rows[0]
        #expect(m.newSet())
        #expect(m.rows.count == 2 && m.rows[0] == zero && m.rows[1].weight.isEmpty)
        #expect(m.summary(for: day).setCount == 0)
        #expect(m.addExercise("push-up")); let row = m.rows[0]
        #expect(m.newSet()); #expect(m.rows == [row])
        #expect(m.focus?.field == .reps && m.focus?.keyboard == true)
    }

    @Test func previousReferenceUsesNearestRecordedValuesAndExcludesLaterRowsDraftsAndFutureDays() throws {
        let m = try model(), prior = try day.adding(days: -1), future = try day.adding(days: 1)
        #expect(m.openDay(prior)); try record(m, weight: "200", reps: "12")
        try record(m, weight: "90", reps: "5"); let priorLast = m.rows[1]
        #expect(m.openDay(future)); try record(m, weight: "300", reps: "1")
        #expect(m.openDay(day)); try record(m, weight: "150", reps: "8")
        let first = m.rows[0]
        try record(m, weight: "80", reps: "4"); let second = m.rows[1]
        #expect(m.selectInput(second.id, field: .weight)); m.typeInput("31.", focus: try #require(m.focus))
        #expect(m.finishEditing()); #expect(m.newSet())
        #expect(m.previousRecordedSet(before: m.rows[2].id)?.rowID == second.id)
        #expect(m.previousRecordedSet(before: m.rows[2].id)?.values == SetValues(weight: 8_000, reps: 4))
        #expect(m.previousRecordedSet(before: first.id)?.rowID == priorLast.id)
        #expect(m.previousRecordedSet(before: first.id)?.values == SetValues(weight: 9_000, reps: 5))
        #expect(m.previousRecordedSet(before: second.id)?.rowID == first.id)
        #expect(m.previousRecordedSet(before: UUID()) == nil)
    }

    @Test func prefillImmediatelySavesCanonicalWeightAndPreservesRowIdentityAndFocusAcrossReopen() throws {
        let store = MemoryJournalRepository(), m = try model(store), prior = try day.adding(days: -1)
        #expect(m.openDay(prior)); try record(m, weight: "1", reps: "7")
        #expect(m.openDay(day)); #expect(m.addExercise("bench")); #expect(m.changeUnit(.kilograms))
        let blank = m.rows[0]
        #expect(m.prefillSet(blank.id)); #expect(!m.prefillSet(blank.id))
        #expect(m.rows[0].id == blank.id && m.rows[0].actionID == blank.actionID)
        #expect(m.rows[0].weight == "0.45" && m.rows[0].reps == "7" && m.rows[0].canonicalWeight == 100)
        let savedSetID = try #require(m.rows[0].performedSetID)
        #expect(m.focus?.rowID == blank.id)
        #expect(m.recordedValues(for: m.rows[0]) == SetValues(weight: 100, reps: 7))
        #expect(m.summary(for: day).setCount == 1 && m.summary(for: prior).setCount == 1)
        let reopened = try model(store)
        #expect(reopened.rows[0] == m.rows[0] && reopened.focus?.rowID == blank.id)
        #expect(reopened.finishEditing())
        #expect(reopened.rows[0].performedSetID == savedSetID)
        #expect(reopened.recordedValues(for: reopened.rows[0]) == SetValues(weight: 100, reps: 7))
        #expect(reopened.summary(for: day).setCount == 1 && reopened.summary(for: prior).setCount == 1)
    }

    @Test func prefillKeepsBodyweightBlankAndWeightedZeroExplicit() throws {
        let m = try model(), prior = try day.adding(days: -1)
        #expect(m.openDay(prior)); try record(m, exercise: "push-up", weight: "", reps: "12")
        try record(m, weight: "0", reps: "3")
        #expect(m.openDay(day)); #expect(m.addExercise("push-up"))
        #expect(m.prefillSet(m.rows[0].id))
        #expect(m.rows[0].weight.isEmpty && m.rows[0].canonicalWeight == 0 && m.rows[0].reps == "12")
        #expect(m.focus?.field == .reps)
        #expect(m.finishEditing()); #expect(m.addExercise("bench"))
        #expect(m.prefillSet(m.rows[0].id))
        #expect(m.rows[0].weight == "0" && m.rows[0].canonicalWeight == 0 && m.rows[0].reps == "3")
        #expect(m.summary(for: day).setCount == 2)
        #expect(m.rows[0].performedSetID != nil && m.focus?.field == .weight)
    }

    @Test func prefillRefusesPartialRecordedUnknownOrHistorylessRowsWithoutChangingThem() throws {
        let m = try model()
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        #expect(!m.prefillSet(m.rows[0].id))
        try enter(m, weight: "135", reps: "10"); #expect(m.finishEditing())
        let recorded = m.rows[0]
        #expect(!m.prefillSet(recorded.id)); #expect(m.rows[0] == recorded)
        #expect(m.newSet()); try enter(m, weight: "31.", reps: "")
        let partial = m.snapshot
        #expect(!m.prefillSet(m.rows[1].id)); #expect(!m.prefillSet(UUID()))
        #expect(m.snapshot == partial)
    }

    @Test func recentExercisesUsesRecordedHistoryUniqueNewestOrderAndHonorsLimit() throws {
        let m = try model(), prior = try day.adding(days: -1)
        #expect(m.openDay(prior)); try record(m, exercise: "squat")
        #expect(m.createExercise(named: "Custom press", group: .shoulders, equipment: .dumbbell))
        let customID = try #require(m.exercise?.id)
        try enter(m, weight: "10", reps: "4"); #expect(m.finishEditing())
        #expect(m.openDay(day)); try record(m, exercise: "bench")
        try record(m, exercise: "squat"); #expect(m.removeExercise("squat"))
        #expect(m.addExercise("deadlift")); try enter(m, weight: "31.", reps: "5")
        #expect(m.recentExercises().map(\.id) == ["squat", "bench", customID])
        #expect(m.recentExercises(limit: 2).map(\.id) == ["squat", "bench"])
        #expect(m.recentExercises(limit: 0).isEmpty && m.recentExercises(limit: -1).isEmpty)
    }

    @Test func bulkAddIsOrderedUniqueAndPreservesExistingDraftsAndRows() throws {
        let store = MemoryJournalRepository(), m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench")); try enter(m, weight: "31.", reps: "8")
        #expect(m.finishEditing()); let existing = m.rows
        #expect(m.addExercises(["squat", "bench", "deadlift", "squat"]))
        #expect(m.tabs.map(\.id) == ["bench", "squat", "deadlift"] && m.exercise?.id == "squat")
        #expect(m.workout?.rows["bench"] == existing && m.summary(for: day).setCount == 0)
        #expect(m.workout?.rows["squat"]?.count == 1 && m.rows[0].weight.isEmpty)
        let snapshot = m.snapshot
        #expect(m.addExercises(["squat", "bench", "deadlift"]))
        #expect(m.snapshot == snapshot)
        #expect(!m.addExercises(["row", "missing-exercise"]))
        #expect(m.snapshot == snapshot && !m.tabs.contains { $0.id == "row" })
        #expect(try model(store).snapshot == snapshot)
    }

    @Test func failedBulkAddIsAtomicAcrossContinuedFailuresAndRetry() throws {
        let store = DailyFailureStore(), m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench")); try enter(m, weight: "135", reps: "10")
        let before = m.snapshot
        store.reject = true
        #expect(!m.addExercises(["deadlift", "squat", "deadlift"]))
        #expect(m.snapshot == before && m.canRetrySave)
        #expect(!m.retrySave()); #expect(m.snapshot == before)
        store.reject = false
        #expect(m.retrySave()); #expect(m.retrySave())
        #expect(m.tabs.map(\.id) == ["bench", "deadlift", "squat"] && m.exercise?.id == "deadlift")
        #expect(m.summary(for: day).setCount == 1 && m.journal.batches.count == 1)
        #expect(try model(store).snapshot == m.snapshot)
    }

    @Test func indexIncludesHiddenRecordedAndMeaningfulDraftsButNotHiddenBlankRows() throws {
        let m = try model()
        #expect(m.openDay(day)); try record(m)
        #expect(m.removeExercise("bench"))
        #expect(m.addExercise("squat")); try enter(m, weight: "0", reps: ""); #expect(m.removeExercise("squat"))
        #expect(m.addExercise("deadlift")); #expect(m.removeExercise("deadlift"))
        #expect(m.addExercise("row"))
        #expect(m.indexedExercises(on: day).map(\.id) == ["row", "bench", "squat"])
        let retained = try #require(m.workout?.rows["bench"])
        #expect(m.addExercise("bench")); #expect(m.rows == retained)
        #expect(m.summary(for: day).setCount == 1)
    }

    @Test func reusableWorkoutsAreStrictlyEarlierRecordedDaysWithInclusiveStructureOrder() throws {
        let m = try model(), prior = try day.adding(days: -1), older = try day.adding(days: -3), future = try day.adding(days: 1)
        #expect(m.openDay(older)); try record(m, exercise: "squat")
        #expect(m.openDay(prior)); try record(m, exercise: "bench"); #expect(m.removeExercise("bench"))
        #expect(m.addExercise("deadlift")); try enter(m, weight: "31.", reps: ""); #expect(m.removeExercise("deadlift"))
        #expect(m.addExercise("row"))
        #expect(m.openDay(future)); try record(m, exercise: "push-up", weight: "", reps: "12")
        #expect(m.openDay(day)); try record(m)
        #expect(m.reusableWorkouts.map(\.day) == [prior, older])
        let first = try #require(m.reusableWorkouts.first)
        #expect(first.exerciseIDs == ["row", "bench", "deadlift"])
        #expect(first.recordedSetCount == 1 && first.id == prior)
        #expect(!m.reuseWorkout(from: day) && !m.reuseWorkout(from: future))
    }

    @Test func reuseAppendsOnlyMissingTabsWithFreshBlankIdentitiesAndKeepsSourceAndDestinationRows() throws {
        let store = MemoryJournalRepository(), m = try model(store), prior = try day.adding(days: -1)
        #expect(m.openDay(prior)); try record(m, exercise: "squat")
        try record(m); #expect(m.removeExercise("bench")); #expect(m.addExercise("row"))
        let source = try #require(m.workout)
        #expect(m.openDay(day)); #expect(m.addExercise("bench")); try enter(m, weight: "31.", reps: "8")
        #expect(m.finishEditing()); let existing = m.rows
        #expect(m.reuseWorkout(from: prior))
        #expect(m.tabs.map(\.id) == ["bench", "squat", "row"] && m.exercise?.id == "squat")
        #expect(m.workout?.rows["bench"] == existing)
        #expect(m.rows.count == 1 && m.rows[0].weight.isEmpty && m.rows[0].reps.isEmpty && m.rows[0].performedSetID == nil)
        #expect(!source.rows.values.flatMap { $0 }.contains { $0.id == m.rows[0].id || $0.actionID == m.rows[0].actionID })
        #expect(m.workspace.days[prior.rawValue] == source && m.summary(for: day).setCount == 0)
        let snapshot = m.snapshot
        #expect(m.reuseWorkout(from: prior)); #expect(m.snapshot == snapshot)
        #expect(try model(store).snapshot == snapshot)
    }

    @Test func reuseRestoresHiddenDestinationRowsAndFinalizesOnlyItsExistingCompleteEdit() throws {
        let m = try model(), prior = try day.adding(days: -1)
        #expect(m.openDay(prior)); try record(m, exercise: "squat"); try record(m)
        let source = m.workout
        #expect(m.openDay(day)); try record(m, exercise: "squat", weight: "95", reps: "8")
        let retained = m.rows; #expect(m.removeExercise("squat"))
        #expect(m.addExercise("row")); try enter(m, weight: "50", reps: "6")
        #expect(m.reuseWorkout(from: prior))
        #expect(m.tabs.map(\.id) == ["row", "squat", "bench"] && m.exercise?.id == "squat")
        #expect(m.rows == retained && m.summary(for: day).setCount == 2)
        #expect(m.workout?.rows["bench"]?.allSatisfy { $0.performedSetID == nil } == true)
        #expect(m.workspace.days[prior.rawValue] == source)
    }

    @Test func reuseFailureKeepsBothDaysUnchangedAndBackgroundRetryAppliesOnce() throws {
        let store = DailyFailureStore(), m = try model(store), prior = try day.adding(days: -1)
        #expect(m.openDay(prior)); try record(m, exercise: "squat"); try record(m)
        #expect(m.openDay(day)); let before = m.snapshot
        store.reject = true
        #expect(!m.reuseWorkout(from: prior)); #expect(!m.flushRecovery())
        #expect(m.snapshot == before)
        store.reject = false
        #expect(m.flushRecovery()); let applied = m.snapshot
        #expect(m.flushRecovery() && m.reuseWorkout(from: prior)); #expect(m.snapshot == applied)
        #expect(m.tabs.map(\.id) == ["squat", "bench"] && m.summary(for: day).setCount == 0)
        #expect(m.workspace.days[prior.rawValue] == before.training?.days[prior.rawValue])
        #expect(try model(store).snapshot == applied)
    }

    @Test func cancelFailedBulkAndReuseCannotReappearOnLaterRecovery() throws {
        let store = DailyFailureStore(), m = try model(store), prior = try day.adding(days: -1)
        #expect(m.openDay(prior)); try record(m, exercise: "squat")
        #expect(m.openDay(day)); #expect(m.addExercise("bench")); let before = m.snapshot
        store.reject = true
        #expect(!m.addExercises(["deadlift", "row"]))
        #expect(m.cancelPendingAction()); #expect(!m.canRetrySave)
        #expect(!m.reuseWorkout(from: prior)); #expect(m.cancelPendingAction())
        store.reject = false
        #expect(m.flushRecovery()); #expect(m.snapshot == before)
        #expect(try model(store).tabs.map(\.id) == ["bench"])
    }

    @Test func cancelDuringContinuedFailureRetainsOnlyCurrentUnsavedInputRecovery() throws {
        let store = DailyFailureStore(), m = try model(store)
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        #expect(m.selectInput(m.rows[0].id, field: .weight))
        store.reject = true; m.typeInput("31.", focus: try #require(m.focus))
        let visible = m.snapshot
        #expect(!m.addExercises(["squat", "deadlift"]))
        #expect(!m.cancelPendingAction() && m.canRetrySave)
        #expect(!m.flushRecovery() && m.snapshot == visible)
        store.reject = false
        #expect(m.flushRecovery()); #expect(m.snapshot == visible)
        #expect(m.tabs.map(\.id) == ["bench"] && m.rows[0].weight == "31." && m.journal.batches.isEmpty)
        #expect(try model(store).snapshot == visible)
    }

    @Test func newerIntentSupersedesFailedBulkAndReuseEvenIfNewSaveAlsoFails() throws {
        let store = DailyFailureStore(), m = try model(store), prior = try day.adding(days: -1)
        #expect(m.openDay(prior)); try record(m, exercise: "squat")
        #expect(m.openDay(day)); #expect(m.addExercise("bench"))
        store.reject = true
        #expect(!m.reuseWorkout(from: prior)); #expect(!m.addExercises(["row", "deadlift"]))
        store.reject = false
        #expect(m.retrySave())
        #expect(m.tabs.map(\.id) == ["bench", "row", "deadlift"])
        #expect(!m.tabs.contains { $0.id == "squat" })
    }

    @Test func customAndLegacyRecordedExercisesRemainRecentIndexedAndReusable() throws {
        var journal = Journal()
        let prior = try day.adding(days: -1)
        _ = try journal.record(DraftBatch(exerciseID: "legacy-lift", sets: [SetValues(weight: 100, reps: 8)]), at: prior.date(in: calendar))
        let store = try MemoryJournalRepository(snapshot: JournalSnapshot(journal: journal)), m = try model(store)
        #expect(m.openDay(prior)); #expect(m.removeExercise("legacy-lift"))
        #expect(m.createExercise(named: "Custom pull", group: .back, equipment: .cable))
        let customID = try #require(m.exercise?.id)
        try enter(m, weight: "20", reps: "8"); #expect(m.finishEditing()); #expect(m.removeExercise(customID))
        #expect(m.openDay(day)); #expect(m.reuseWorkout(from: prior))
        #expect(Set(m.tabs.map(\.id)) == Set(["legacy-lift", customID]))
        #expect(m.recentExercises().map(\.id) == [customID, "legacy-lift"])
        #expect(m.indexedExercises(on: prior).map(\.id) == [customID, "legacy-lift"])
        #expect(m.summary(for: day).setCount == 0)
        #expect(try model(store).tabs.map(\.id) == m.tabs.map(\.id))
    }

    @Test func reusedStructureAndImmediatelyRecordedPrefillPersistThroughActualFileReopen() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FileJournalRepository(url: folder.appendingPathComponent("journal.json"))
        let m = try model(store), prior = try day.adding(days: -1)
        #expect(m.openDay(prior)); try record(m, weight: "1", reps: "7")
        let source = m.workout
        #expect(m.openDay(day)); try #require(m.reuseWorkout(from: prior)); #expect(m.changeUnit(.kilograms))
        #expect(m.prefillSet(m.rows[0].id))
        let reopened = try model(FileJournalRepository(url: folder.appendingPathComponent("journal.json")))
        #expect(reopened.rows[0].canonicalWeight == 100 && reopened.rows[0].weight == "0.45")
        #expect(reopened.rows[0].performedSetID != nil && reopened.summary(for: day).setCount == 1)
        #expect(reopened.focus?.rowID == reopened.rows[0].id)
        #expect(reopened.recordedValues(for: reopened.rows[0]) == SetValues(weight: 100, reps: 7))
        #expect(reopened.workspace.days[prior.rawValue] == source)
        #expect(reopened.finishEditing()); #expect(reopened.summary(for: day).setCount == 1)
        #expect(reopened.recordedValues(for: reopened.rows[0]) == SetValues(weight: 100, reps: 7))
    }
}

@MainActor private final class DailyFailureStore: JournalRepository {
    var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ candidate: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try candidate.validated()
    }
}
