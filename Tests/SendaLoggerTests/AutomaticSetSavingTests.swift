import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct AutomaticSetSavingTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private var day: TrainingDay { try! TrainingDay("2026-11-07") }
    private func model(_ repository: any JournalRepository) throws -> TrainingNotebookModel {
        try TrainingNotebookModel(repository: repository, calendar: calendar,
                                  now: { self.day.date(in: self.calendar) })
    }
    private func begin(_ model: TrainingNotebookModel, exercise: String = "bench") throws -> UUID {
        #expect(model.openDay(day)); #expect(model.addExercise(exercise))
        return try #require(model.rows.first?.id)
    }
    private func enter(_ model: TrainingNotebookModel, row: UUID, weight: String = "135", reps: String = "10") throws {
        #expect(model.selectInput(row, field: .weight))
        model.typeInput(weight, focus: try #require(model.focus))
        #expect(model.selectInput(row, field: .reps))
        model.typeInput(reps, focus: try #require(model.focus))
    }

    @Test func workoutRecordsMarkOnlyTheSetThatStrictlyBeatEarlierSavedPerformance() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let prior = try day.adding(days: -1)
        #expect(model.openDay(prior))
        #expect(model.addExercise("bench"))
        try enter(model, row: try #require(model.rows.first?.id), weight: "45")
        #expect(model.newSet())
        try enter(model, row: try #require(model.rows.last?.id))
        #expect(model.workoutPersonalRecords.isEmpty)

        let tie = try begin(model)
        try enter(model, row: tie)
        #expect(model.workoutPersonalRecords.isEmpty)
        #expect(model.newSet())
        let extraRep = try #require(model.rows.last?.id)
        try enter(model, row: extraRep, reps: "11")
        #expect(model.newSet())
        let heavier = try #require(model.rows.last?.id)
        try enter(model, row: heavier, weight: "140", reps: "5")
        #expect(model.repeatLastSet())

        let records = model.workoutPersonalRecords
        #expect(Set(records.keys) == [extraRep, heavier])
        #expect(records[extraRep]?.previousValues == SetValues(weight: 13_500, reps: 10))
        #expect(records[heavier]?.values == SetValues(weight: 14_000, reps: 5))
        #expect(records[heavier]?.previousValues == SetValues(weight: 13_500, reps: 11))
        #expect(try self.model(store).workoutPersonalRecords == records)

        #expect(model.openDay(prior))
        #expect(model.workoutPersonalRecords.isEmpty)
        try enter(model, row: try #require(model.rows.first?.id), weight: "145")
        #expect(model.openDay(day))
        #expect(model.workoutPersonalRecords.isEmpty)
    }

    @Test func bodyweightRecordUsesSavedRepsThroughFailedSaveCorrectionAndUndo() throws {
        let store = AutomaticSavingFailureRepository(), model = try model(store)
        #expect(model.openDay(try day.adding(days: -1)))
        #expect(model.addExercise("push-up"))
        try enter(model, row: try #require(model.rows.first?.id), weight: "", reps: "8")
        let baselineWrite = try #require(model.latestWorkoutSetWrite)
        let row = try begin(model, exercise: "push-up")
        #expect(model.selectInput(row, field: .reps))
        let focus = try #require(model.focus)
        store.reject = true
        model.typeInput("10", focus: focus)
        #expect(model.canRetrySave && model.workoutPersonalRecords.isEmpty)
        #expect(model.latestWorkoutSetWrite == baselineWrite)
        store.reject = false
        #expect(model.retrySave())
        let earned = try #require(model.latestWorkoutSetWrite)
        #expect(earned.rowID == row && earned.day == day && earned.exerciseID == "push-up")
        #expect(earned.values == SetValues(weight: 0, reps: 10))
        #expect(try self.model(store).latestWorkoutSetWrite == nil)
        #expect(model.workoutPersonalRecords[row]?.values == SetValues(weight: 0, reps: 10))
        model.typeInput("", focus: focus)
        #expect(model.workoutPersonalRecords[row]?.values == SetValues(weight: 0, reps: 10))
        model.typeInput("7", focus: focus)
        #expect(model.workoutPersonalRecords.isEmpty)
        model.typeInput("9", focus: focus)
        let edited = model.latestWorkoutSetWrite
        #expect(model.deleteSet(row))
        #expect(model.workoutPersonalRecords.isEmpty)
        #expect(model.undoChange())
        #expect(model.latestWorkoutSetWrite == edited)
        #expect(model.workoutPersonalRecords[row]?.previousValues == SetValues(weight: 0, reps: 8))
    }

    @Test func completeInputSavesBeforeFocusLeavesTheRow() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let row = try begin(model)
        try enter(model, row: row)
        #expect(model.focus?.rowID == row && model.focus?.field == .reps)
        #expect(model.summary(for: day).setCount == 1)
        #expect(model.journal.batches.first?.values == [SetValues(weight: 13_500, reps: 10)])
        let reopened = try self.model(store)
        #expect(reopened.journal == model.journal && reopened.focus == model.focus)
        #expect(reopened.rows.first?.performedSetID == model.rows.first?.performedSetID)
    }

    @Test func firstSetStateRequiresADurableSaveAndSurvivesDeletionInSession() throws {
        let store = AutomaticSavingFailureRepository(), model = try model(store)
        let row = try begin(model)
        #expect(!model.hasSavedFirstSet)
        #expect(model.selectInput(row, field: .weight))
        model.typeInput("135", focus: try #require(model.focus))
        #expect(!model.hasSavedFirstSet)
        #expect(model.selectInput(row, field: .reps))
        store.reject = true
        model.typeInput("8", focus: try #require(model.focus))
        #expect(!model.hasSavedFirstSet && model.canRetrySave && store.snapshot.journal.batches.isEmpty)

        store.reject = false
        #expect(model.retrySave())
        #expect(model.hasSavedFirstSet && model.focus?.rowID == row)
        #expect(try self.model(store).hasSavedFirstSet)
        #expect(model.deleteSet(row))
        #expect(model.journal.batches.isEmpty && model.hasSavedFirstSet)
    }

    @Test func validCorrectionUpdatesTheSameHistoricalSetImmediately() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let previous = try TrainingDay("2026-11-06")
        #expect(model.openDay(previous)); #expect(model.addExercise("bench"))
        let row = try #require(model.rows.first?.id)
        try enter(model, row: row)
        #expect(model.finishEditing())
        let setID = try #require(model.rows.first?.performedSetID)
        #expect(model.selectInput(row, field: .reps))
        model.typeInput("8", focus: try #require(model.focus))
        #expect(model.journal.reference(to: setID)?.set.values == SetValues(weight: 13_500, reps: 8))
        #expect(model.journal.reference(to: setID)?.batch.recordedAt == previous.date(in: calendar))
        #expect(model.rows.first?.performedSetID == setID && model.focus?.rowID == row)
        #expect(model.rows.first?.pendingCorrection != true && model.journal.batches.count == 1)
        #expect(try self.model(store).journal == model.journal)
    }

    @Test func autosavePreservesRawLeadingZerosUntilEditingFinishes() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let row = try begin(model)
        try enter(model, row: row, weight: "00135", reps: "0010")
        #expect(model.rows.first?.weight == "00135" && model.rows.first?.reps == "0010")
        #expect(model.journal.batches.first?.values == [SetValues(weight: 13_500, reps: 10)])
        let focus = model.focus
        let reopened = try self.model(store)
        #expect(reopened.rows == model.rows && reopened.focus == focus)
        #expect(model.finishEditing())
        #expect(model.rows.first?.weight == "135" && model.rows.first?.reps == "10")
    }

    @Test func trailingDecimalRetainsLastValidHistoryAndDurableRawInput() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let row = try begin(model)
        try enter(model, row: row)
        let setID = try #require(model.rows.first?.performedSetID)
        #expect(model.selectInput(row, field: .weight))
        model.typeInput("31.", focus: try #require(model.focus))
        #expect(model.rows.first?.weight == "31." && model.rows.first?.pendingCorrection == true)
        #expect(model.journal.reference(to: setID)?.set.values == SetValues(weight: 13_500, reps: 10))
        let reopened = try self.model(store)
        #expect(reopened.rows == model.rows && reopened.focus == model.focus)
        #expect(reopened.finishEditing())
        #expect(reopened.rows.first?.weight == "31." && reopened.rows.first?.performedSetID == setID)
    }

    @Test func incompleteNewInputPersistsWithoutInventingASet() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let row = try begin(model)
        try enter(model, row: row, weight: "31.", reps: "8")
        #expect(model.journal.batches.isEmpty)
        let reopened = try self.model(store)
        #expect(reopened.rows.first?.weight == "31." && reopened.rows.first?.reps == "8")
        #expect(reopened.focus == model.focus && reopened.journal.batches.isEmpty)
    }

    @Test func bodyweightAndExplicitZeroSaveAsSoonAsRepsAreEntered() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let bodyweightRow = try begin(model, exercise: "push-up")
        try enter(model, row: bodyweightRow, weight: "", reps: "12")
        #expect(model.rows.first?.weight == "")
        #expect(model.recordedValues(for: model.rows[0]) == SetValues(weight: 0, reps: 12))
        #expect(model.addExercise("bench"))
        try enter(model, row: try #require(model.rows.first?.id), weight: "0", reps: "3")
        #expect(model.rows.first?.weight == "0")
        #expect(model.recordedValues(for: model.rows[0]) == SetValues(weight: 0, reps: 3))
        #expect(try self.model(store).summary(for: day).setCount == 2)
    }

    @Test func kilogramPrefillSavesExactHistoricalCanonicalWeight() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let prior = try day.adding(days: -1)
        #expect(model.openDay(prior)); #expect(model.addExercise("bench"))
        try enter(model, row: try #require(model.rows.first?.id), weight: "1", reps: "7")
        #expect(model.openDay(day)); #expect(model.addExercise("bench")); #expect(model.changeUnit(.kilograms))
        let row = try #require(model.rows.first)
        #expect(model.prefillSet(row.id))
        #expect(model.rows.first?.id == row.id && model.rows.first?.actionID == row.actionID)
        #expect(model.rows.first?.weight == "0.45" && model.rows.first?.canonicalWeight == 100)
        #expect(model.recordedValues(for: model.rows[0]) == SetValues(weight: 100, reps: 7))
        #expect(model.summary(for: day).setCount == 1 && model.focus?.rowID == row.id)
        #expect(try self.model(store).rows == model.rows)
    }

    @Test func repeatedNumericStepsKeepOnePerformedSet() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let row = try begin(model)
        try enter(model, row: row)
        let setID = try #require(model.rows.first?.performedSetID)
        let repsFocus = try #require(model.focus)
        #expect(model.stepInput(increasing: true, focus: repsFocus))
        #expect(model.stepInput(increasing: true, focus: repsFocus))
        #expect(model.journal.reference(to: setID)?.set.values == SetValues(weight: 13_500, reps: 12))
        #expect(model.selectInput(row, field: .weight))
        let weightFocus = try #require(model.focus)
        #expect(model.setInputWeight(14_000, focus: weightFocus))
        #expect(model.stepInput(increasing: true, focus: weightFocus))
        #expect(model.journal.reference(to: setID)?.set.values == SetValues(weight: 14_250, reps: 12))
        #expect(model.journal.batches.count == 1 && model.journal.batches.flatMap(\.sets).count == 1)
        #expect(try self.model(store).rows.first?.performedSetID == setID)
    }

    @Test func failedAutomaticSaveKeepsRawInputAndRetriesExactlyOnce() throws {
        let store = AutomaticSavingFailureRepository(), model = try model(store)
        let row = try begin(model)
        #expect(model.selectInput(row, field: .weight)); model.typeInput("135", focus: try #require(model.focus))
        #expect(model.selectInput(row, field: .reps))
        store.reject = true
        model.typeInput("10", focus: try #require(model.focus))
        #expect(model.rows.first?.reps == "10" && model.focus?.rowID == row)
        #expect(model.journal.batches.isEmpty && store.snapshot.journal.batches.isEmpty && model.canRetrySave)
        #expect(!model.retrySave())
        store.reject = false
        #expect(model.retrySave())
        let setID = try #require(model.rows.first?.performedSetID), saved = model.snapshot
        #expect(model.journal.reference(to: setID)?.set.values == SetValues(weight: 13_500, reps: 10))
        #expect(model.retrySave() && model.snapshot == saved)
        #expect(model.finishEditing() && model.journal.batches.flatMap(\.sets).count == 1)
        #expect(try self.model(store).rows.first?.performedSetID == setID)
    }

    @Test func newerNumericInputSupersedesAFailedNavigationDestination() throws {
        let store = AutomaticSavingFailureRepository(), model = try model(store)
        let row = try begin(model)
        try enter(model, row: row)
        let setID = try #require(model.rows.first?.performedSetID)
        store.reject = true
        #expect(!model.changeDay(1))
        model.typeInput("11", focus: try #require(model.focus))
        #expect(model.rows.first?.reps == "11" && model.selectedDay == day)
        #expect(model.journal.reference(to: setID)?.set.values.reps == 10)
        store.reject = false
        #expect(model.retrySave())
        #expect(model.selectedDay == day && model.focus?.rowID == row)
        #expect(model.journal.reference(to: setID)?.set.values.reps == 11)
        #expect(model.journal.batches.count == 1)
    }

    @Test func openingMetadataEditorCannotDropAFailedNumericUpdate() throws {
        let store = AutomaticSavingFailureRepository(), model = try model(store)
        let row = try begin(model)
        try enter(model, row: row)
        let setID = try #require(model.rows.first?.performedSetID)
        store.reject = true
        model.typeInput("8", focus: try #require(model.focus))
        let focus = model.focus
        #expect(!model.openProgress(for: "bench"))
        #expect(!model.beginMetadataEditing())
        #expect(model.rows.first?.reps == "8" && model.focus == focus && model.canRetrySave)
        #expect(model.journal.reference(to: setID)?.set.values.reps == 10)
        store.reject = false
        #expect(model.retrySave())
        #expect(!model.isProgressPresented && model.focus == focus)
        #expect(model.journal.reference(to: setID)?.set.values.reps == 8)
        #expect(model.updateSetDetails(row, kind: .warmup, repsInReserve: 3))
        #expect(model.rows.first?.kind == .warmup && model.rows.first?.repsInReserve == 3)
        #expect(model.rows.first?.performedSetID == setID && model.journal.batches.count == 1)
        #expect(try self.model(store).rows == model.rows)
    }

    @Test func doneOnlyClosesEditingWithoutDuplicatingOrRevisingSavedValues() throws {
        let store = MemoryJournalRepository(), model = try model(store)
        let row = try begin(model)
        try enter(model, row: row)
        let journal = model.journal, setID = try #require(model.rows.first?.performedSetID)
        #expect(model.finishEditing() && model.focus == nil)
        #expect(model.finishEditing() && model.journal == journal)
        #expect(model.rows.first?.performedSetID == setID && model.journal.batches.count == 1)
        #expect(try self.model(store).journal == journal)
    }

    @Test func saveStatusReflectsDurabilityWhileEditingAndAfterErrorDismissal() throws {
        let store = AutomaticSavingFailureRepository(), model = try model(store)
        let row = try begin(model)
        try enter(model, row: row)
        #expect(model.focus?.rowID == row && model.saveStatus == "All changes saved")
        #expect(model.selectInput(row, field: .weight))
        model.typeInput("31.", focus: try #require(model.focus))
        #expect(store.snapshot.training?.days[day.rawValue]?.rows["bench"]?.first?.weight == "31.")
        #expect(model.saveStatus == "All changes saved")
        #expect(model.finishEditing() && model.saveStatus == "All changes saved")
        #expect(model.selectInput(row, field: .weight))
        store.reject = true
        model.typeInput("140", focus: try #require(model.focus))
        #expect(model.canRetrySave && model.saveStatus == "Couldn’t save changes")
        model.dismissError()
        #expect(model.errorMessage == nil && model.canRetrySave)
        #expect(model.saveStatus == "Couldn’t save changes")
        store.reject = false
        #expect(model.retrySave() && !model.canRetrySave)
        #expect(model.saveStatus == "All changes saved")
        #expect(model.recordedValues(for: model.rows[0]) == SetValues(weight: 14_000, reps: 10))
    }
}

@MainActor private final class AutomaticSavingFailureRepository: JournalRepository {
    var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { try snapshot.validated() }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated()
    }
}
