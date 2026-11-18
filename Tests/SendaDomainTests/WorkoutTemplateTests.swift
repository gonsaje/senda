import Foundation
import Testing
import SendaDomain

struct WorkoutTemplateTests {
    private let knownIDs = Set(Exercise.catalog.map(\.id))

    @Test func startersUseKnownExercisesInValidDistinctWorkouts() throws {
        let starters = WorkoutTemplate.catalog
        #expect((9...12).contains(starters.count))
        #expect(Set(starters.map(\.id)).count == starters.count)
        #expect(Set(starters.map(\.name)).isSuperset(of: ["Full body", "Upper body", "Lower body", "Push", "Pull", "Legs"]))
        for workout in starters {
            #expect(try workout.validated(against: knownIDs) == workout)
        }
    }

    @Test func validationRejectsEmptyDuplicateOrUnknownExerciseSelectionsAndInvalidPlans() throws {
        let plan = ExercisePlan(workingSets: 3, minimumReps: 6, maximumReps: 10)
        let invalid = [
            WorkoutTemplate(name: "   ", exerciseIDs: ["bench"]),
            WorkoutTemplate(name: "Missing exercises", exerciseIDs: []),
            WorkoutTemplate(name: "Repeated exercise", exerciseIDs: ["bench", "bench"]),
            WorkoutTemplate(name: "Unknown exercise", exerciseIDs: ["invented-exercise"]),
            WorkoutTemplate(name: "Orphaned plan", exerciseIDs: ["bench"], exercisePlans: ["squat": plan]),
            WorkoutTemplate(name: "Invalid plan", exerciseIDs: ["bench"], exercisePlans: ["bench":
                ExercisePlan(workingSets: 0, minimumReps: 10, maximumReps: 8)])
        ]
        for workout in invalid {
            #expect(throws: (any Error).self) { try workout.validated(against: knownIDs) }
        }
    }

    @Test func customNamesCanMatchStartersButCannotRepeatInTheWorkspace() throws {
        let week = try #require(TrainingDay(rawValue: "2026-11-16"))
        let personal = WorkoutTemplate(name: "  Full   body\n", exerciseIDs: ["bench"])
        #expect(personal.name == "Full body")
        let workspace = TrainingWorkspace(visibleWeek: week, workoutTemplates: [personal])
        #expect(try workspace.validated(against: Journal(), exercises: Exercise.catalog) == workspace)

        for conflicting in [
            WorkoutTemplate(name: "FULL BODY", exerciseIDs: ["squat"]),
            WorkoutTemplate(id: personal.id.uppercased(), name: "Different name", exerciseIDs: ["squat"]),
            WorkoutTemplate(id: "full-body", name: "Different name", exerciseIDs: ["squat"])
        ] {
            var invalid = workspace
            invalid.workoutTemplates?.append(conflicting)
            #expect(throws: (any Error).self) { try invalid.validated(against: Journal(), exercises: Exercise.catalog) }
        }
    }
}
