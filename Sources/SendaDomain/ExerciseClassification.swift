import Foundation

public enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest = "Chest", back = "Back", shoulders = "Shoulders", legs = "Legs", arms = "Arms", core = "Core", fullBody = "Full body"
}
public enum ExerciseEquipment: String, Codable, CaseIterable, Sendable {
    case barbell = "Barbell", dumbbell = "Dumbbell", cable = "Cable", machine = "Machine", bodyweight = "Bodyweight", other = "Other"
}
public extension Exercise {
    var group: MuscleGroup { muscleGroup ?? defaults.0 }
    var equipmentType: ExerciseEquipment { equipment ?? defaults.1 }
    var requiresWeight: Bool { equipmentType != .bodyweight }
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
