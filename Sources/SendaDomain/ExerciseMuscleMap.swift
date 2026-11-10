/// Surface regions used by the Learn anatomy illustration. These are educational
/// labels, independent of the broader muscle groups saved with an exercise.
public enum MuscleRegion: String, CaseIterable, Sendable {
    case chest, frontShoulders, sideShoulders, rearShoulders
    case biceps, triceps, forearms, lats, upperBack, spinalErectors
    case abdominals, glutes, quadriceps, hamstrings, calves

    public var name: String {
        switch self {
        case .chest: "Chest"
        case .frontShoulders: "Front shoulders"
        case .sideShoulders: "Side shoulders"
        case .rearShoulders: "Rear shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .lats: "Lats"
        case .upperBack: "Upper back"
        case .spinalErectors: "Spinal erectors"
        case .abdominals: "Abdominals"
        case .glutes: "Glutes"
        case .quadriceps: "Quadriceps"
        case .hamstrings: "Hamstrings"
        case .calves: "Calves"
        }
    }

    public var anatomicalName: String {
        switch self {
        case .chest: "Pectoralis major"
        case .frontShoulders: "Anterior deltoid"
        case .sideShoulders: "Middle deltoid"
        case .rearShoulders: "Posterior deltoid"
        case .biceps: "Biceps brachii and brachialis"
        case .triceps: "Triceps brachii"
        case .forearms: "Brachioradialis and wrist and finger flexors"
        case .lats: "Latissimus dorsi"
        case .upperBack: "Trapezius and rhomboids"
        case .spinalErectors: "Erector spinae"
        case .abdominals: "Rectus abdominis, transverse abdominis and obliques"
        case .glutes: "Gluteus maximus and other gluteal muscles"
        case .quadriceps: "Quadriceps femoris"
        case .hamstrings: "Biceps femoris, semitendinosus and semimembranosus"
        case .calves: "Gastrocnemius and soleus"
        }
    }
}

/// A qualitative map for the variation described by `ExerciseFormGuide`.
/// Primary regions produce the main movement; supporting regions assist it.
/// Stabilizing regions hold position or grip and are kept separate from movers.
/// The surface map is selective, not an exhaustive list or activation measurement.
public struct ExerciseMuscleMap: Equatable, Sendable {
    public let primary: [MuscleRegion]
    public let supporting: [MuscleRegion]
    public let stabilizing: [MuscleRegion]
    public let variation: String

    /// Custom or unknown identifiers have no inferred anatomical guidance.
    public static func map(for id: String) -> ExerciseMuscleMap? {
        switch id {
        case "bench":
            ExerciseMuscleMap(primary: [.chest], supporting: [.frontShoulders, .triceps],
                stabilizing: [.abdominals], variation: "Flat barbell bench press")
        case "deadlift":
            ExerciseMuscleMap(primary: [.glutes, .quadriceps, .hamstrings], supporting: [],
                stabilizing: [.spinalErectors, .abdominals, .lats, .upperBack, .forearms],
                variation: "Conventional barbell deadlift")
        case "squat":
            ExerciseMuscleMap(primary: [.quadriceps, .glutes], supporting: [.hamstrings],
                stabilizing: [.abdominals, .spinalErectors], variation: "Barbell back squat")
        case "row":
            ExerciseMuscleMap(primary: [.lats, .upperBack], supporting: [.rearShoulders, .biceps],
                stabilizing: [.spinalErectors, .abdominals, .forearms],
                variation: "Bent-over barbell row with an overhand grip")
        case "overhead-press":
            ExerciseMuscleMap(primary: [.frontShoulders, .sideShoulders], supporting: [.triceps, .upperBack],
                stabilizing: [.abdominals, .spinalErectors], variation: "Standing barbell shoulder press")
        case "lat-pulldown":
            ExerciseMuscleMap(primary: [.lats], supporting: [.upperBack, .biceps, .rearShoulders],
                stabilizing: [.abdominals, .forearms], variation: "Seated cable pulldown to the chest")
        case "romanian-deadlift":
            ExerciseMuscleMap(primary: [.hamstrings, .glutes], supporting: [],
                stabilizing: [.spinalErectors, .abdominals, .upperBack, .forearms],
                variation: "Barbell Romanian deadlift")
        case "dumbbell-bench":
            ExerciseMuscleMap(primary: [.chest], supporting: [.frontShoulders, .triceps],
                stabilizing: [.abdominals], variation: "Flat dumbbell bench press")
        case "pull-up":
            ExerciseMuscleMap(primary: [.lats], supporting: [.upperBack, .biceps, .rearShoulders],
                stabilizing: [.abdominals, .forearms], variation: "Overhand pull-up")
        case "leg-press":
            ExerciseMuscleMap(primary: [.quadriceps, .glutes], supporting: [.hamstrings],
                stabilizing: [.abdominals], variation: "Seated machine leg press")
        case "leg-curl":
            ExerciseMuscleMap(primary: [.hamstrings], supporting: [.calves],
                stabilizing: [], variation: "Lying machine leg curl")
        case "leg-extension":
            ExerciseMuscleMap(primary: [.quadriceps], supporting: [],
                stabilizing: [], variation: "Seated machine leg extension")
        case "lunge":
            ExerciseMuscleMap(primary: [.quadriceps, .glutes], supporting: [.hamstrings],
                stabilizing: [.abdominals, .spinalErectors, .forearms],
                variation: "Forward lunge with dumbbells")
        case "biceps-curl":
            ExerciseMuscleMap(primary: [.biceps], supporting: [.forearms],
                stabilizing: [], variation: "Seated dumbbell curl with palms forward")
        case "triceps-extension":
            ExerciseMuscleMap(primary: [.triceps], supporting: [],
                stabilizing: [.forearms], variation: "Standing cable rope pressdown")
        case "lateral-raise":
            ExerciseMuscleMap(primary: [.sideShoulders], supporting: [.upperBack],
                stabilizing: [.abdominals, .forearms], variation: "Standing dumbbell lateral raise")
        case "calf-raise":
            ExerciseMuscleMap(primary: [.calves], supporting: [],
                stabilizing: [], variation: "Seated foot-press machine")
        case "hip-thrust":
            ExerciseMuscleMap(primary: [.glutes], supporting: [.hamstrings],
                stabilizing: [.abdominals, .quadriceps], variation: "Barbell hip thrust with shoulders on a bench")
        case "cable-row":
            ExerciseMuscleMap(primary: [.lats, .upperBack], supporting: [.rearShoulders, .biceps],
                stabilizing: [.abdominals, .spinalErectors, .forearms],
                variation: "Seated low cable row")
        case "push-up":
            ExerciseMuscleMap(primary: [.chest], supporting: [.frontShoulders, .triceps],
                stabilizing: [.abdominals, .glutes], variation: "Floor push-up with legs extended")
        default:
            nil
        }
    }
}
