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
    @Test func sectionSwitchClosesEditingAndKeepsAutomaticallySavedSetAndDayContext() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model, weight: "135", reps: "10")
        #expect(model.personalRecords.first?.reference.values == SetValues(weight: 13_500, reps: 10))
        let day = model.selectedDay, setID = try #require(model.rows.first?.performedSetID)
        #expect(model.focus != nil)
        #expect(model.selectSection(.profile))
        #expect(model.section == .profile && model.selectedDay == day && model.focus == nil)
        #expect(model.personalRecords.first?.reference.values == SetValues(weight: 13_500, reps: 10))
        #expect(model.selectSection(.learn)); #expect(model.selectSection(.log))
        #expect(model.rows.count == 1 && model.rows[0].weight == "135")
        #expect(model.rows[0].performedSetID == setID)
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
    @Test func failedSectionSwitchRetainsSavedRecordAndFocusThenRetryClosesEditing() throws {
        let store = DockFailureStore()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model, weight: "135", reps: "10")
        let focus = model.focus, saved = try store.loadSnapshot(), setID = model.rows.first?.performedSetID
        store.reject = true
        #expect(!model.selectSection(.profile))
        #expect(model.section == .log && model.focus == focus)
        #expect(model.personalRecords.first?.reference.values == SetValues(weight: 13_500, reps: 10))
        #expect(try store.loadSnapshot() == saved)
        store.reject = false
        #expect(model.selectSection(.profile))
        #expect(model.journal.batches.count == 1 && model.rows.first?.performedSetID == setID && model.focus == nil)
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
    @Test func preferenceRetryAppliesTheRejectedUnitWithoutChangingWeights() throws {
        let store = DockFailureStore()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model, weight: "135", reps: "10"); #expect(model.finishEditing())
        store.reject = true
        #expect(!model.setPreferredUnit(.kilograms))
        #expect(model.workspace.preferredUnit == .pounds)
        store.reject = false
        #expect(model.retryProfileAction())
        #expect(model.workspace.preferredUnit == .kilograms)
        #expect(model.personalRecords[0].reference.values.weight == 13_500)
        #expect(try TrainingNotebookModel(repository: store).workspace.preferredUnit == .kilograms)
    }
    @Test func recordRetryOpensReadOnlySourceWithoutMovingTheWorkout() throws {
        let store = DockFailureStore()
        let model = try TrainingNotebookModel(repository: store)
        try enter(model, weight: "135", reps: "10"); #expect(model.finishEditing())
        let sourceDay = model.selectedDay
        let record = try #require(model.personalRecords.first)
        #expect(model.changeDay(1)); #expect(model.addExercise("squat"))
        let currentDay = model.selectedDay
        #expect(model.selectInput(try #require(model.rows.first).id, field: .weight))
        model.typeInput("31.", focus: try #require(model.focus))
        store.reject = true
        #expect(!model.openPersonalRecord(record))
        #expect(!model.isProgressPresented && model.selectedDay == currentDay)
        store.reject = false
        #expect(model.retryProfileAction())
        #expect(model.isProgressPresented && model.selectedDay == currentDay && model.progressSessionDay == sourceDay)
        #expect(model.exercise?.id == "squat" && model.rows.first?.weight == "31." && model.journal.batches.count == 1)
        #expect(model.errorMessage == nil)
    }
    @Test func recordDrilldownRestoresRemovedTabOnlyWhenExplicitlyEditing() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        try enter(model, weight: "135", reps: "10"); #expect(model.finishEditing())
        let record = try #require(model.personalRecords.first)
        let rowID = try #require(model.rows.first).id
        #expect(model.removeExercise("bench"))
        #expect(model.selectSection(.profile))
        #expect(model.openPersonalRecord(record))
        #expect(model.section == .profile && model.isProgressPresented && model.exercise == nil)
        #expect(model.progressSetID == record.reference.setID)
        #expect(model.editRecordedSession(for: "bench", on: try #require(model.progressSessionDay), setID: record.reference.setID))
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
