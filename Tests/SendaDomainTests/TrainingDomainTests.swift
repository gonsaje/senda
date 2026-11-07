import Foundation
import Testing
@testable import SendaDomain

struct TrainingDomainTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/New_York")!
        return value
    }

    @Test func weeksAreMondayThroughSundayAcrossDaylightSaving() throws {
        let day = try TrainingDay("2026-03-08")
        #expect(try day.week().map(\.rawValue) == ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06", "2026-03-07", "2026-03-08"])
        let previous = try day.adding(days: -1)
        #expect(day.date(in: calendar).timeIntervalSince(previous.date(in: calendar)) == 23 * 3600)
        #expect(TrainingDay(day.date(in: calendar), calendar: calendar) == day)
        #expect(throws: (any Error).self) { try TrainingDay("2026-02-30") }
    }

    @Test func blankRowsDoNotBecomeZeroWeightSetsAndBodyweightNeedsOnlyReps() throws {
        let bench = Exercise.catalog.first { $0.id == "bench" }!
        let pushup = Exercise.catalog.first { $0.id == "push-up" }!
        var row = TrainingRow(unit: .pounds)
        #expect(row.parsed(for: bench) == nil)
        row.reps = "10"
        #expect(row.parsed(for: bench) == nil)
        #expect(row.parsed(for: pushup) == SetValues(weight: 0, reps: 10))
        row.weight = "0"; row.weightIsDirty = true
        #expect(row.parsed(for: bench) == SetValues(weight: 0, reps: 10))
        row.weight = "31."
        #expect(row.parsed(for: bench) == nil)
    }

    @Test func unitChangesPreserveCanonicalWeightAndRejectPartialNumbers() {
        var row = TrainingRow(weight: "1", reps: "10", unit: .pounds, canonicalWeight: 100)
        let toKg = row.changeUnit(to: .kilograms)
        #expect(toKg)
        #expect(row.weight == "0.45")
        #expect(row.parsed(for: Exercise.catalog[0])?.weight == 100)
        let toLb = row.changeUnit(to: .pounds)
        #expect(toLb)
        #expect(row.weight == "1")
        row.weight = "31."; row.weightIsDirty = true
        let partial = row.changeUnit(to: .kilograms)
        #expect(!partial)
        #expect(row.unit == .pounds)
        #expect(row.weight == "31.")
    }

    @Test func setDeletionUndoRetainsOrderedIdentitiesAndUnrelatedEntries() throws {
        var journal = Journal()
        let first = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 100, reps: 10), SetValues(weight: 200, reps: 8)]), at: Date())
        let removed = try journal.removeSet(first.sets[0].id)
        let other = try journal.record(DraftBatch(exerciseID: "squat", sets: [SetValues(weight: 300, reps: 5)]), at: Date())
        _ = try journal.restoreSet(removed)
        #expect(journal.batches.first { $0.id == first.id }?.sets.map(\.id) == first.sets.map(\.id))
        #expect(journal.batches.first { $0.id == first.id }?.values == first.values)
        #expect(journal.batches.contains(other))
        #expect(throws: (any Error).self) { try journal.restoreSet(removed) }
        _ = try journal.validated()
    }

    @Test func lastSetUndoRestoresItsIdentityWithoutReusingConsumedActions() throws {
        var journal = Journal()
        let draft = DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 100, reps: 10)])
        let batch = try journal.record(draft, at: Date())
        let removed = try journal.removeSet(batch.sets[0].id)
        #expect(journal.batches.isEmpty)
        #expect(throws: JournalError.actionUndone) { try journal.record(draft, at: Date()) }
        _ = try journal.restoreSet(removed)
        #expect(journal.batches[0].sets[0].id == batch.sets[0].id)
        #expect(journal.hasConsumedAction(draft.actionID))
        #expect(try journal.record(draft, at: Date()).id == batch.id)
        #expect(journal.batches.count == 1)
    }

    @Test func staleDeletionUndoCannotOverwriteLaterChanges() throws {
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 100, reps: 10), SetValues(weight: 200, reps: 8)]), at: Date())
        let removed = try journal.removeSet(batch.sets[0].id)
        _ = try journal.updateSet(batch.sets[1].id, values: SetValues(weight: 250, reps: 7))
        let unchanged = journal
        #expect(throws: JournalError.staleRevision) { try journal.restoreSet(removed) }
        #expect(journal == unchanged)
    }
}
