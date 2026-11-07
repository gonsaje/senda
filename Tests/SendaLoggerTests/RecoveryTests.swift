import Testing
import Foundation
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor
struct RecoveryTests {
    @Test func reopeningRestoresEveryLiftAndPartialNumericTextWithoutRecording() throws {
        let store = MemoryJournalRepository()
        let first = try LoggerModel(repository: store)
        _ = first.setValue(8, for: .reps)
        let action = first.draft?.actionID
        first.selectExercise("deadlift")
        _ = first.setValue(5, for: .reps)
        first.typeNumber("229.")
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.selectedExerciseID == "deadlift")
        #expect(reopened.numberInputText == "229.")
        #expect(!reopened.numberInputIsValid)
        #expect(reopened.journal.batches.isEmpty)
        reopened.cancelNumberInput()
        #expect(reopened.draft?.sets.first?.reps == 5)
        reopened.selectExercise("bench")
        #expect(reopened.draft?.actionID == action)
        #expect(reopened.draft?.sets.first?.reps == 8)
    }

    @Test func openSetEditorAndInvalidRowTextRecoverAndCancelKeepsOriginalEntry() throws {
        let store = MemoryJournalRepository()
        let first = try LoggerModel(repository: store)
        first.beginEditingSets()
        _ = first.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        first.typeEditedSet(at: 2, field: .reps, text: "")
        first.setEditorFocus(index: 2, field: .reps)
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.editor?.sets.last?.reps == 8)
        #expect(reopened.editor?.inputs[2].reps == "")
        #expect(reopened.editor?.focus == SetFieldFocus(index: 2, field: .reps))
        #expect(!reopened.canConfirmSetEdits)
        #expect(!reopened.confirmSetEdits())
        reopened.cancelSetEdits()
        #expect(reopened.values.map(\.reps) == [10, 10, 10, 10])
        #expect(reopened.journal.batches.isEmpty)
    }

    @Test func recordUndoAndRerecordStayAtomicAcrossReopening() throws {
        let store = MemoryJournalRepository()
        let first = try LoggerModel(repository: store)
        _ = first.setValue(8, for: .reps)
        let originalAction = first.draft?.actionID
        #expect(first.record())
        let recordedID = first.recorded?.id
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.recorded?.id == recordedID)
        #expect(!reopened.record())
        #expect(reopened.journal.batches.count == 1)
        #expect(reopened.undo())
        let undone = try LoggerModel(repository: store)
        #expect(undone.journal.batches.isEmpty)
        #expect(undone.values.map(\.reps) == [8, 8, 8, 8])
        #expect(undone.draft?.actionID != originalAction)
        #expect(undone.record())
        #expect(undone.journal.batches.count == 1)
    }

    @Test func recordedNumbersEditInPlaceRecoverAndSaveOnlyOnDone() throws {
        let store = MemoryJournalRepository()
        let first = try LoggerModel(repository: store)
        #expect(first.record())
        let original = try #require(first.recorded)
        first.selectField(.weight)
        #expect(first.isEditingRecorded)
        first.typeNumber("140")
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.isEditingRecorded)
        #expect(reopened.numberInputText == "140")
        #expect(reopened.journal.batches.first?.values.first?.weight == 13_500)
        #expect(reopened.finishEditing())
        #expect(reopened.recorded?.id == original.id)
        #expect(reopened.recorded?.revision == 2)
        #expect(reopened.recorded?.values.first?.weight == 14_000)
        #expect(reopened.journal.batches.count == 1)
        reopened.selectField(.reps)
        _ = reopened.setValue(7, for: .reps)
        reopened.cancelEditing()
        #expect(reopened.values.map(\.reps) == [10, 10, 10, 10])
    }

    @Test func unchangedDoneDoesNotFlattenExceptionsOrBumpRevision() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.beginEditingSets()
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        _ = model.confirmSetEdits()
        _ = model.record()
        model.selectField(.reps)
        #expect(model.finishEditing())
        #expect(model.recorded?.revision == 1)
        #expect(model.values.map(\.reps) == [10, 10, 10, 8])
    }

    @Test func editingPreviousEntryKeepsCurrentPartialInputAndUnfinishedSets() throws {
        let store = MemoryJournalRepository()
        let model = try LoggerModel(repository: store)
        _ = model.record()
        let previous = try #require(model.recorded)
        model.anotherBatch()
        _ = model.setValue(8, for: .reps)
        model.typeNumber("137.")
        model.beginEditingSets(batchID: previous.id)
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 7))
        #expect(model.confirmSetEdits())
        #expect(model.numberInputText == "137.")
        #expect(!model.numberInputIsValid)
        #expect(model.values.map(\.reps) == [8, 8, 8, 8])
        #expect(model.journal.batches.first?.values.last?.reps == 7)
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.numberInputText == "137.")
        #expect(reopened.values.map(\.reps) == [8, 8, 8, 8])
        reopened.beginEditingSets(batchID: previous.id)
        reopened.cancelSetEdits()
        #expect(reopened.numberInputText == "137.")
    }

    @Test func recoveryFailureKeepsEditsInMemoryAndRetriesWithoutRecording() throws {
        let store = RecoveryFailureStore()
        let model = try LoggerModel(repository: store)
        #expect(model.flushRecovery())
        store.failWrites = true
        #expect(model.setValue(8, for: .reps))
        #expect(model.values.first?.reps == 8)
        #expect(model.recoveryErrorMessage != nil)
        #expect(try LoggerModel(repository: store).values.first?.reps == 10)
        store.failWrites = false
        #expect(model.flushRecovery())
        #expect(model.recoveryErrorMessage == nil)
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.values.first?.reps == 8)
        #expect(reopened.journal.batches.isEmpty)
    }

    @Test func failedRecordAndUndoKeepMatchingStoredWorkspace() throws {
        let store = RecoveryFailureStore()
        let model = try LoggerModel(repository: store)
        _ = model.setValue(8, for: .reps)
        let beforeRecord = store.snapshot
        store.failWrites = true
        #expect(!model.record())
        #expect(store.snapshot == beforeRecord)
        #expect(try LoggerModel(repository: store).journal.batches.isEmpty)
        store.failWrites = false
        #expect(model.record())
        let beforeUndo = store.snapshot
        store.failWrites = true
        #expect(!model.undo())
        #expect(store.snapshot == beforeUndo)
        #expect(try LoggerModel(repository: store).recorded?.id == model.recorded?.id)
    }

    @Test func failedCorrectionRecoversPendingInputAndKeepsPerformedValues() throws {
        let store = RecoveryFailureStore()
        let model = try LoggerModel(repository: store)
        _ = model.record()
        let id = model.recorded?.id
        model.selectField(.weight)
        model.typeNumber("140")
        let beforeDone = store.snapshot
        store.failWrites = true
        #expect(!model.finishEditing())
        #expect(store.snapshot == beforeDone)
        #expect(model.isEditingRecorded)
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.numberInputText == "140")
        #expect(reopened.journal.batches.first?.values.first?.weight == 13_500)
        store.failWrites = false
        #expect(reopened.finishEditing())
        #expect(reopened.recorded?.id == id)
        #expect(reopened.recorded?.values.first?.weight == 14_000)
    }

    @Test func recoveredOlderEntryEditorPreservesCurrentInvalidDockOnDone() throws {
        let store = MemoryJournalRepository()
        let model = try LoggerModel(repository: store)
        _ = model.record()
        let previous = try #require(model.recorded)
        model.anotherBatch()
        model.typeNumber("")
        model.beginEditingSets(batchID: previous.id)
        _ = model.updateEditedSet(at: 3, values: SetValues(weight: 13_500, reps: 8))
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.editor?.sets.last?.reps == 8)
        #expect(reopened.numberInputText == "")
        #expect(reopened.confirmSetEdits())
        #expect(reopened.numberInputText == "")
        #expect(!reopened.numberInputIsValid)
        #expect(reopened.values.last?.reps == 10)
        #expect(reopened.journal.batches.first?.values.last?.reps == 8)
    }

    @Test func progressChangesOnlyWhenCorrectionIsDone() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        _ = model.record(); model.anotherBatch(); _ = model.record()
        let id = try #require(model.recorded?.id)
        #expect(model.comparison?.repDifferenceAtSameWeight == 0)
        model.selectField(.reps)
        _ = model.setValue(8, for: .reps)
        #expect(model.comparison == nil)
        #expect(model.journal.comparison(for: id)?.repDifferenceAtSameWeight == 0)
        #expect(model.finishEditing())
        #expect(model.comparison?.repDifferenceAtSameWeight == -8)
        #expect(model.journal.batches.count == 2)
    }

    @Test func realFileRestoresWorkingEntryRecordUndoAndRerecord() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("senda-integration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("journal.json")
        let first = try LoggerModel(repository: FileJournalRepository(url: url))
        first.selectExercise("deadlift")
        first.typeNumber("229.")
        let recovered = try LoggerModel(repository: FileJournalRepository(url: url))
        #expect(recovered.selectedExerciseID == "deadlift")
        #expect(recovered.numberInputText == "229.")
        recovered.typeNumber("230")
        #expect(recovered.record())
        let saved = try LoggerModel(repository: FileJournalRepository(url: url))
        #expect(saved.recorded?.values.first?.weight == 23_000)
        #expect(saved.undo())
        let undone = try LoggerModel(repository: FileJournalRepository(url: url))
        #expect(undone.journal.batches.isEmpty)
        #expect(undone.values.first?.weight == 23_000)
        #expect(undone.record())
        #expect(try FileJournalRepository(url: url).load().batches.count == 1)
    }
}

@MainActor
private final class RecoveryFailureStore: JournalRepository {
    var snapshot = JournalSnapshot()
    var failWrites = false
    func loadSnapshot() throws -> JournalSnapshot { try snapshot.validated() }
    func saveSnapshot(_ snapshot: JournalSnapshot) throws {
        if failWrites { throw CocoaError(.fileWriteOutOfSpace) }
        self.snapshot = try snapshot.validated()
    }
}
