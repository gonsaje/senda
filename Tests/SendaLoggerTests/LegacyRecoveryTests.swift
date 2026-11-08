import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct LegacyRecoveryTests {
    private func original() throws -> JournalSnapshot {
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]), at: Date())
        var edit = SetEditSession(source: .recorded(batch.id), revision: 1, sets: batch.values)
        edit.inputs[0].weight = "31."; edit.inputs[0].weightIsDirty = true
        return JournalSnapshot(journal: journal, workspace: EntryWorkspace(sessions: ["bench": .recorded(batch.id)], editor: edit))
    }
    @Test func openGroupEditorKeepsPartialInputUntilExplicitResolution() throws {
        let source = try original()
        let store = try MemoryJournalRepository(snapshot: source)
        let recovery = try LegacyRecoveryModel(repository: store)
        let logger = try #require(recovery.logger)
        #expect(logger.editor?.inputs[0].weight == "31.")
        #expect(!logger.canConfirmSetEdits)
        #expect(try store.loadSnapshot() == source)
        logger.typeEditedSet(at: 0, field: .weight, text: "140")
        #expect(logger.confirmSetEdits())
        #expect(recovery.accept())
        #expect(recovery.isComplete)
        #expect(try store.loadSnapshot().journal.batches[0].values[0].weight == 14_000)
        #expect(try store.loadSnapshot().workspace?.editor == nil)
    }
    @Test func reviewInputSurvivesReopeningBeforeConfirmation() throws {
        let source = try original()
        let store = try MemoryJournalRepository(snapshot: source)
        let recovery = try LegacyRecoveryModel(repository: store)
        let logger = try #require(recovery.logger)
        logger.typeEditedSet(at: 0, field: .weight, text: "14.")
        #expect(recovery.flushRecovery())
        let reopened = try LegacyRecoveryModel(repository: store)
        #expect(reopened.logger?.editor?.inputs[0].weight == "14.")
        #expect(try store.loadSnapshot().journal == source.journal)
    }
    @Test func cancellingRecoveredEditorLeavesPerformedHistoryUntouched() throws {
        let source = try original()
        let store = try MemoryJournalRepository(snapshot: source)
        let recovery = try LegacyRecoveryModel(repository: store)
        #expect(recovery.discard())
        #expect(recovery.isComplete)
        #expect(try store.loadSnapshot().journal == source.journal)
    }
    @Test func failedRecoveryResolutionCanRetryWithoutDoubleCorrection() throws {
        let source = try original()
        let store = LegacyFailureStore(source)
        let recovery = try LegacyRecoveryModel(repository: store)
        let logger = try #require(recovery.logger)
        logger.typeEditedSet(at: 0, field: .weight, text: "140")
        #expect(logger.confirmSetEdits())
        store.reject = true
        #expect(!recovery.accept())
        #expect(!recovery.isComplete)
        #expect(try store.loadSnapshot() == source)
        store.reject = false
        #expect(recovery.accept())
        #expect(try store.loadSnapshot().journal.batches[0].revision == 2)
    }
}
@MainActor private final class LegacyFailureStore: JournalRepository {
    var snapshot: JournalSnapshot
    var reject = false
    init(_ snapshot: JournalSnapshot) { self.snapshot = snapshot }
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ candidate: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try candidate.validated()
    }
}
