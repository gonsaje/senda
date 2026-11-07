import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct ExerciseReferenceTests {
    @Test func referencesChangeOnlyAfterRecordDoneAndUndo() throws {
        let store = MemoryJournalRepository(journal: try SampleJournal.make())
        let model = try LoggerModel(repository: store)
        let baseline = model.exerciseHistory
        #expect(baseline.personalBest?.values == SetValues(weight: 13_500, reps: 10))
        model.selectSet(0, field: .weight)
        model.typeNumber("200")
        #expect(model.applyNumberInput())
        #expect(model.exerciseHistory == baseline)
        #expect(model.record())
        #expect(model.exerciseHistory.personalBest?.values.weight == 20_000)
        model.selectSet(0, field: .weight)
        model.typeNumber("225")
        #expect(model.applyNumberInput())
        #expect(model.exerciseHistory.personalBest?.values.weight == 20_000)
        model.cancelEditing()
        #expect(model.exerciseHistory.personalBest?.values.weight == 20_000)
        model.selectSet(0, field: .weight)
        model.typeNumber("225")
        #expect(model.finishEditing())
        #expect(model.exerciseHistory.personalBest?.values.weight == 22_500)
        #expect(model.undo())
        #expect(model.exerciseHistory == baseline)
        let reopened = try LoggerModel(repository: store)
        #expect(reopened.exerciseHistory == baseline)
        reopened.selectExercise("deadlift")
        #expect(reopened.exerciseHistory.personalBest?.values.weight == 22_500)
        #expect(reopened.exerciseHistory.commonWorkingSet?.reps == 5...5)
    }

    @Test func failedHistoryWriteDoesNotPublishANewPr() throws {
        let store = ReferenceFailureStore(journal: try SampleJournal.make())
        let model = try LoggerModel(repository: store)
        let baseline = model.exerciseHistory
        model.selectSet(0, field: .weight)
        model.typeNumber("300")
        store.rejectWrites = true
        #expect(!model.record())
        #expect(model.exerciseHistory == baseline)
        store.rejectWrites = false
        #expect(model.record())
        let newBest = model.exerciseHistory
        model.selectSet(0, field: .weight)
        model.typeNumber("350")
        store.rejectWrites = true
        #expect(!model.finishEditing())
        #expect(model.exerciseHistory == newBest)
        store.rejectWrites = false
        #expect(model.finishEditing())
        #expect(model.exerciseHistory.personalBest?.values.weight == 35_000)
    }
}

@MainActor private final class ReferenceFailureStore: JournalRepository {
    private var snapshot: JournalSnapshot
    var rejectWrites = false
    init(journal: Journal) { snapshot = JournalSnapshot(journal: journal) }
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if rejectWrites { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated()
    }
}
