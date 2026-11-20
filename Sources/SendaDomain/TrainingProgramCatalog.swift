import Foundation

extension TrainingProgram {
    public static let catalog: [TrainingProgram] = {
        let source = "https://www.nsca.com/contentassets/8323553f698a466a98220b21d9eb9a65/foundationsoffitnessprogramming_201508.pdf"
        func session(_ title: String, offset: Int, ids: [String], sets: Int, reps: Int, rir: Int, rest: Int) -> ProgramSession {
            let exercises = ids.enumerated().map { index, id in
                ProgramExercise(exerciseID: id,
                                plan: ExercisePlan(workingSets: index < 2 ? sets : 2,
                                                   minimumReps: index < 2 ? reps : 10, maximumReps: index < 2 ? reps : 10),
                                targetRIR: rir, restSeconds: index < 2 ? nil : 60)
            }
            return ProgramSession(title: title, dayOffset: offset, exercises: exercises,
                                  supersets: [SupersetPlan(first: ids[0], second: ids[1], rounds: sets, restSeconds: rest)])
        }
        func block(_ title: String, progression: String, sets: Int, reps: Int, rir: Int, rest: Int,
                   threeDays: Bool) -> ProgramBlock {
            var sessions = [
                session("Upper body", offset: 0, ids: ["bench", "cable-row", "lateral-raise"], sets: sets, reps: reps, rir: rir, rest: rest),
                session("Lower body", offset: threeDays ? 2 : 3, ids: ["goblet-squat", "leg-curl", "calf-raise"], sets: sets, reps: reps, rir: rir, rest: rest)
            ]
            if threeDays {
                sessions.append(session("Full body", offset: 4, ids: ["dumbbell-bench", "cable-row", "reverse-lunge"],
                                        sets: sets, reps: reps, rir: rir, rest: rest))
            }
            return ProgramBlock(title: title, weeks: 4, progression: progression, sessions: sessions)
        }
        return [
            TrainingProgram(id: "senda-upper-lower", title: "Upper / lower rotation",
                summary: "Two sessions a week for four weeks. Alternate upper- and lower-body training.",
                author: "Senda", sourceURL: source,
                coachingNotes: "Complete one set of A1 and A2 before resting. Adjust the load to keep the prescribed reps in reserve.",
                blocks: [block("Rotation", progression: "Repeat the two sessions each week. Increase load in a small step when every set meets the rep and effort targets.",
                               sets: 2, reps: 8, rir: 2, rest: 90, threeDays: false)]),
            TrainingProgram(id: "senda-strength-cycle", title: "Strength cycle",
                summary: "Three sessions a week across three four-week blocks.",
                author: "Senda", sourceURL: source,
                coachingNotes: "Choose loads for the current block’s rep target. Rest longer between rounds when you need it to repeat the movement with control.",
                blocks: [
                    block("Foundation", progression: "Use two working sets for each paired lift. Practise a repeatable range of motion with about three reps in reserve.",
                          sets: 2, reps: 8, rir: 3, rest: 90, threeDays: true),
                    block("Build", progression: "Add a third set to each paired lift. Hold load steady until all three rounds meet the rep target.",
                          sets: 3, reps: 8, rir: 2, rest: 120, threeDays: true),
                    block("Consolidate", progression: "Use six reps per paired lift and a longer rest. Adjust load while keeping two reps in reserve.",
                          sets: 3, reps: 6, rir: 2, rest: 150, threeDays: true)
                ])
        ]
    }()
}
