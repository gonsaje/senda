enum ExpandedExerciseCatalog {
    private struct Entry {
        let exercise: Exercise
        let muscles: ExerciseMuscleMap
    }

    static let exercises = entries.map(\.exercise)
    static let muscleMaps = Dictionary(uniqueKeysWithValues: entries.map { ($0.exercise.id, $0.muscles) })

    // Keep these identifiers stable. Saved sets and workout templates refer to them.
    private static let entries = [
        lift("incline-barbell-bench", "Incline barbell bench", .chest, .barbell, [.chest], supporting: [.frontShoulders, .triceps]),
        lift("close-grip-bench", "Close-grip bench", .arms, .barbell, [.triceps], supporting: [.chest, .frontShoulders]),
        lift("front-squat", "Front squat", .legs, .barbell, [.quadriceps, .glutes], supporting: [.adductors]),
        lift("sumo-deadlift", "Sumo deadlift", .legs, .barbell, [.glutes, .quadriceps, .hamstrings], stabilizing: [.spinalErectors, .abdominals], loadedStabilizers: [.spinalErectors]),
        lift("barbell-good-morning", "Barbell good morning", .legs, .barbell, [.hamstrings, .glutes], stabilizing: [.spinalErectors, .abdominals], loadedStabilizers: [.spinalErectors]),
        lift("barbell-curl", "Barbell curl", .arms, .barbell, [.biceps], supporting: [.forearms]),
        lift("incline-dumbbell-bench", "Incline dumbbell bench", .chest, .dumbbell, [.chest], supporting: [.frontShoulders, .triceps]),
        lift("dumbbell-shoulder-press", "Dumbbell shoulder press", .shoulders, .dumbbell, [.frontShoulders, .sideShoulders], supporting: [.triceps]),
        lift("one-arm-dumbbell-row", "One-arm dumbbell row", .back, .dumbbell, [.lats, .upperBack], supporting: [.rearShoulders, .biceps]),
        lift("dumbbell-fly", "Dumbbell fly", .chest, .dumbbell, [.chest], supporting: [.frontShoulders]),
        lift("reverse-dumbbell-fly", "Reverse dumbbell fly", .shoulders, .dumbbell, [.rearShoulders], supporting: [.upperBack]),
        lift("hammer-curl", "Hammer curl", .arms, .dumbbell, [.biceps, .forearms]),
        lift("goblet-squat", "Goblet squat", .legs, .dumbbell, [.quadriceps, .glutes], supporting: [.adductors], stabilizing: [.abdominals]),
        lift("bulgarian-split-squat", "Bulgarian split squat", .legs, .dumbbell, [.quadriceps, .glutes], supporting: [.hamstrings]),
        lift("dumbbell-step-up", "Dumbbell step-up", .legs, .dumbbell, [.quadriceps, .glutes], supporting: [.hamstrings]),
        lift("dumbbell-romanian-deadlift", "Dumbbell Romanian deadlift", .legs, .dumbbell, [.hamstrings, .glutes], stabilizing: [.spinalErectors, .abdominals, .forearms], loadedStabilizers: [.spinalErectors]),
        lift("cable-fly", "Cable fly", .chest, .cable, [.chest], supporting: [.frontShoulders]),
        lift("face-pull", "Face pull", .shoulders, .cable, [.rearShoulders, .upperBack]),
        lift("cable-overhead-triceps-extension", "Overhead cable triceps extension", .arms, .cable, [.triceps]),
        lift("cable-curl", "Cable curl", .arms, .cable, [.biceps], supporting: [.forearms]),
        lift("cable-crunch", "Cable crunch", .core, .cable, [.abdominals]),
        lift("straight-arm-pulldown", "Straight-arm pulldown", .back, .cable, [.lats], stabilizing: [.abdominals]),
        lift("machine-chest-press", "Machine chest press", .chest, .machine, [.chest], supporting: [.frontShoulders, .triceps]),
        lift("machine-shoulder-press", "Machine shoulder press", .shoulders, .machine, [.frontShoulders, .sideShoulders], supporting: [.triceps]),
        lift("machine-chest-supported-row", "Chest-supported machine row", .back, .machine, [.upperBack, .lats], supporting: [.rearShoulders, .biceps]),
        lift("hack-squat", "Hack squat", .legs, .machine, [.quadriceps, .glutes], supporting: [.adductors]),
        lift("seated-leg-curl", "Seated leg curl", .legs, .machine, [.hamstrings], supporting: [.calves]),
        lift("seated-calf-raise", "Seated calf raise", .legs, .machine, [.calves]),
        lift("chin-up", "Chin-up", .back, .bodyweight, [.lats, .biceps], supporting: [.upperBack], stabilizing: [.forearms, .abdominals]),
        lift("dip", "Dip", .chest, .bodyweight, [.chest, .triceps], supporting: [.frontShoulders]),
        lift("inverted-row", "Inverted row", .back, .bodyweight, [.lats, .upperBack], supporting: [.rearShoulders, .biceps]),
        lift("bodyweight-squat", "Bodyweight squat", .legs, .bodyweight, [.quadriceps, .glutes], supporting: [.adductors]),
        lift("glute-bridge", "Glute bridge", .legs, .bodyweight, [.glutes], supporting: [.hamstrings]),
        lift("reverse-lunge", "Bodyweight reverse lunge", .legs, .bodyweight, [.quadriceps, .glutes], supporting: [.hamstrings]),
        lift("crunch", "Crunch", .core, .bodyweight, [.abdominals]),
        lift("hanging-knee-raise", "Hanging knee raise", .core, .bodyweight, [.abdominals, .hipFlexors], stabilizing: [.forearms])
    ]

    private static func lift(_ id: String, _ name: String, _ group: MuscleGroup, _ equipment: ExerciseEquipment,
                             _ primary: [MuscleRegion], supporting: [MuscleRegion] = [],
                             stabilizing: [MuscleRegion] = [], loadedStabilizers: [MuscleRegion] = []) -> Entry {
        Entry(
            exercise: Exercise(id: id, name: name, shortName: name, startingWeight: 0, muscleGroup: group, equipment: equipment),
            muscles: ExerciseMuscleMap(primary: primary, supporting: supporting, stabilizing: stabilizing, variation: name, loadedStabilizers: loadedStabilizers)
        )
    }
}
