import Foundation
import Testing
@testable import SendaDomain

struct TrainingProgressTests {
    private func add(_ id: String, _ weight: Int, _ reps: Int, to journal: inout Journal) throws -> RecordedBatch {
        try journal.record(DraftBatch(exerciseID: id, sets: [SetValues(weight: weight, reps: reps)]), at: Date(timeIntervalSince1970: 1_790_000_000))
    }
    @Test func allRecordsUseWeightThenRepsAndIncludeCustomAndBodyweight() throws {
        var journal = Journal()
        _ = try add("bench", 13_500, 12, to: &journal)
        _ = try add("bench", 14_500, 6, to: &journal)
        let best = try add("bench", 14_500, 8, to: &journal)
        _ = try add("custom-row", 5_000, 10, to: &journal)
        _ = try add("push-up", 0, 20, to: &journal)
        #expect(journal.personalRecords.map(\.exerciseID) == ["bench", "custom-row", "push-up"])
        #expect(journal.personalRecords.first?.reference.setID == best.sets[0].id)
        #expect(journal.personalRecords.last?.reference.values == SetValues(weight: 0, reps: 20))
    }
    @Test func bigThreeUsesOnlyItsExactLiftsAndRequiresAllThree() throws {
        var journal = Journal()
        _ = try add("bench", 14_500, 8, to: &journal)
        _ = try add("deadlift", 22_500, 5, to: &journal)
        _ = try add("dumbbell-bench", 50_000, 1, to: &journal)
        #expect(journal.bigThreeProgress.records.count == 2)
        #expect(journal.bigThreeProgress.totalWeight == nil)
        _ = try add("squat", 18_500, 8, to: &journal)
        #expect(journal.bigThreeProgress.records.map(\.exerciseID) == ["bench", "deadlift", "squat"])
        #expect(journal.bigThreeProgress.totalWeight == 55_500)
    }
    @Test func correctionsRemovalAndRestorationRecomputeProgress() throws {
        var journal = Journal()
        _ = try add("bench", 13_500, 10, to: &journal)
        let best = try add("bench", 14_500, 8, to: &journal)
        _ = try journal.updateSet(best.sets[0].id, values: SetValues(weight: 15_500, reps: 5))
        #expect(journal.personalRecords[0].reference.values.weight == 15_500)
        let removed = try journal.removeSet(best.sets[0].id)
        #expect(journal.personalRecords[0].reference.values.weight == 13_500)
        _ = try journal.restoreSet(removed)
        #expect(journal.personalRecords[0].reference.values.weight == 15_500)
        #expect(journal.personalRecords[0].reference.setID == best.sets[0].id)
    }
    @Test func emptyAndZeroWeightRecordsAreDistinct() throws {
        var journal = Journal()
        #expect(journal.personalRecords.isEmpty)
        #expect(journal.bigThreeProgress.totalWeight == nil)
        for id in ["bench", "deadlift", "squat"] { _ = try add(id, 0, 1, to: &journal) }
        #expect(journal.bigThreeProgress.records.count == 3)
        #expect(journal.bigThreeProgress.totalWeight == 0)
    }
}
