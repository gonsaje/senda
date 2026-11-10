import Testing
import SendaDomain
@testable import SendaNotebook

struct TrainingTrendFeedbackTests {
    private let bench = Exercise(id: "bench", name: "Bench", shortName: "Bench", startingWeight: 13_500)
    private let pullUp = Exercise(id: "pull-up", name: "Pull-up", shortName: "Pull-up", startingWeight: 0)

    @Test func mixedChangesDescribeBothDifferencesWithoutCallingEitherAnImprovement() {
        for (weight, reps, statement) in [
            (14_500, 3, "10 lb more · 2 fewer reps"),
            (12_500, 7, "10 lb less · 2 more reps"),
            (14_500, 7, "10 lb more · 2 more reps"),
            (12_500, 3, "10 lb less · 2 fewer reps")
        ] {
            let feedback = TrainingTrendFeedback.make(comparison: .differentSets,
                latest: SetValues(weight: weight, reps: reps), previous: SetValues(weight: 13_500, reps: 5),
                exercise: bench, unit: .pounds)
            #expect(feedback == TrainingTrendFeedback(text: statement, symbol: "arrow.left.arrow.right", positive: false))
        }
    }

    @Test func sameLoadDescribesMoreAndFewerRepsIncludingSingular() {
        for (reps, statement, symbol, positive) in [
            (7, "2 more reps at 135 lb", "arrow.up", true),
            (4, "1 fewer rep at 135 lb", "arrow.down", false)
        ] {
            let feedback = TrainingTrendFeedback.make(comparison: .repsAtSameWeight(delta: reps - 5, weight: 13_500),
                latest: SetValues(weight: 13_500, reps: reps), previous: SetValues(weight: 13_500, reps: 5),
                exercise: bench, unit: .pounds)
            #expect(feedback == TrainingTrendFeedback(text: statement, symbol: symbol, positive: positive))
        }
    }

    @Test func sameRepsDescribesLoadChangeInSelectedUnit() {
        for (weight, unit, statement, symbol, positive) in [
            (14_500, WeightUnit.pounds, "10 lb more for 5 reps", "arrow.up", true),
            (12_500, .pounds, "10 lb less for 5 reps", "arrow.down", false),
            (14_500, .kilograms, "4.54 kg more for 5 reps", "arrow.up", true),
            (12_500, .kilograms, "4.54 kg less for 5 reps", "arrow.down", false)
        ] {
            let feedback = TrainingTrendFeedback.make(comparison: .weightAtSameReps(delta: weight - 13_500, reps: 5),
                latest: SetValues(weight: weight, reps: 5), previous: SetValues(weight: 13_500, reps: 5),
                exercise: bench, unit: unit)
            #expect(feedback == TrainingTrendFeedback(text: statement, symbol: symbol, positive: positive))
        }
    }

    @Test func kilogramDeltaUsesCanonicalDifferenceInsteadOfSubtractingRoundedLoads() {
        let feedback = TrainingTrendFeedback.make(comparison: .weightAtSameReps(delta: 3, reps: 1),
            latest: SetValues(weight: 4, reps: 1), previous: SetValues(weight: 1, reps: 1),
            exercise: bench, unit: .kilograms)
        #expect(feedback.text == "0.01 kg more for 1 rep")
    }

    @Test func sameWeightRepFeedbackUsesSelectedKilograms() {
        let feedback = TrainingTrendFeedback.make(comparison: .repsAtSameWeight(delta: 1, weight: 13_500),
            latest: SetValues(weight: 13_500, reps: 6), previous: SetValues(weight: 13_500, reps: 5),
            exercise: bench, unit: .kilograms)
        #expect(feedback.text == "1 more rep at 61.23 kg")
    }

    @Test func bodyweightComparisonsIdentifyAddedLoad() {
        let fewerAddedPounds = TrainingTrendFeedback.make(comparison: .weightAtSameReps(delta: -2_500, reps: 5),
            latest: SetValues(weight: 0, reps: 5), previous: SetValues(weight: 2_500, reps: 5),
            exercise: pullUp, unit: .pounds)
        #expect(fewerAddedPounds.text == "25 lb less added weight for 5 reps")
        let mixedAddedKilograms = TrainingTrendFeedback.make(comparison: .differentSets,
            latest: SetValues(weight: 3_500, reps: 6), previous: SetValues(weight: 2_500, reps: 5),
            exercise: pullUp, unit: .kilograms)
        #expect(mixedAddedKilograms == TrainingTrendFeedback(text: "4.54 kg more added weight · 1 more rep",
            symbol: "arrow.left.arrow.right", positive: false))
        let bodyweightReps = TrainingTrendFeedback.make(comparison: .repsAtSameWeight(delta: 1, weight: 0),
            latest: SetValues(weight: 0, reps: 6), previous: SetValues(weight: 0, reps: 5),
            exercise: pullUp, unit: .pounds)
        #expect(bodyweightReps.text == "1 more rep at BW")
        let addedWeightReps = TrainingTrendFeedback.make(comparison: .repsAtSameWeight(delta: -1, weight: 2_500),
            latest: SetValues(weight: 2_500, reps: 4), previous: SetValues(weight: 2_500, reps: 5),
            exercise: pullUp, unit: .pounds)
        #expect(addedWeightReps.text == "1 fewer rep at BW + 25 lb")
    }

    @Test func tinyKilogramChangesStayNonzeroInBothDirections() {
        for (latest, previous, statement, symbol, positive) in [
            (1, 0, "Less than 0.01 kg more for 5 reps", "arrow.up", true),
            (0, 1, "Less than 0.01 kg less for 5 reps", "arrow.down", false)
        ] {
            let feedback = TrainingTrendFeedback.make(comparison: .weightAtSameReps(delta: latest - previous, reps: 5),
                latest: SetValues(weight: latest, reps: 5), previous: SetValues(weight: previous, reps: 5),
                exercise: bench, unit: .kilograms)
            #expect(feedback == TrainingTrendFeedback(text: statement, symbol: symbol, positive: positive))
        }
    }

    @Test func tinyMixedBodyweightChangesStayExplicitAndNeutral() {
        for (latest, previous, reps, statement) in [
            (1, 0, 4, "Less than 0.01 kg more added weight · 1 fewer rep"),
            (0, 1, 6, "Less than 0.01 kg less added weight · 1 more rep")
        ] {
            let feedback = TrainingTrendFeedback.make(comparison: .differentSets,
                latest: SetValues(weight: latest, reps: reps), previous: SetValues(weight: previous, reps: 5),
                exercise: pullUp, unit: .kilograms)
            #expect(feedback == TrainingTrendFeedback(text: statement, symbol: "arrow.left.arrow.right", positive: false))
        }
    }

    @Test func matchedAndFirstDayRetainFactualStates() {
        let values = SetValues(weight: 13_500, reps: 5)
        let matched = TrainingTrendFeedback.make(comparison: .matched, latest: values, previous: values,
            exercise: bench, unit: .pounds)
        #expect(matched == TrainingTrendFeedback(text: "Matched prior set", symbol: "equal", positive: false))
        let firstDay = TrainingTrendFeedback.make(comparison: .insufficientHistory, latest: values, previous: nil,
            exercise: bench, unit: .pounds)
        #expect(firstDay == TrainingTrendFeedback(text: "One recorded day in this window. Record another day to compare.",
            symbol: nil, positive: false))
    }
}
