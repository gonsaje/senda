import Testing
import SendaDomain
@testable import SendaNotebook

struct TrainingSetTypeTextTests {
    @Test func legacyUnknownTypeStillNeedsClassification() {
        #expect(TrainingSetTypeText.title(nil) == "Not set")
        #expect(TrainingSetTypeText.buttonTitle(nil) == "Choose type")
    }

    @Test func pickerOffersWorkingOnceWithoutTheLegacyRegularAlias() {
        let choices = TrainingSetTypeText.choices
        #expect(choices == [.warmup, .working, .dropSet])
        #expect(Set(choices.map(TrainingSetTypeText.title)).count == 3)
        #expect(Set(choices.map(TrainingSetTypeText.identifier)).count == 3)
        #expect(choices.map(TrainingSetTypeText.title) == ["Warm-up", "Working set", "Drop set"])
    }

    @Test func legacyRegularDisplaysAndSelectsTheSingleWorkingChoice() {
        #expect(TrainingSetTypeText.title(.regular) == "Working set")
        #expect(TrainingSetTypeText.buttonTitle(.regular) == "Working set")
        #expect(TrainingSetTypeText.definition(.regular) == TrainingSetTypeText.definition(.working))
        #expect(TrainingSetTypeText.choices.filter { $0 == TrainingSetTypeText.selectedChoice(for: .regular) } == [.working])
        #expect(TrainingSetTypeText.selectedChoice(for: .working) == .working)
        #expect(TrainingSetTypeText.selectedChoice(for: .warmup) == .warmup)
        #expect(TrainingSetTypeText.selectedChoice(for: .dropSet) == .dropSet)
        #expect(TrainingSetTypeText.selectedChoice(for: nil) == nil)
    }

    @Test func dropDefinitionKeepsStagesInOneSetAndDoesNotRequireFailure() {
        let definition = TrainingSetTypeText.definition(.dropSet)
        #expect(definition.contains("Reduce the weight"))
        #expect(definition.contains("little rest"))
        #expect(definition.contains("starting weight and reps"))
        #expect(definition.contains("add each drop"))
        #expect(definition.contains("one drop set"))
        #expect(!definition.contains("each weight as its own set"))
        #expect(definition.contains("do not count toward your working-set target"))
        #expect(!definition.lowercased().contains("failure"))
    }

    @Test func effortActionRemainsClearlyNamedWithoutRepeatingTheType() {
        #expect(TrainingSetDetailsText.effort(nil) == "Reps left")
        #expect(TrainingSetDetailsText.effort(0) == "0 reps left")
        #expect(TrainingSetDetailsText.effort(1) == "1 rep left")
        #expect(TrainingSetDetailsText.effort(5) == "5+ reps left")
    }

    @Test func dropGuidanceRequestsManualReviewRatherThanAnIncrease() {
        let guidance = NextWorkoutGuidance(plan: ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12),
                                          status: .reviewPlan, reason: .dropSets, referenceWeight: 13_500)
        let exercise = Exercise(id: "bench", name: "Bench", shortName: "Bench", startingWeight: 13_500)
        let text = TrainingNextWorkoutText.make(guidance, exercise: exercise, unit: .pounds)
        #expect(text.contains("drop sets"))
        #expect(text.contains("manually"))
        #expect(!text.contains("increase"))
        #expect(!text.contains("unclassified"))
    }
}
