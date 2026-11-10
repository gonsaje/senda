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
