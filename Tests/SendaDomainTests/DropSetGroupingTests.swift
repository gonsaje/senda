import Foundation
import Testing
@testable import SendaDomain

struct DropSetGroupingTests {
    private let day = try! TrainingDay("2026-11-09")
    private func snapshot() throws -> JournalSnapshot {
        let group = UUID()
        let rows = [TrainingRow(unit: .pounds, kind: .dropSet, dropGroupID: group),
                    TrainingRow(unit: .pounds, kind: .dropSet, dropGroupID: group),
                    TrainingRow(unit: .pounds, kind: .working)]
        return JournalSnapshot(training: TrainingWorkspace(visibleWeek: day, selectedDay: day,
            days: [day.rawValue: DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": rows])]))
    }

    @Test func explicitGroupsKeepTheirOrderAndLegacyAdjacentDropsRemainSeparate() throws {
        let grouped = try snapshot()
        let rows = try #require(grouped.training?.days[day.rawValue]?.rows["bench"])
        let entries = TrainingSetEntry.grouping(rows)
        #expect(entries.count == 2 && entries[0].rows == Array(rows.prefix(2)))
        #expect(entries[0].id == rows[0].dropGroupID && entries[0].isDropSet)
        var legacy = rows
        for index in legacy.indices { legacy[index].dropGroupID = nil; legacy[index].kind = .dropSet }
        #expect(TrainingSetEntry.grouping(legacy).count == 3)
        #expect(try grouped.validated() == grouped)
    }

    @Test func groupsRejectSeparatedMembersMixedKindsAndCrossExerciseOrDayReuse() throws {
        let original = try snapshot()
        var separated = original
        separated.training!.days[day.rawValue]!.rows["bench"]!.swapAt(1, 2)
        #expect(throws: (any Error).self) { try separated.validated() }
        var wrongKind = original
        wrongKind.training!.days[day.rawValue]!.rows["bench"]![1].kind = .warmup
        #expect(throws: (any Error).self) { try wrongKind.validated() }
        let group = try #require(original.training?.days[day.rawValue]?.rows["bench"]?.first?.dropGroupID)
        var anotherExercise = original
        anotherExercise.training!.days[day.rawValue]!.rows["squat"] = [TrainingRow(unit: .pounds, kind: .dropSet, dropGroupID: group)]
        #expect(throws: (any Error).self) { try anotherExercise.validated() }
        var anotherDay = original
        anotherDay.training!.days["2026-11-10"] = DayWorkout(exerciseIDs: ["squat"], selectedExerciseID: "squat",
            rows: ["squat": [TrainingRow(unit: .pounds, kind: .dropSet, dropGroupID: group)]])
        #expect(throws: (any Error).self) { try anotherDay.validated() }
    }

    @Test func groupIdentityCannotCollideWithAnIndependentPerformedSet() throws {
        var value = try snapshot(), journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 100, reps: 10)]), at: Date())
        var recorded = TrainingRow(weight: "1", reps: "10", unit: .pounds, canonicalWeight: 100,
                                   performedSetID: batch.sets[0].id, kind: .working)
        recorded.actionID = batch.actionID
        value.journal = journal
        value.training!.days[day.rawValue]!.rows["bench"]![2] = recorded
        for index in 0...1 { value.training!.days[day.rawValue]!.rows["bench"]![index].dropGroupID = batch.sets[0].id }
        #expect(throws: (any Error).self) { try value.validated() }
    }

    @Test func deletedStageUndoMustRestoreAValidDropGroup() throws {
        var value = try snapshot()
        let row = value.training!.days[day.rawValue]!.rows["bench"]!.remove(at: 1)
        var invalid = row; invalid.kind = .working
        value.training!.undo = .deleted(day: day, exerciseID: "bench", index: 1, row: invalid, removal: nil)
        #expect(throws: (any Error).self) { try value.validated() }
        value.training!.undo = .deleted(day: day, exerciseID: "bench", index: 1, row: row, removal: nil)
        #expect(try value.validated() == value)
    }
}

struct GroupedSetRemovalTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    private func fixture() throws -> Journal {
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 100, reps: 10), SetValues(weight: 80, reps: 8), SetValues(weight: 60, reps: 6)]), at: date)
        _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 40, reps: 4), SetValues(weight: 20, reps: 2)]), at: date)
        _ = try journal.record(DraftBatch(exerciseID: "squat", sets: [SetValues(weight: 300, reps: 5)]), at: date)
        return journal
    }

    @Test func bulkRemovalAndUndoKeepSharedBatchIdentitiesValuesDatesAndUnrelatedHistory() throws {
        var journal = try fixture()
        let before = journal.batches
        let removedIDs = Array(before[0].sets.prefix(2).map(\.id)) + before[1].sets.map(\.id)
        let token = try journal.removeSets(removedIDs)
        #expect(token.batches.count == 2 && journal.batches.count == 2)
        #expect(journal.batches[0].sets.map(\.id) == [before[0].sets[2].id])
        #expect(journal.batches[0].revision == before[0].revision + 1)
        _ = try journal.restoreSets(token)
        #expect(journal.batches.map(\.id) == before.map(\.id))
        #expect(journal.batches.map(\.sets) == before.map(\.sets))
        #expect(journal.batches.map(\.recordedAt) == before.map(\.recordedAt))
        #expect(journal.batches[0].revision == 3 && journal.batches[1].revision == 3 && journal.batches[2] == before[2])
        let restored = journal
        #expect(throws: (any Error).self) { try journal.restoreSets(token) }
        #expect(journal == restored)
    }

    @Test func invalidBulkSelectionAndStaleSurvivorUndoAreAtomic() throws {
        var journal = try fixture()
        let before = journal, id = journal.batches[0].sets[0].id
        #expect(throws: (any Error).self) { try journal.removeSets([id, id]) }
        #expect(throws: (any Error).self) { try journal.removeSets([id, UUID()]) }
        #expect(journal == before)
        let token = try journal.removeSets([id, journal.batches[0].sets[1].id])
        _ = try journal.updateSet(journal.batches[0].sets[0].id, values: SetValues(weight: 70, reps: 7))
        let edited = journal
        #expect(throws: JournalError.staleRevision) { try journal.restoreSets(token) }
        #expect(journal == edited)
    }

    @Test func duplicateOriginalBatchPositionsCannotReorderRestoredHistory() throws {
        var journal = try fixture()
        let before = journal.batches
        let token = try journal.removeSets(before[0].sets.map(\.id) + before[1].sets.map(\.id))
        let malformed = RemovedTrainingSets(batches: token.batches.map {
            RemovedTrainingBatch(batch: $0.batch, batchIndex: 0, removedSetIDs: $0.removedSetIDs)
        })
        let deleted = journal
        #expect(throws: (any Error).self) { try journal.restoreSets(malformed) }
        #expect(journal == deleted)
    }
}
