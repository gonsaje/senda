import Testing
import Foundation
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor
struct LoggerTests {
    private func seeded() throws -> Journal {
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: "bench", sets: Array(repeating:
            SetValues(weight: 13_500, reps: 10), count: 4)), at: Date(timeIntervalSince1970: 1_000))
        return journal
    }

    @Test func draftSuggestionsNeverBecomePerformedSetsUntilExplicitSave() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository(journal: seeded()))
        #expect(model.draft?.sets.count == 4)
        #expect(model.recorded == nil)
        #expect(model.journal.batches.count == 1)
        #expect(model.comparison == nil)
        #expect(model.priorReference?.values.map(\.reps) == [10, 10, 10, 10])
        #expect(model.record())
        #expect(model.draft == nil)
        #expect(model.recorded?.values.map(\.reps) == [10, 10, 10, 10])
        #expect(model.journal.batches.count == 2)
        #expect(!model.record())
        #expect(model.journal.batches.count == 2)
    }

    @Test func draftExceptionCancelAndConfirmDoNotWriteHistory() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository(journal: seeded()))
        model.beginEditingSets()
        #expect(model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8)))
        model.cancelSetEdits()
        #expect(model.draft?.sets.last?.reps == 10)
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        #expect(model.confirmSetEdits())
        #expect(model.draft?.sets.map(\.reps) == [10, 10, 10, 8])
        #expect(model.journal.batches.count == 1)
        #expect(model.record())
        #expect(model.recorded?.values.map(\.reps) == [10, 10, 10, 8])
        #expect(model.comparison?.repDifferenceAtSameWeight == -2)
    }

    @Test func recordedCorrectionNeedsConfirmationAndUpdatesComparison() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository(journal: seeded()))
        _ = model.record()
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        #expect(model.recorded?.values.last?.reps == 10)
        model.cancelSetEdits()
        #expect(model.comparison?.repDifferenceAtSameWeight == 0)
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        #expect(model.confirmSetEdits())
        #expect(model.comparison?.repDifferenceAtSameWeight == -2)
        #expect(model.recorded?.revision == 2)
        #expect(model.undo())
        #expect(model.draft?.sets.last?.reps == 8)
        #expect(model.recorded == nil)
        #expect(model.comparison == nil)
        #expect(model.journal.batches.count == 1)
    }

    @Test func anotherBatchAllowsIdenticalValuesWithFreshAction() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        let action = model.draft?.actionID
        _ = model.record()
        model.anotherBatch()
        #expect(model.draft?.actionID != action)
        #expect(model.journal.batches.count == 1)
        #expect(model.record())
        try #require(model.journal.batches.count == 2)
        #expect(model.journal.batches[0].values == model.journal.batches[1].values)
    }

    @Test func switchingLiftsKeepsEachUnsavedDraftAndRecordedState() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        _ = model.setValue(8, for: .reps)
        let action = model.draft?.actionID
        model.selectExercise("deadlift")
        _ = model.setValue(5, for: .reps)
        _ = model.record()
        let recordedID = model.recorded?.id
        model.selectExercise("bench")
        #expect(model.draft?.actionID == action)
        #expect(model.draft?.sets.first?.reps == 8)
        model.selectExercise("deadlift")
        #expect(model.recorded?.id == recordedID)
    }

    @Test func failedSaveAndFailedUndoDoNotPublishCandidateState() throws {
        let store = SwitchableRepository()
        let model = try LoggerModel(repository: store)
        let draft = model.draft
        store.failWrites = true
        #expect(!model.record())
        #expect(model.draft == draft)
        #expect(model.journal.batches.isEmpty)
        #expect(model.errorMessage != nil)
        store.failWrites = false
        #expect(model.record())
        let recorded = model.recorded
        store.failWrites = true
        #expect(!model.undo())
        #expect(model.recorded == recorded)
        #expect(model.draft == nil)
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 0, values: SetValues(weight: 10_000, reps: 8))
        #expect(!model.confirmSetEdits())
        #expect(model.recorded == recorded)
        #expect(model.editor != nil)
    }

    @Test func resizingKeepsExceptionsAndGlobalWeightDoesNotClearRepExceptions() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        _ = model.confirmSetEdits()
        #expect(model.setValue(5, for: .sets))
        #expect(model.draft?.sets.map(\.reps) == [10, 10, 10, 8, 10])
        #expect(model.setValue(13_750, for: .weight))
        #expect(model.draft?.sets.map(\.reps) == [10, 10, 10, 8, 10])
        let before = model.draft
        #expect(!model.setValue(0, for: .sets))
        #expect(!model.setValue(31, for: .sets))
        #expect(!model.setValue(-1, for: .weight))
        #expect(model.draft == before)
    }

    @Test func typedNumbersAreBoundedAndLocaleDecimalSeparatorIsAccepted() {
        #expect(NumericField.weight.parse("137.5") == 13_750)
        #expect(NumericField.weight.parse("137,50") == 13_750)
        #expect(NumericField.weight.parse("0") == 0)
        for value in ["", "-1", "NaN", "1e3", "1.234", "10001", "1,234.50"] {
            #expect(NumericField.weight.parse(value) == nil)
        }
        #expect(NumericField.reps.parse("10") == 10)
        #expect(NumericField.reps.parse("0") == nil)
        #expect(NumericField.sets.parse("31") == nil)
        #expect(NumericField.sets.parse("4.0") == nil)
    }

    @Test func freshSessionRestoresUnfinishedEntriesOutsideHistory() throws {
        let store = MemoryJournalRepository()
        let first = try LoggerModel(repository: store)
        _ = first.record()
        first.anotherBatch()
        _ = first.setValue(8, for: .reps)
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.journal.batches.count == 1)
        #expect(reopened.draft?.sets.first?.reps == 8)
        #expect(reopened.recorded == nil)
    }

    @Test func typingAnIncreasedSetCountPreservesAllExistingExceptions() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        _ = model.setValue(12, for: .sets)
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 11, values: SetValues(weight: 13_750, reps: 8))
        _ = model.confirmSetEdits()
        model.selectField(.sets)
        model.typeNumber("1")
        #expect(model.draft?.sets.count == 12)
        model.typeNumber("15")
        #expect(model.applyNumberInput())
        #expect(model.draft?.sets.count == 15)
        #expect(model.draft?.sets[11] == SetValues(weight: 13_750, reps: 8))
    }

    @Test func invalidPartialNumberCannotSaveOrEscapeBySwitchingFields() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.selectField(.sets)
        model.typeNumber("3")
        model.typeNumber("31")
        #expect(!model.record())
        #expect(model.draft?.sets.count == 4)
        model.selectField(.weight)
        #expect(model.selectedField == .sets)
        model.selectExercise("deadlift")
        #expect(model.selectedExerciseID == "bench")
        #expect(model.journal.batches.isEmpty)
        model.cancelNumberInput()
        model.selectField(.weight)
        #expect(model.selectedField == .weight)
        #expect(model.draft?.sets.count == 4)
    }

    @Test func savingOrOpeningExceptionsAppliesCompleteTypedNumberOnce() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.typeNumber("137.5")
        model.beginEditingSets()
        #expect(model.editor?.sets.first?.weight == 13_750)
        model.cancelSetEdits()
        model.selectField(.sets)
        model.typeNumber("15")
        #expect(model.record())
        #expect(model.recorded?.sets.count == 15)
        #expect(model.recorded?.values.first?.weight == 13_750)
    }

    @Test func steppingUsesTheCompleteTypedWeight() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.typeNumber("150")
        #expect(model.stepNumber(increasing: true))
        #expect(model.draft?.sets.first?.weight == 15_250)
        #expect(model.numberInputText == "152.5")
        #expect(model.stepNumber(increasing: false))
        #expect(model.draft?.sets.first?.weight == 15_000)
    }

    @Test func steppingTypedSetCountKeepsExistingExceptions() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        _ = model.setValue(12, for: .sets)
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 11, values: SetValues(weight: 13_750, reps: 8))
        _ = model.confirmSetEdits()
        model.selectField(.sets)
        model.typeNumber("15")
        #expect(model.recordSetCount == 15)
        #expect(model.stepNumber(increasing: true))
        #expect(model.draft?.sets.count == 16)
        #expect(model.draft?.sets[11] == SetValues(weight: 13_750, reps: 8))
    }

    @Test func steppingInvalidTextDoesNotChangeDraftOrClearInput() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.typeNumber("-1")
        let before = model.draft
        #expect(!model.stepNumber(increasing: true))
        #expect(model.draft == before)
        #expect(model.numberInputText == "-1")
        #expect(!model.numberInputIsValid)
    }

    @Test func steppingClampsAtFieldLimitsAndCannotChangeRecordedSets() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        _ = model.setValue(0, for: .weight)
        #expect(model.stepNumber(increasing: false))
        #expect(model.draft?.sets.first?.weight == 0)
        model.selectField(.sets)
        _ = model.setValue(30, for: .sets)
        #expect(model.stepNumber(increasing: true))
        #expect(model.draft?.sets.count == 30)
        _ = model.record()
        let recorded = model.recorded
        #expect(!model.stepNumber(increasing: false))
        #expect(model.recorded == recorded)
    }

    @Test func steppingAPendingSmallerCountResizesOnlyOnceAndKeepsTheLastException() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        _ = model.confirmSetEdits()
        model.selectField(.sets)
        model.typeNumber("3")
        #expect(model.stepNumber(increasing: true))
        #expect(model.draft?.sets.map(\.reps) == [10, 10, 10, 8])
        #expect(model.numberInputText == "4")
    }
}

@MainActor
private final class SwitchableRepository: JournalRepository {
    var journal = Journal()
    var failWrites = false
    func loadSnapshot() throws -> JournalSnapshot { JournalSnapshot(journal: journal) }
    func saveSnapshot(_ snapshot: JournalSnapshot) throws { try save(snapshot.journal) }
    func load() throws -> Journal { journal }
    func save(_ journal: Journal) throws {
        if failWrites { throw CocoaError(.fileWriteOutOfSpace) }
        self.journal = journal
    }
}
