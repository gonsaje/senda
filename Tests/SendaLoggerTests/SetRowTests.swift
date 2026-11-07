import Testing
import Foundation
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor
struct SetRowTests {
    @Test func editingOneRowDoesNotChangeOtherSets() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.selectSet(3, field: .reps)
        #expect(model.setValue(8, for: .reps))
        #expect(model.values.map(\.reps) == [10, 10, 10, 8])
        #expect(model.selectedSetIndex == 3)
        #expect(model.record())
        model.selectSet(1, field: .weight, unit: .kilograms)
        model.typeNumber("60")
        #expect(model.finishEditing())
        #expect(model.values.map(\.weight) == [13_500, 13_228, 13_500, 13_500])
        #expect(model.journal.batches.count == 1)
    }

    @Test func unitSwitchingDoesNotRoundOrModifyStoredWeights() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        _ = model.setValue(100, for: .weight)
        _ = model.record()
        #expect(model.selectWeightUnit(.kilograms))
        #expect(!model.isEditingRecorded)
        model.selectSet(0, field: .weight, unit: .kilograms)
        #expect(model.numberInputText == "0.45")
        #expect(model.selectWeightUnit(.pounds))
        #expect(model.numberInputText == "1")
        #expect(model.selectWeightUnit(.kilograms))
        #expect(model.finishEditing())
        #expect(model.values.map(\.weight) == [100, 100, 100, 100])
        #expect(model.recorded?.revision == 1)
    }

    @Test func selectedRowUnitAndPartialTextRecoverTogether() throws {
        let store = MemoryJournalRepository()
        let model = try LoggerModel(repository: store)
        model.selectSet(3, field: .weight, unit: .kilograms)
        model.typeNumber("61.")
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.selectedSetIndex == 3)
        #expect(reopened.selectedWeightUnit == .kilograms)
        #expect(reopened.numberInputText == "61.")
        #expect(!reopened.numberInputIsValid)
        #expect(reopened.journal.batches.isEmpty)
        reopened.cancelNumberInput()
        #expect(reopened.numberInputText == "61.23")
        #expect(reopened.values.last?.weight == 13_500)
    }

    @Test func addAndRemoveRowsPreserveOtherValuesAndAreConfirmedForLoggedEntries() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.selectSet(3, field: .reps)
        _ = model.setValue(8, for: .reps)
        _ = model.record()
        let oldIDs = try #require(model.recorded).sets.map(\.id)
        #expect(model.addSet())
        #expect(model.values.map(\.reps) == [10, 10, 10, 8, 8])
        #expect(model.journal.batches.first?.sets.count == 4)
        model.cancelEditing()
        #expect(model.values.count == 4)
        #expect(model.addSet())
        #expect(model.finishEditing())
        #expect(model.recorded?.sets.prefix(4).map(\.id) == oldIDs)
        #expect(model.recorded?.sets.count == 5)
        let beforeRemoval = try #require(model.recorded).sets.map(\.id)
        #expect(model.removeSet(at: 1))
        #expect(model.values.map(\.reps) == [10, 10, 8, 8])
        #expect(model.finishEditing())
        #expect(model.journal.batches.count == 1)
        #expect(model.recorded?.sets.map(\.id) == [beforeRemoval[0], beforeRemoval[2], beforeRemoval[3], beforeRemoval[4]])
    }

    @Test func dialValueEditsOnlySelectedWeightAndRejectsInvalidAmounts() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.selectSet(2, field: .weight, unit: .kilograms)
        #expect(model.setWeightAmount(60))
        #expect(model.values.map(\.weight) == [13_500, 13_500, 13_228, 13_500])
        #expect(!model.setWeightAmount(.nan))
        #expect(!model.setWeightAmount(-1))
        #expect(!model.setWeightAmount(100_000))
    }

    @Test func dialCanTravelFromZeroAcrossTheFullWeightRange() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        model.selectSet(1, field: .weight, unit: .pounds)
        for amount in [0.0, 500, 2_500, 10_000, 0] {
            #expect(model.setWeightAmount(amount))
            #expect(model.values[1].weight == Int(amount * 100))
            #expect(model.values[0].weight == 13_500)
        }
        #expect(model.selectWeightUnit(.kilograms))
        #expect(model.setWeightAmount(2_000))
        #expect(model.values[1].weight == 440_925)
        let maximum = NSDecimalNumber(decimal: WeightUnit.kilograms.maximumAmount).doubleValue
        #expect(model.setWeightAmount(maximum))
        #expect(model.values[1].weight == 1_000_000)
        #expect(!model.setWeightAmount(maximum + 0.001))
        #expect(model.journal.batches.isEmpty)
    }

    @Test func olderEntryUnitSwitchPreservesCurrentInputAndExactUntouchedWeight() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        _ = model.setValue(100, for: .weight)
        _ = model.record()
        let old = try #require(model.recorded)
        model.anotherBatch()
        model.typeNumber("137.")
        model.beginEditingSets(batchID: old.id)
        #expect(model.selectEditorWeightUnit(.kilograms))
        model.typeEditedSet(at: 0, field: .reps, text: "8")
        #expect(model.confirmSetEdits())
        #expect(model.journal.batches.first?.values.first == SetValues(weight: 100, reps: 8))
        #expect(model.selectedWeightUnit == .pounds)
        #expect(model.numberInputText == "137.")
    }

    @Test func cannotRemoveLastRowOrAddBeyondThirty() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        _ = model.setValue(1, for: .sets)
        #expect(!model.removeSet(at: 0))
        _ = model.setValue(30, for: .sets)
        #expect(!model.addSet())
        #expect(model.values.count == 30)
    }

    @Test func numberControlsOpenOnlyWhenNeededAndCloseWithoutRecording() throws {
        let store = MemoryJournalRepository()
        let model = try LoggerModel(repository: store)
        #expect(!model.showsNumberEditor)
        model.selectSet(2, field: .reps)
        #expect(model.showsNumberEditor)
        model.typeNumber("8")
        #expect(model.closeNumberEditor())
        #expect(!model.showsNumberEditor)
        #expect(model.values.map(\.reps) == [10, 10, 8, 10])
        #expect(model.journal.batches.isEmpty)
        let reopened = try LoggerModel(repository: store)
        #expect(!reopened.showsNumberEditor)
        #expect(reopened.values == model.values)
    }

    @Test func cancellingAnAddedRecordedRowRecoversTheOriginalEntry() throws {
        let store = MemoryJournalRepository()
        let model = try LoggerModel(repository: store)
        #expect(model.record())
        let original = try #require(model.recorded)
        #expect(model.addSet())
        #expect(model.selectedSetIndex == 4)
        model.cancelEditing()
        #expect(model.recoveryErrorMessage == nil)
        let reopened = try LoggerModel(repository: store)
        #expect(!reopened.isEditingRecorded)
        #expect(reopened.values.count == 4)
        #expect(reopened.recorded == original)
        #expect(reopened.selectedSetIndex == 3)
    }

    @Test func replacingAnIdenticalRowStillPreservesTheSurvivingSetIdentities() throws {
        let store = MemoryJournalRepository()
        let model = try LoggerModel(repository: store)
        #expect(model.record())
        let original = try #require(model.recorded)
        #expect(model.removeSet(at: 0))
        #expect(model.addSet())
        #expect(model.values == original.values)
        #expect(model.finishEditing())
        let corrected = try #require(model.recorded)
        #expect(corrected.revision == 2)
        #expect(corrected.sets.prefix(3).map(\.id) == original.sets.dropFirst().map(\.id))
        #expect(!original.sets.map(\.id).contains(corrected.sets[3].id))
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.recorded == corrected)
    }
}
