import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct DropSetWorkflowTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private var today: TrainingDay { try! TrainingDay("2026-11-09") }
    private func model(_ repository: (any JournalRepository)? = nil) throws -> TrainingNotebookModel {
        try TrainingNotebookModel(repository: repository ?? MemoryJournalRepository(), calendar: calendar,
                                  now: { today.date(in: calendar) })
    }
    private func enter(_ model: TrainingNotebookModel, rowID: UUID? = nil, weight: String = "135", reps: String = "10") throws {
        let rowID = try rowID ?? #require(model.rows.last?.id)
        #expect(model.selectInput(rowID, field: .weight))
        model.typeInput(weight, focus: try #require(model.focus))
        #expect(model.selectInput(rowID, field: .reps))
        model.typeInput(reps, focus: try #require(model.focus))
    }
    private func twoStages(_ store: (any JournalRepository)? = nil) throws -> TrainingNotebookModel {
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model); #expect(model.finishEditing())
        #expect(model.setKind(.dropSet, for: try #require(model.rows.first?.id)))
        #expect(model.addDropStage(to: try #require(model.rows.first?.id)))
        try enter(model, weight: "110", reps: "8"); #expect(model.finishEditing())
        return model
    }
    private func sharedBatchSnapshot(grouped: Bool = true, unit: WeightUnit = .pounds,
                                     day: TrainingDay? = nil, values: [SetValues]? = nil) throws -> JournalSnapshot {
        let day = day ?? today
        let values = values ?? [SetValues(weight: 13_500, reps: 10), SetValues(weight: 11_000, reps: 8), SetValues(weight: 9_500, reps: 6)]
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: values), at: day.date(in: calendar))
        let group = UUID()
        let rows = batch.sets.enumerated().map { index, set -> TrainingRow in
            var row = TrainingRow(set: set, unit: unit)
            row.kind = index < 2 ? .dropSet : .working
            row.dropGroupID = grouped && index < 2 ? group : nil
            return row
        }
        return JournalSnapshot(journal: journal, training: TrainingWorkspace(visibleWeek: try day.week()[0], selectedDay: day,
            days: [day.rawValue: DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": rows], unit: unit)]))
    }

    @Test func choosingDropPersistsAnExplicitGroupWithoutChangingThePerformedSet() throws {
        let model = try model()
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model); #expect(model.finishEditing())
        let before = try #require(model.rows.first), journal = model.journal
        #expect(model.setKind(.dropSet, for: before.id))
        let row = try #require(model.rows.first)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
        #expect(encoded["dropGroupID"] as? String != nil)
        #expect(row.performedSetID == before.performedSetID && model.journal == journal)
    }

    @Test func stagesAutosaveIndependentlyAndDoubleAddReusesTheBlankStage() throws {
        let store = MemoryJournalRepository()
        let model = try model(store)
        #expect(model.openToday()); #expect(model.addExercise("bench"))
        try enter(model); #expect(model.finishEditing())
        let first = try #require(model.rows.first)
        #expect(model.setKind(.dropSet, for: first.id))
        #expect(model.addDropStage(to: first.id))
        let second = try #require(model.rows.last)
        #expect(model.addDropStage(to: first.id))
        #expect(model.rows.count == 2 && model.focus?.rowID == second.id && model.focus?.field == .weight)
        try enter(model, weight: "110", reps: "8")
        #expect(model.rows.map(\.dropGroupID) == [model.rows[0].dropGroupID, model.rows[0].dropGroupID])
        #expect(model.rows[0].dropGroupID != nil && model.setEntries.count == 1)
        #expect(model.recordedValues(for: model.rows[0]) == SetValues(weight: 13_500, reps: 10))
        #expect(model.recordedValues(for: model.rows[1]) == SetValues(weight: 11_000, reps: 8))
        #expect(model.rows[0].performedSetID == first.performedSetID && model.rows[1].performedSetID != first.performedSetID)
        #expect(model.summary(for: today).setCount == 1 && model.loggedSetCount(for: "bench", on: today) == 1)
        #expect(model.setPosition(for: first.id)?.setIndex == 1)
        #expect(model.setPosition(for: second.id)?.stageIndex == 2 && model.setPosition(for: second.id)?.stageCount == 2)
        #expect(model.setPosition(for: second.id)?.isDropSet == true)
        let reopened = try self.model(store)
        #expect(reopened.rows == model.rows && reopened.focus == model.focus)
        #expect(reopened.journal == model.journal && reopened.canRepeat)
    }

    @Test func partialStageAndFailedNumericWritesPreserveLastValidValuesAndRetry() throws {
        let store = DropFailureRepository()
        let model = try twoStages(store)
        let second = try #require(model.rows.last)
        #expect(model.selectInput(second.id, field: .weight))
        let focus = try #require(model.focus), journal = model.journal
        store.reject = true
        model.typeInput("31.", focus: focus)
        #expect(model.rows.last?.weight == "31." && model.canRetrySave)
        #expect(model.recordedValues(for: try #require(model.rows.last)) == SetValues(weight: 11_000, reps: 8))
        #expect(model.journal == journal && model.unfinishedSetCount(for: today) == 1 && !model.canRepeat)
        #expect(model.summary(for: today).setCount == 1)
        store.reject = false
        #expect(model.retrySave())
        let reopened = try self.model(store)
        #expect(reopened.rows == model.rows && reopened.focus == focus && reopened.journal == journal)
        model.typeInput("100", focus: focus)
        #expect(model.recordedValues(for: try #require(model.rows.last)) == SetValues(weight: 10_000, reps: 8))
        #expect(model.rows.last?.performedSetID == second.performedSetID && model.unfinishedSetCount(for: today) == 0)
    }

    @Test func failedGroupRepeatRetriesAllStagesAndDeduplicatesItsAction() throws {
        let store = DropFailureRepository()
        let model = try twoStages(store)
        for row in model.rows { #expect(model.setRepsInReserve(4, for: row.id)) }
        let before = model.snapshot, original = model.rows, action = UUID()
        store.reject = true
        #expect(!model.repeatLastSet(actionID: action))
        #expect(model.snapshot == before && model.canRetrySave)
        store.reject = false
        #expect(model.retrySave())
        #expect(model.setEntries.count == 2 && model.rows.count == 4)
        let copied = Array(model.rows.suffix(2))
        #expect(Array(model.rows.prefix(2)) == original)
        #expect(copied[0].dropGroupID != nil && copied[0].dropGroupID == copied[1].dropGroupID)
        #expect(copied[0].dropGroupID != original[0].dropGroupID)
        #expect(Set(copied.map(\.id)).isDisjoint(with: original.map(\.id)))
        #expect(Set(copied.map(\.actionID)).isDisjoint(with: original.map(\.actionID)))
        #expect(Set(copied.compactMap(\.performedSetID)).isDisjoint(with: original.compactMap(\.performedSetID)))
        #expect(copied.allSatisfy { $0.repsInReserve == nil })
        #expect(copied.map { model.recordedValues(for: $0) } == original.map { model.recordedValues(for: $0) })
        let repeated = model.snapshot
        #expect(model.repeatLastSet(actionID: action) && model.snapshot == repeated)
        let reopened = try self.model(store)
        #expect(reopened.undoChange() && reopened.rows == original)
        #expect(reopened.summary(for: today).setCount == 1)
    }

    @Test func groupDeleteRetriesAndUndoRestoresSharedHistoricalBatchIdentities() throws {
        let snapshot = try sharedBatchSnapshot()
        let store = DropFailureRepository(snapshot)
        let model = try model(store)
        let original = model.rows, batch = try #require(model.journal.batches.first)
        store.reject = true
        #expect(!model.deleteSet(original[1].id))
        #expect(model.snapshot == snapshot)
        #expect(try store.loadSnapshot() == snapshot)
        store.reject = false
        #expect(model.retrySave())
        #expect(model.rows == [original[2]] && model.summary(for: today).setCount == 1)
        #expect(model.journal.batches.first?.sets.map(\.id) == [batch.sets[2].id])
        let reopened = try self.model(store)
        #expect(reopened.undoChange())
        #expect(reopened.rows == original)
        #expect(reopened.journal.batches.first?.sets == batch.sets)
        #expect(reopened.journal.batches.first?.recordedAt == batch.recordedAt)
        #expect(reopened.journal.batches.first?.id == batch.id)
        #expect(reopened.journal.batches.first?.actionID == batch.actionID)
        #expect(reopened.summary(for: today).setCount == 2)
    }

    @Test func deletingTheStartingStageKeepsTheGroupAndUndoRestoresItsOrder() throws {
        let model = try twoStages()
        let before = model.rows, group = try #require(before.first?.dropGroupID)
        #expect(model.deleteDropStage(before[0].id))
        #expect(model.rows == [before[1]] && model.setEntries.first?.id == group)
        #expect(model.setPosition(for: before[1].id)?.stageIndex == 1)
        #expect(model.undoChange() && model.rows == before)
    }

    @Test func changingGroupTypeSplitsStagesWithoutChangingValuesOrEffort() throws {
        let model = try twoStages()
        for row in model.rows { #expect(model.setRepsInReserve(3, for: row.id)) }
        let before = model.rows, journal = model.journal
        #expect(model.setKind(.warmup, for: before[1].id))
        #expect(model.setEntries.count == 2 && model.rows.allSatisfy { $0.kind == .warmup && $0.dropGroupID == nil && $0.repsInReserve == 3 })
        #expect(model.rows.map(\.performedSetID) == before.map(\.performedSetID) && model.journal == journal)
        #expect(model.summary(for: today).setCount == 2)
    }

    @Test func newSetAfterABlankDropStageStartsAnIndependentWorkingEntry() throws {
        let model = try twoStages()
        #expect(model.addDropStage(to: model.rows[0].id))
        let blank = try #require(model.rows.last)
        #expect(model.newSet())
        #expect(model.rows.count == 4 && model.setEntries.count == 2)
        #expect(model.rows.last?.kind == .working && model.rows.last?.dropGroupID == nil)
        #expect(model.rows[2].id == blank.id && model.rows[2].dropGroupID != nil)
    }

    @Test func bodyweightDropStagesFocusRepsAndKeepZeroCanonicalWeight() throws {
        let model = try model()
        #expect(model.openToday()); #expect(model.addExercise("push-up"))
        let first = try #require(model.rows.first)
        #expect(model.setKind(.dropSet, for: first.id))
        #expect(model.selectInput(first.id, field: .reps))
        model.typeInput("12", focus: try #require(model.focus))
        #expect(model.addDropStage(to: first.id))
        #expect(model.focus?.field == .reps && model.focus?.keyboard == true)
        model.typeInput("8", focus: try #require(model.focus))
        #expect(model.journal.batches.flatMap(\.sets).map(\.values) == [SetValues(weight: 0, reps: 12), SetValues(weight: 0, reps: 8)])
        #expect(model.rows.allSatisfy { $0.weight.isEmpty } && model.summary(for: today).setCount == 1)
    }

    @Test func legacyDropRowsStaySeparateUntilOneExplicitlyGainsAStage() throws {
        let snapshot = try sharedBatchSnapshot(grouped: false)
        let store = try MemoryJournalRepository(snapshot: snapshot)
        let model = try model(store), original = model.rows
        #expect(model.setEntries.count == 3 && model.rows.allSatisfy { $0.dropGroupID == nil })
        #expect(try store.loadSnapshot() == snapshot)
        #expect(model.addDropStage(to: original[0].id))
        #expect(model.rows.count == 4 && model.setEntries.count == 3)
        #expect(model.rows[2] == original[1] && model.rows[2].dropGroupID == nil)
        #expect(model.journal == snapshot.journal)
    }

    @Test func groupedHistoryKeepsExactCanonicalWeightsAndCivilDatesAcrossUnitChanges() throws {
        let past = try TrainingDay("2026-11-02")
        let values = [SetValues(weight: 100, reps: 10), SetValues(weight: 55, reps: 8)]
        let snapshot = try sharedBatchSnapshot(unit: .kilograms, day: past, values: values)
        let store = try MemoryJournalRepository(snapshot: snapshot)
        var otherCalendar = calendar; otherCalendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let model = try TrainingNotebookModel(repository: store, calendar: otherCalendar, now: { today.date(in: calendar) })
        #expect(model.rows.map(\.weight) == ["0.45", "0.25"])
        #expect(model.changeUnit(.pounds)); #expect(model.changeUnit(.kilograms))
        #expect(model.rows.map(\.canonicalWeight) == [100, 55])
        #expect(model.repeatLastSet())
        #expect(model.journal.batches.flatMap(\.sets).map(\.values) == values + values)
        #expect(model.summary(for: past).setCount == 2 && model.summary(for: today).setCount == 0)
        let exercise = Exercise.catalog[0]
        let progress = model.snapshot.progress(for: exercise, through: today, calendar: otherCalendar)
        #expect(progress.setCount == 2 && progress.sessions.first?.setCount == 2)
        #expect(progress.sessions.first?.sets.count == 4 && progress.sessions.first?.day == past)
        #expect(progress.bestSet?.values == values[0] && progress.sessions.first?.sets[0].id == snapshot.journal.batches[0].sets[0].id)
        #expect(model.snapshot.trends(through: today, calendar: otherCalendar).setCount == 2)
        #expect(model.journal.batches[0].recordedAt == snapshot.journal.batches[0].recordedAt)
        #expect(model.setPlan(ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12), for: "bench"))
        #expect(model.nextWorkoutGuidance(for: "bench").reason == .dropSets)
    }
}

@MainActor private final class DropFailureRepository: JournalRepository {
    private var snapshot: JournalSnapshot
    var reject = false
    init(_ snapshot: JournalSnapshot = JournalSnapshot()) { self.snapshot = snapshot }
    func loadSnapshot() throws -> JournalSnapshot { try snapshot.validated() }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated()
    }
}
