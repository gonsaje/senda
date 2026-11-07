import Foundation

struct ActionReceipt: Codable, Equatable, Sendable {
    let request: DraftBatch
    let batchID: UUID
    var undone: Bool
}

/// Pure domain state. Commands validate complete candidates before mutating anything.
public struct Journal: Codable, Equatable, Sendable {
    public private(set) var batches: [RecordedBatch] = []
    private var receipts: [ActionReceipt] = []

    public init() {}

    public mutating func record(_ draft: DraftBatch, at date: Date) throws -> RecordedBatch {
        if let receipt = receipts.first(where: { $0.request.actionID == draft.actionID }) {
            guard receipt.request == draft else { throw JournalError.actionConflict }
            guard !receipt.undone else { throw JournalError.actionUndone }
            guard let batch = batches.first(where: { $0.id == receipt.batchID }) else {
                throw JournalError.corruptJournal
            }
            return batch
        }
        try Self.validate(draft)
        guard date.timeIntervalSince1970.isFinite else { throw JournalError.corruptJournal }
        let batch = RecordedBatch(id: UUID(), actionID: draft.actionID, exerciseID: draft.exerciseID,
            recordedAt: date, revision: 1, sets: draft.sets.enumerated().map {
                PerformedSet(id: UUID(), position: $0.offset + 1, values: $0.element)
            })
        batches.append(batch)
        receipts.append(ActionReceipt(request: draft, batchID: batch.id, undone: false))
        return batch
    }

    public mutating func correct(batchID: UUID, revision: Int, sets: [SetValues], retainedSetIDs: [UUID?]? = nil) throws -> RecordedBatch {
        guard let index = batches.firstIndex(where: { $0.id == batchID }) else { throw JournalError.missingBatch }
        let old = batches[index]
        guard old.revision == revision, revision < Int.max else { throw JournalError.staleRevision }
        try SetValidation.validate(sets)
        if let retainedSetIDs {
            let retained = retainedSetIDs.compactMap { $0 }
            guard retainedSetIDs.count == sets.count, Set(retained).count == retained.count,
                  Set(retained).isSubset(of: Set(old.sets.map(\.id))) else { throw JournalError.invalidSets }
        }
        let corrected = RecordedBatch(id: old.id, actionID: old.actionID, exerciseID: old.exerciseID,
            recordedAt: old.recordedAt, revision: old.revision + 1, sets: sets.enumerated().map {
                let id: UUID
                if let retainedSetIDs { id = retainedSetIDs[$0.offset] ?? UUID() }
                else { id = $0.offset < old.sets.count ? old.sets[$0.offset].id : UUID() }
                return PerformedSet(id: id, position: $0.offset + 1, values: $0.element)
            })
        batches[index] = corrected
        return corrected
    }

    public mutating func undo(batchID: UUID, revision: Int) throws -> DraftBatch {
        guard let index = batches.firstIndex(where: { $0.id == batchID }) else { throw JournalError.missingBatch }
        let batch = batches[index]
        guard batch.revision == revision else { throw JournalError.staleRevision }
        guard let receiptIndex = receipts.firstIndex(where: { $0.batchID == batchID }) else {
            throw JournalError.corruptJournal
        }
        batches.remove(at: index)
        // Retain the receipt so a delayed delivery cannot resurrect an undone action.
        receipts[receiptIndex].undone = true
        return DraftBatch(exerciseID: batch.exerciseID, sets: batch.values)
    }

    public func entries(for exerciseID: String) -> [RecordedBatch] {
        batches.enumerated().filter { $0.element.exerciseID == exerciseID }.sorted {
            if $0.element.recordedAt == $1.element.recordedAt { return $0.offset < $1.offset }
            return $0.element.recordedAt < $1.element.recordedAt
        }.map(\.element)
    }

    public func hasConsumedAction(_ actionID: UUID) -> Bool { receipts.contains { $0.request.actionID == actionID } }

    public func comparison(for batchID: UUID) -> EntryComparison? {
        guard let batch = batches.first(where: { $0.id == batchID }) else { return nil }
        let entries = entries(for: batch.exerciseID)
        guard let index = entries.firstIndex(where: { $0.id == batchID }), index > 0 else { return nil }
        return EntryComparison(previous: entries[index - 1], current: batch)
    }

    /// Decoding is not validation: enforce invariants at a persistence boundary, too.
    public func validated() throws -> Journal {
        guard Set(batches.map(\.id)).count == batches.count,
              Set(receipts.map(\.batchID)).count == receipts.count,
              Set(receipts.map(\.request.actionID)).count == receipts.count else {
            throw JournalError.corruptJournal
        }
        var setIDs = Set<UUID>()
        for batch in batches {
            try SetValidation.validate(batch.values)
            guard batch.revision > 0, batch.recordedAt.timeIntervalSince1970.isFinite,
                  batch.sets.map(\.position) == Array(1...batch.sets.count),
                  let receipt = receipts.first(where: { $0.batchID == batch.id }),
                  !receipt.undone, receipt.request.actionID == batch.actionID,
                  receipt.request.exerciseID == batch.exerciseID else { throw JournalError.corruptJournal }
            for set in batch.sets {
                guard setIDs.insert(set.id).inserted else { throw JournalError.corruptJournal }
            }
        }
        for receipt in receipts {
            try Self.validate(receipt.request)
            guard receipt.undone == !batches.contains(where: { $0.id == receipt.batchID }) else {
                throw JournalError.corruptJournal
            }
        }
        return self
    }

    private static func validate(_ draft: DraftBatch) throws {
        guard !draft.exerciseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              draft.exerciseID.count <= 80 else { throw JournalError.invalidExercise }
        try SetValidation.validate(draft.sets)
    }
}
