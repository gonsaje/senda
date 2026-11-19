import SendaDomain

public struct TrainingDaySummary: Equatable, Sendable {
    public let exercises: [String]
    public let muscleGroups: [MuscleGroup]
    public let setCount: Int
    public let weekFocus: String?

    init(performed: [Exercise], setCount: Int) {
        self.setCount = setCount
        exercises = performed.map(\.name)
        let groups = Set(performed.map(\.group))
        muscleGroups = MuscleGroup.allCases.filter(groups.contains)
        weekFocus = Self.weekFocus(for: performed)
    }

    private static func weekFocus(for performed: [Exercise]) -> String? {
        guard !performed.isEmpty else { return nil }
        let lowerRegions: [MuscleRegion] = [.quadriceps, .hamstrings, .glutes, .calves]
        var groups: Set<MuscleGroup> = []
        var lowerMuscles: Set<MuscleRegion> = []
        var hasUnspecifiedLegs = false

        for exercise in performed {
            let primary = exercise.muscleMap?.primary ?? []
            let targetsOnlyLegs = !primary.isEmpty && primary.allSatisfy(lowerRegions.contains)
            if exercise.group == .legs || targetsOnlyLegs {
                groups.insert(.legs)
                let muscles = primary.filter(lowerRegions.contains)
                lowerMuscles.formUnion(muscles)
                if muscles.isEmpty { hasUnspecifiedLegs = true }
            } else {
                groups.insert(exercise.group)
            }
        }

        let hasCore = groups.remove(.core) != nil
        let summarize = groups.count + (hasCore ? 1 : 0) >= 3
        var names: [String]
        if groups.count >= 2 && (summarize || lowerMuscles.count >= 3) {
            names = [groups.contains(.legs) || groups.contains(.fullBody) ? "Full Body" : "Upper Body"]
        } else {
            names = MuscleGroup.allCases.filter(groups.contains).flatMap { group -> [String] in
                guard group == .legs else { return [group == .fullBody ? "Full Body" : group.rawValue] }
                if lowerMuscles.count >= 3 { return ["Lower Body"] }
                if hasUnspecifiedLegs || (lowerMuscles.count == 2 && (hasCore || groups.count > 1)) {
                    return ["Legs"]
                }
                return lowerRegions.filter(lowerMuscles.contains).map { $0 == .quadriceps ? "Quads" : $0.name }
            }
        }
        if hasCore { names.append(MuscleGroup.core.rawValue) }
        return names.joined(separator: " · ")
    }
}
