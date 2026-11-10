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

public extension Journal {
    mutating func removeSets(_ ids: [UUID]) throws -> RemovedTrainingSets {
        let selected = Set(ids)
        guard selected.count == ids.count else { throw JournalError.invalidSets }
        let removals = batches.enumerated().compactMap { index, batch -> RemovedTrainingBatch? in
            let removed = batch.sets.filter { selected.contains($0.id) }.map(\.id)
            return removed.isEmpty ? nil : RemovedTrainingBatch(batch: batch, batchIndex: index, removedSetIDs: removed)
        }
        guard removals.reduce(0, { $0 + $1.removedSetIDs.count }) == ids.count else { throw JournalError.missingBatch }
        var candidate = self
        for removal in removals {
            let batch = removal.batch
            guard batch.revision < Int.max - 1 else { throw JournalError.staleRevision }
            let removed = Set(removal.removedSetIDs)
            let kept = batch.sets.filter { !removed.contains($0.id) }
            if kept.isEmpty { _ = try candidate.undo(batchID: batch.id, revision: batch.revision) }
            else {
                _ = try candidate.correct(batchID: batch.id, revision: batch.revision,
                                          sets: kept.map(\.values), retainedSetIDs: kept.map { Optional($0.id) })
            }
        }
        _ = try candidate.validated()
        self = candidate
        return RemovedTrainingSets(batches: removals)
    }

    @discardableResult mutating func restoreSets(_ token: RemovedTrainingSets) throws -> [PerformedSet] {
        guard Set(token.batches.map { $0.batch.id }).count == token.batches.count,
              Set(token.batches.map(\.batchIndex)).count == token.batches.count else { throw JournalError.actionConflict }
        var removedIDs = Set<UUID>()
        for removal in token.batches {
            let original = removal.batch
            let selected = Set(removal.removedSetIDs)
            guard removal.batchIndex >= 0, original.revision > 0, original.revision < Int.max - 1,
                  !selected.isEmpty, selected.count == removal.removedSetIDs.count,
                  selected.isSubset(of: Set(original.sets.map(\.id))),
                  !original.sets.isEmpty, Set(original.sets.map(\.id)).count == original.sets.count,
                  original.sets.map(\.position) == Array(1...original.sets.count),
                  original.recordedAt.timeIntervalSince1970.isFinite,
                  let receipt = receipts.first(where: { $0.batchID == original.id }),
                  receipt.request.actionID == original.actionID,
                  receipt.request.exerciseID == original.exerciseID else { throw JournalError.actionConflict }
            try SetValidation.validate(original.values)
            for id in selected {
                guard removedIDs.insert(id).inserted, reference(to: id) == nil else { throw JournalError.actionConflict }
            }
            let kept = original.sets.filter { !selected.contains($0.id) }
            if kept.isEmpty {
                guard !batches.contains(where: { $0.id == original.id }), receipt.undone else { throw JournalError.staleRevision }
            } else {
                let expected = RecordedBatch(id: original.id, actionID: original.actionID, exerciseID: original.exerciseID,
                    recordedAt: original.recordedAt, revision: original.revision + 1, sets: kept.enumerated().map {
                        PerformedSet(id: $0.element.id, position: $0.offset + 1, values: $0.element.values)
                    })
                guard !receipt.undone, batches.first(where: { $0.id == original.id }) == expected else { throw JournalError.staleRevision }
            }
        }
        var candidate = self
        for removal in token.batches.sorted(by: { $0.batchIndex < $1.batchIndex }) {
            let old = removal.batch
            let restored = RecordedBatch(id: old.id, actionID: old.actionID, exerciseID: old.exerciseID,
                recordedAt: old.recordedAt, revision: old.revision + 2, sets: old.sets)
            if let index = candidate.batches.firstIndex(where: { $0.id == old.id }) { candidate.batches[index] = restored }
            else { candidate.batches.insert(restored, at: min(removal.batchIndex, candidate.batches.count)) }
            let receipt = candidate.receipts.firstIndex(where: { $0.batchID == old.id })!
            candidate.receipts[receipt].undone = false
        }
        _ = try candidate.validated()
        self = candidate
        return token.batches.flatMap { removal in removal.batch.sets.filter { removal.removedSetIDs.contains($0.id) } }
    }

    @discardableResult mutating func updateSet(_ id: UUID, values: SetValues) throws -> PerformedSet {
        guard let source = reference(to: id) else { throw JournalError.missingBatch }
        guard source.set.values != values else { return source.set }
        var rows = source.batch.values
        rows[source.set.position - 1] = values
        let batch = try correct(batchID: source.batch.id, revision: source.batch.revision, sets: rows,
                                retainedSetIDs: source.batch.sets.map { Optional($0.id) })
        return batch.sets[source.set.position - 1]
    }
    mutating func removeSet(_ id: UUID) throws -> RemovedTrainingSet {
        guard let index = batches.firstIndex(where: { $0.sets.contains { $0.id == id } }),
              let set = batches[index].sets.first(where: { $0.id == id }) else { throw JournalError.missingBatch }
        let batch = batches[index]
        guard batch.revision < Int.max - 1 else { throw JournalError.staleRevision }
        let removal = RemovedTrainingSet(batch: batch, set: set, batchIndex: index)
        let kept = batch.sets.filter { $0.id != id }
        if kept.isEmpty { _ = try undo(batchID: batch.id, revision: batch.revision) }
        else { _ = try correct(batchID: batch.id, revision: batch.revision, sets: kept.map(\.values), retainedSetIDs: kept.map { Optional($0.id) }) }
        return removal
    }
    @discardableResult mutating func restoreSet(_ removal: RemovedTrainingSet) throws -> PerformedSet {
        let old = removal.batch
        guard removal.batchIndex >= 0, old.revision < Int.max - 1,
              old.sets.contains(removal.set), reference(to: removal.set.id) == nil,
              let receiptIndex = receipts.firstIndex(where: { $0.batchID == old.id }),
              receipts[receiptIndex].request.actionID == old.actionID,
              receipts[receiptIndex].request.exerciseID == old.exerciseID else { throw JournalError.actionConflict }
        try SetValidation.validate(old.values)
        if let index = batches.firstIndex(where: { $0.id == old.id }) {
            let current = batches[index]
            guard !receipts[receiptIndex].undone, current.revision == old.revision + 1 else { throw JournalError.staleRevision }
            var restored = current.sets
            restored.insert(removal.set, at: min(max(0, removal.set.position - 1), restored.count))
            try SetValidation.validate(restored.map(\.values))
            batches[index] = RecordedBatch(id: old.id, actionID: old.actionID, exerciseID: old.exerciseID,
                recordedAt: old.recordedAt, revision: current.revision + 1, sets: restored.enumerated().map {
                    PerformedSet(id: $0.element.id, position: $0.offset + 1, values: $0.element.values)
                })
        } else {
            guard receipts[receiptIndex].undone, old.sets.count == 1 else { throw JournalError.staleRevision }
            batches.insert(RecordedBatch(id: old.id, actionID: old.actionID, exerciseID: old.exerciseID,
                recordedAt: old.recordedAt, revision: old.revision + 2, sets: old.sets), at: min(removal.batchIndex, batches.count))
            receipts[receiptIndex].undone = false
        }
        return removal.set
    }
}
