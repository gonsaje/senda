import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct TrainingSectionTests {
    private func enter(_ model: TrainingNotebookModel, weight: String, reps: String) throws {
        #expect(model.openDay(model.today)); #expect(model.addExercise("bench"))
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .weight)); model.typeInput(weight, focus: try #require(model.focus))
        #expect(model.selectInput(row.id, field: .reps)); model.typeInput(reps, focus: try #require(model.focus))
    }
    @Test func sectionSwitchFinishesValidSetAndKeepsDayContext() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model, weight: "135", reps: "10")
        #expect(model.personalRecords.isEmpty)
        let day = model.selectedDay
        #expect(model.selectSection(.profile))
        #expect(model.section == .profile && model.selectedDay == day && model.focus == nil)
        #expect(model.personalRecords.first?.reference.values == SetValues(weight: 13_500, reps: 10))
        #expect(model.selectSection(.learn)); #expect(model.selectSection(.log))
        #expect(model.rows.count == 1 && model.rows[0].weight == "135")
    }
    @Test func unfinishedInputSurvivesSectionSwitchAndReopeningOutsideProgress() throws {
        let store = MemoryJournalRepository()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model, weight: "31.", reps: "8")
        #expect(model.selectSection(.learn))
        #expect(model.personalRecords.isEmpty && model.bigThreeProgress.totalWeight == nil)
        let reopened = try TrainingNotebookModel(repository: store)
        #expect(reopened.rows[0].weight == "31." && reopened.rows[0].reps == "8")
        #expect(reopened.journal.batches.isEmpty)
    }
    @Test func failedSectionSwitchRetainsFocusAndRetryRecordsOnlyOnce() throws {
        let store = DockFailureStore()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model, weight: "135", reps: "10")
        let focus = model.focus
        store.reject = true
        #expect(!model.selectSection(.profile))
        #expect(model.section == .log && model.focus == focus && model.personalRecords.isEmpty)
        store.reject = false
        #expect(model.selectSection(.profile))
        #expect(model.journal.batches.count == 1)
        #expect(model.selectSection(.profile))
        #expect(model.journal.batches.count == 1)
    }
    @Test func defaultUnitDoesNotRewriteExistingDayOrCanonicalWeights() throws {
        let store = MemoryJournalRepository()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model, weight: "135", reps: "10"); #expect(model.finishEditing())
        #expect(model.setPreferredUnit(.kilograms))
        #expect(model.workspace.preferredUnit == .kilograms && model.unit == .pounds)
        #expect(model.personalRecords[0].reference.values.weight == 13_500)
        #expect(model.changeDay(1))
        #expect(model.unit == .kilograms)
        let reopened = try TrainingNotebookModel(repository: store)
        #expect(reopened.workspace.preferredUnit == .kilograms)
    }
    @Test func recordDrilldownOpensOriginalSetAndRestoresRemovedTab() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model, weight: "135", reps: "10"); #expect(model.finishEditing())
        let record = try #require(model.personalRecords.first)
        let rowID = try #require(model.rows.first).id
        #expect(model.removeExercise("bench"))
        #expect(model.selectSection(.profile))
        #expect(model.openPersonalRecord(record))
        #expect(model.section == .log && model.exercise?.id == "bench" && model.revealRowID == rowID)
        #expect(model.rows[0].performedSetID == record.reference.setID)
    }
}
@MainActor private final class DockFailureStore: JournalRepository {
    private var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated()
    }
}
