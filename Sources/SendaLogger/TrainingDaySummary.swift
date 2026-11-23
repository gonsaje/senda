import SendaDomain

public struct TrainingDaySummary: Equatable, Sendable {
    public let exercises: [String]
    public let muscleGroups: [MuscleGroup]
    public let setCount: Int
    public let weekFocus: String?

    init(performed: [Exercise], setCount: Int, planned: [Exercise] = []) {
        self.setCount = setCount
        exercises = performed.map(\.name)
        let groups = performed.reduce(into: Set<MuscleGroup>()) { result, exercise in
            let tracked = exercise.trackedMuscles
            if !tracked.isEmpty || exercise.presetID == nil {
                result.insert(exercise.group)
                result.formUnion(tracked.map(\.group))
            }
        }
        muscleGroups = MuscleGroup.allCases.filter(groups.contains)
        weekFocus = Self.weekFocus(for: performed.isEmpty ? planned : performed)
    }

    private static func weekFocus(for performed: [Exercise]) -> String? {
        guard !performed.isEmpty else { return nil }
        var categories = Set<MuscleGroup>()
        var primaryCategories = Set<MuscleGroup>()
        var lowerMuscles = Set<MuscleRegion>()
        var hasUnspecifiedLegs = false

        for exercise in performed {
            let isCustom = exercise.presetID == nil
            let primary = exercise.primaryTrackedMuscles
            // Show deliberately loaded stabilizers and custom choices in the headline; ordinary assists stay in Muscles.
            let displayed = isCustom ? exercise.trackedMuscles : primary + (exercise.muscleMap?.loadedStabilizers ?? [])
            guard isCustom || !exercise.trackedMuscles.isEmpty else { continue }
            categories.insert(exercise.group)
            categories.formUnion(displayed.map(\.group))
            if primary.isEmpty {
                primaryCategories.insert(exercise.group)
            } else {
                primaryCategories.formUnion(primary.map(\.group))
            }
            let lower = displayed.filter { $0.group == .legs }
            lowerMuscles.formUnion(lower)
            if exercise.group == .legs && lower.isEmpty { hasUnspecifiedLegs = true }
        }

        let hasCore = categories.remove(.core) != nil
        let areaCount = categories.count
        let primaryAreaCount = primaryCategories.subtracting([.core]).count
        var names: [String] = []
        if categories.contains(.fullBody) || areaCount >= 3 || (areaCount >= 2 && hasCore && primaryAreaCount >= 2) {
            names = [categories.contains(.legs) || categories.contains(.fullBody) ? "Full Body" : "Upper Body"]
        } else {
            for group in MuscleGroup.allCases where categories.contains(group) {
                if group != .legs {
                    names.append(group.rawValue)
                } else if lowerMuscles.count >= 3 && areaCount == 1 {
                    names.append("Lower Body")
                } else if hasUnspecifiedLegs || (lowerMuscles.count >= 2 && (hasCore || areaCount > 1)) {
                    names.append("Legs")
                } else {
                    let commonOrder: [MuscleRegion] = [.quadriceps, .hamstrings, .glutes, .calves]
                    let order = commonOrder + MuscleRegion.allCases.filter { !commonOrder.contains($0) }
                    names += order.filter(lowerMuscles.contains).map { $0 == .quadriceps ? "Quads" : $0.name }
                }
            }
        }
        if hasCore { names.append(MuscleGroup.core.rawValue) }
        if names.isEmpty { return performed.count == 1 ? performed[0].displayName : "Workout" }
        return names.joined(separator: " · ")
    }
}
