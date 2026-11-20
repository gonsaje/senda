public extension Exercise {
    /// Muscles used to credit working and drop sets in the training log.
    var trackedMuscles: [MuscleRegion] {
        guard presetID != nil else { return customMuscleTags }
        return muscleMap?.trackedMuscles ?? []
    }

    var primaryTrackedMuscles: [MuscleRegion] {
        guard presetID != nil else {
            return customMuscleTags.filter { group == .fullBody || $0.group == group }
        }
        return muscleMap?.primary ?? []
    }

    /// Search includes the targets of stretching and non-strength activities, even when they earn no set credit.
    var taggedMuscles: [MuscleRegion] {
        if let presetID, let targets = GymExerciseCatalog.entriesByID[presetID]?.activityMuscles { return targets }
        return trackedMuscles
    }

    var taggedGroups: Set<MuscleGroup> {
        Set(taggedMuscles.map(\.group)).union([group])
    }
}
