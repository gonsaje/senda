import Foundation
import SendaDomain

var journal = try SampleJournal.make()
let previousCount = journal.batches.count
let draft = DraftBatch(exerciseID: "bench", sets: [10, 10, 10, 8].map { SetValues(weight: 13_500, reps: $0) })
let batch = try journal.record(draft, at: Date())
print("Draft recorded as individual sets:", batch.sets.map { "\($0.position): 135 lb × \($0.values.reps)" }.joined(separator: ", "))
_ = try journal.record(draft, at: Date())
precondition(journal.batches.count == previousCount + 1)
print("Replaying the save action added no duplicate.")
if let difference = journal.comparison(for: batch.id)?.repDifferenceAtSameWeight {
    print("Comparison: \(abs(difference)) fewer reps at the same weight.")
}
let recovered = try journal.undo(batchID: batch.id, revision: batch.revision)
precondition(journal.batches.count == previousCount)
print("Undo returned \(recovered.sets.count) unrecorded sets with a fresh action ID.")
print("Sample only. No files were written.")
