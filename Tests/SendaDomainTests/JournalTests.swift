import Testing
import Foundation
@testable import SendaDomain

struct JournalTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    private func draft(_ reps: [Int] = [10, 10, 10, 8], actionID: UUID = UUID()) -> DraftBatch {
        DraftBatch(actionID: actionID, exerciseID: "bench", sets: reps.map { SetValues(weight: 13_500, reps: $0) })
    }

    @Test func testBatchCommitsIndividualSetsInOrder() throws {
        var journal = Journal()
        let batch = try journal.record(draft(), at: date)
        #expect(batch.sets.map(\.position) == [1, 2, 3, 4])
        #expect(batch.sets.map(\.values.reps) == [10, 10, 10, 8])
        #expect(Set(batch.sets.map(\.id)).count == 4)
        #expect(journal.batches == [batch])
    }

    @Test func testInvalidExceptionRejectsEntireBatch() throws {
        var journal = Journal()
        let before = journal
        #expect(throws: (any Error).self) { try journal.record(draft([10, 10, 10, 0]), at: date) }
        #expect(journal == before)
        for sets in [[], [SetValues(weight: -1, reps: 10)], [SetValues(weight: 0, reps: 1000)],
                     Array(repeating: SetValues(weight: 100, reps: 1), count: 31)] {
            #expect(throws: (any Error).self) { try journal.record(DraftBatch(exerciseID: "bench", sets: sets), at: date) }
            #expect(journal == before)
        }
    }

    @Test func testActionReplayIsIdempotentButAnotherBatchCanBeIdentical() throws {
        var journal = Journal()
        let request = draft()
        let first = try journal.record(request, at: date)
        #expect(try journal.record(request, at: date.addingTimeInterval(1)) == first)
        #expect(journal.batches.count == 1)
        let second = try journal.record(draft(), at: date.addingTimeInterval(2))
        #expect(first.id != second.id)
        #expect(journal.batches.count == 2)
    }

    @Test func testSameActionWithDifferentContentIsRejected() throws {
        var journal = Journal()
        let request = draft()
        _ = try journal.record(request, at: date)
        let before = journal
        #expect(throws: (any Error).self) { try journal.record(draft([8], actionID: request.actionID), at: date) }
        #expect(journal == before)
    }

    @Test func testCorrectionIsAtomicAndKeepsSetIdentity() throws {
        var journal = Journal()
        let batch = try journal.record(draft([10, 10, 10, 10]), at: date)
        let corrected = try journal.correct(batchID: batch.id, revision: 1, sets: draft().sets)
        #expect(corrected.sets.map(\.id) == batch.sets.map(\.id))
        #expect(corrected.sets.map(\.values.reps) == [10, 10, 10, 8])
        #expect(corrected.revision == 2)
        let before = journal
        #expect(throws: (any Error).self) { try journal.correct(batchID: batch.id, revision: 1, sets: draft().sets) }
        #expect(throws: (any Error).self) { try journal.correct(batchID: batch.id, revision: 2, sets: draft([0]).sets) }
        #expect(journal == before)
    }

    @Test func testUndoRemovesOnlyTargetAndReturnsCorrectedValuesAsFreshDraft() throws {
        var journal = Journal()
        let request = draft([10, 10, 10, 10])
        let first = try journal.record(request, at: date)
        let other = try journal.record(draft([5]), at: date)
        let corrected = try journal.correct(batchID: first.id, revision: 1, sets: draft().sets)
        let recovered = try journal.undo(batchID: first.id, revision: corrected.revision)
        #expect(journal.batches == [other])
        #expect(recovered.sets == draft().sets)
        #expect(recovered.actionID != request.actionID)
        #expect(throws: (any Error).self) { try journal.record(request, at: date) }
        _ = try journal.record(recovered, at: date)
        #expect(journal.batches.count == 2)
    }

    @Test func testStaleUndoCannotRemoveCorrection() throws {
        var journal = Journal()
        let batch = try journal.record(draft(), at: date)
        _ = try journal.correct(batchID: batch.id, revision: 1, sets: draft([8]).sets)
        let before = journal
        #expect(throws: (any Error).self) { try journal.undo(batchID: batch.id, revision: 1) }
        #expect(journal == before)
    }

    @Test func testComparisonUsesActualSameLiftEntriesAndRespectsDifferentLoads() throws {
        var journal = Journal()
        let first = try journal.record(draft([10, 10, 10, 10]), at: date)
        _ = try journal.record(DraftBatch(exerciseID: "deadlift", sets: [SetValues(weight: 22_500, reps: 5)]),
                               at: date.addingTimeInterval(5))
        let second = try journal.record(draft(), at: date.addingTimeInterval(10))
        let comparison = try #require(journal.comparison(for: second.id))
        #expect(comparison.previous == first)
        #expect(comparison.repDifferenceAtSameWeight == -2)
        let mixed = try journal.correct(batchID: second.id, revision: 1,
            sets: [SetValues(weight: 15_500, reps: 10)])
        #expect(journal.comparison(for: mixed.id)?.repDifferenceAtSameWeight == nil)
        #expect(journal.comparison(for: first.id) == nil)
    }

    @Test func rejectsMissingExerciseAndNonFiniteDateWithoutConsumingAction() throws {
        var journal = Journal()
        let request = draft()
        #expect(throws: JournalError.invalidExercise) {
            try journal.record(DraftBatch(exerciseID: " ", sets: request.sets), at: date)
        }
        #expect(throws: JournalError.corruptJournal) {
            try journal.record(request, at: Date(timeIntervalSince1970: .infinity))
        }
        #expect(journal.batches.isEmpty)
        _ = try journal.record(request, at: date)
        #expect(journal.batches.count == 1)
    }

    @Test func decodedJournalRejectsBrokenOrderAndReceiptLinks() throws {
        var journal = Journal()
        _ = try journal.record(draft(), at: date)
        let encoded = try JSONEncoder().encode(journal)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var batches = try #require(object["batches"] as? [[String: Any]])
        var sets = try #require(batches[0]["sets"] as? [[String: Any]])
        sets[3]["position"] = 1
        batches[0]["sets"] = sets
        object["batches"] = batches
        let badOrder = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(throws: JournalError.corruptJournal) { try badOrder.validated() }
        object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["receipts"] = []
        let missingReceipt = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(throws: JournalError.corruptJournal) { try missingReceipt.validated() }
    }
}
