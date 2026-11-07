import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct InputEchoTests {
    @Test func unchangedNumberEventsPreserveOriginalPoundsThroughRecovery() throws {
        let store = MemoryJournalRepository()
        let model = try LoggerModel(repository: store)
        #expect(model.setValue(100, for: .weight))
        model.selectSet(0, field: .weight, unit: .kilograms)
        #expect(model.numberInputText == "0.45")
        model.typeNumber("0.45")
        #expect(model.closeNumberEditor())
        #expect(model.values[0].weight == 100)
        #expect(try LoggerModel(repository: store).values[0].weight == 100)
        #expect(model.journal.batches.isEmpty)
    }

    @Test func unchangedEditorEventsDoNotCorrectRecordedPounds() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        #expect(model.setValue(100, for: .weight))
        #expect(model.record())
        model.beginEditingSets()
        #expect(model.selectEditorWeightUnit(.kilograms))
        #expect(model.editor?.inputs[0].weight == "0.45")
        model.typeEditedSet(at: 0, field: .weight, text: "0.45")
        #expect(model.confirmSetEdits())
        #expect(model.recorded?.values[0].weight == 100)
        #expect(model.recorded?.revision == 1)
    }

    @Test func clearingAndRetypingRoundedKilogramsStillAppliesTheActualEdit() throws {
        let model = try LoggerModel(repository: MemoryJournalRepository())
        #expect(model.setValue(100, for: .weight))
        model.selectSet(0, field: .weight, unit: .kilograms)
        model.typeNumber("")
        model.typeNumber("0.45")
        #expect(model.closeNumberEditor())
        #expect(model.values[0].weight == 99)
    }
}
