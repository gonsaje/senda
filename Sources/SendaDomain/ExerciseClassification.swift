import Foundation

public enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest = "Chest", back = "Back", shoulders = "Shoulders", legs = "Legs", arms = "Arms", core = "Core", neck = "Neck", fullBody = "Full body"
}
public enum ExerciseEquipment: String, Codable, CaseIterable, Sendable {
    case barbell = "Barbell", dumbbell = "Dumbbell", cable = "Cable", machine = "Machine", bodyweight = "Bodyweight", other = "Other"
}
public extension Exercise {
    var group: MuscleGroup { muscleGroup ?? defaults.0 }
    var equipmentType: ExerciseEquipment { equipment ?? defaults.1 }
    var equipmentLabel: String {
        if equipmentType == .other, let presetID, let setup = GymExerciseCatalog.entriesByID[presetID]?.setup { return setup }
        return equipmentType.rawValue
    }
    var requiresWeight: Bool {
        if equipmentType == .bodyweight || customSetup.requiredEquipment?.isEmpty == true { return false }
        return presetID.flatMap { GymExerciseCatalog.entriesByID[$0]?.optionalLoad } != true
    }
    private var defaults: (MuscleGroup, ExerciseEquipment) {
        switch id {
        case "bench": (.chest, .barbell)
        case "dumbbell-bench": (.chest, .dumbbell)
        case "push-up": (.chest, .bodyweight)
        case "deadlift", "row": (.back, .barbell)
        case "lat-pulldown": (.back, .machine)
        case "cable-row": (.back, .cable)
        case "pull-up": (.back, .bodyweight)
        case "overhead-press": (.shoulders, .barbell)
        case "lateral-raise": (.shoulders, .dumbbell)
        case "squat", "romanian-deadlift", "hip-thrust": (.legs, .barbell)
        case "leg-press", "leg-curl", "leg-extension", "calf-raise": (.legs, .machine)
        case "lunge": (.legs, .dumbbell)
        case "biceps-curl": (.arms, .dumbbell)
        case "triceps-extension": (.arms, .cable)
        default: (.fullBody, .other)
        }
    }
}
