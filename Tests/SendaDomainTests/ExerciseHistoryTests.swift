import Foundation
import Testing
@testable import SendaDomain

struct ExerciseHistoryTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    @discardableResult private func add(_ journal: inout Journal, _ sets: [SetValues],
                                       exercise: String = "bench", seconds: Double = 0) throws -> RecordedBatch {
        try journal.record(DraftBatch(exerciseID: exercise, sets: sets), at: date.addingTimeInterval(seconds))
    }

    @Test func emptyHistoryHasNoInventedReferences() {
        let history = Journal().history(for: "bench")
        #expect(history.personalBest == nil)
        #expect(history.commonWorkingSet == nil)
    }

    @Test func topSetUsesWeightThenRepsAndTheLatestExactTie() throws {
        var journal = Journal()
        let batch = try add(&journal, [SetValues(weight: 13_500, reps: 20), SetValues(weight: 15_000, reps: 5),
            SetValues(weight: 15_000, reps: 8), SetValues(weight: 15_000, reps: 8)])
        #expect(batch.topSet == batch.sets[3])
        #expect(journal.history(for: "bench").personalBest?.setID == batch.sets[3].id)
    }

    @Test func personalBestIsExerciseSpecificAndUsesPerformanceDates() throws {
        var journal = Journal()
        let newest = try add(&journal, [SetValues(weight: 15_000, reps: 8)], seconds: 100)
        _ = try add(&journal, [SetValues(weight: 40_000, reps: 10)], exercise: "deadlift", seconds: 200)
        _ = try add(&journal, [SetValues(weight: 15_000, reps: 8)], seconds: -100)
        let best = try #require(journal.history(for: "bench").personalBest)
        #expect(best.batchID == newest.id)
        #expect(best.recordedAt == newest.recordedAt)
        #expect(best.values == SetValues(weight: 15_000, reps: 8))
        #expect(journal.history(for: "squat").personalBest == nil)
    }

    @Test func commonReferenceCountsIndividualSetsAndUsesTheirTypicalRepRange() throws {
        var journal = Journal()
        _ = try add(&journal, [SetValues(weight: 10_000, reps: 5), SetValues(weight: 15_000, reps: 3)]
            + [8, 9, 10, 11].map { SetValues(weight: 13_500, reps: $0) })
        let common = try #require(journal.history(for: "bench").commonWorkingSet)
        #expect(common.weight == 13_500)
        #expect(common.reps == 8...11)
        #expect(common.occurrenceCount == 4)
    }

    @Test func isolatedRepOutliersDoNotDominateTheCommonRange() throws {
        var journal = Journal()
        _ = try add(&journal, [1, 8, 8, 8, 10, 10, 10, 30].map { SetValues(weight: 13_500, reps: $0) })
        #expect(journal.history(for: "bench").commonWorkingSet?.reps == 8...10)
    }

    @Test func equalWeightFrequencyFavorsMostRecentPerformance() throws {
        var journal = Journal()
        _ = try add(&journal, Array(repeating: SetValues(weight: 20_000, reps: 5), count: 4), seconds: -100)
        let newest = try add(&journal, Array(repeating: SetValues(weight: 13_500, reps: 10), count: 4), seconds: 100)
        _ = try add(&journal, Array(repeating: SetValues(weight: 22_500, reps: 8), count: 4), seconds: -200)
        #expect(journal.history(for: "bench").commonWorkingSet?.weight == newest.values[0].weight)
        #expect(journal.history(for: "bench").commonWorkingSet?.reps == 10...10)
    }

    @Test func sparseHistoryHasAPrButNoCommonPatternUntilAWeightRepeats() throws {
        var journal = Journal()
        _ = try add(&journal, [SetValues(weight: 13_500, reps: 8), SetValues(weight: 15_000, reps: 5)])
        #expect(journal.history(for: "bench").personalBest != nil)
        #expect(journal.history(for: "bench").commonWorkingSet == nil)
        _ = try add(&journal, [SetValues(weight: 13_500, reps: 10)], seconds: 1)
        #expect(journal.history(for: "bench").commonWorkingSet?.reps == 8...10)
    }

    @Test func replayDoesNotInflateFrequencyButAnIntentionalIdenticalEntryDoes() throws {
        var journal = Journal()
        let request = DraftBatch(exerciseID: "bench", sets: Array(repeating: SetValues(weight: 100, reps: 10), count: 2))
        _ = try journal.record(request, at: date)
        _ = try journal.record(request, at: date)
        #expect(journal.history(for: "bench").commonWorkingSet?.occurrenceCount == 2)
        _ = try add(&journal, request.sets, seconds: 1)
        #expect(journal.history(for: "bench").commonWorkingSet?.occurrenceCount == 4)
    }

    @Test func correctionsAndUndoRecomputeReferencesFromSurvivingSets() throws {
        var journal = Journal()
        let first = try add(&journal, Array(repeating: SetValues(weight: 13_500, reps: 10), count: 4))
        let next = try add(&journal, Array(repeating: SetValues(weight: 15_000, reps: 5), count: 5), seconds: 100)
        #expect(journal.history(for: "bench").personalBest?.batchID == next.id)
        #expect(journal.history(for: "bench").commonWorkingSet?.weight == 15_000)
        let corrected = try journal.correct(batchID: next.id, revision: 1,
            sets: Array(repeating: SetValues(weight: 12_500, reps: 8), count: 2))
        #expect(journal.history(for: "bench").personalBest?.batchID == first.id)
        #expect(journal.history(for: "bench").commonWorkingSet?.weight == 13_500)
        _ = try journal.undo(batchID: first.id, revision: 1)
        #expect(journal.history(for: "bench").personalBest?.batchID == corrected.id)
        #expect(journal.history(for: "bench").commonWorkingSet?.reps == 8...8)
        _ = try journal.undo(batchID: corrected.id, revision: corrected.revision)
        #expect(journal.history(for: "bench").personalBest == nil)
        #expect(journal.history(for: "bench").commonWorkingSet == nil)
    }
}
