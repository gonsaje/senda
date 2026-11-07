import Testing
import Foundation
@testable import SendaDomain

struct SetIdentityTests {
    @Test func removingMiddleSetRetainsIdentityOfRemainingOrderedSets() throws {
        var journal = Journal()
        let original = try journal.record(DraftBatch(exerciseID: "bench", sets: [10, 9, 8, 7].map {
            SetValues(weight: 13_500, reps: $0)
        }), at: Date())
        let retained = [original.sets[0], original.sets[2], original.sets[3]]
        let corrected = try journal.correct(batchID: original.id, revision: 1,
            sets: retained.map(\.values), retainedSetIDs: retained.map { Optional($0.id) })
        #expect(corrected.sets.map(\.id) == retained.map(\.id))
        #expect(corrected.sets.map(\.position) == [1, 2, 3])
    }

    @Test func correctionRejectsForeignOrDuplicateSetIDsAtomically() throws {
        var journal = Journal()
        let original = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 100, reps: 1)]), at: Date())
        let before = journal
        #expect(throws: (any Error).self) {
            try journal.correct(batchID: original.id, revision: 1, sets: original.values, retainedSetIDs: [UUID()])
        }
        #expect(throws: (any Error).self) {
            try journal.correct(batchID: original.id, revision: 1, sets: original.values + original.values,
                                retainedSetIDs: [original.sets[0].id, original.sets[0].id])
        }
        #expect(journal == before)
    }
}
