import Foundation

public enum ExerciseGym: String, CaseIterable, Codable, Hashable, Sendable {
    case home, commercial, bodybuilding, crossFit, specialty

    public var label: String {
        switch self {
        case .home: "Home gym"
        case .commercial: "Commercial gym"
        case .bodybuilding: "Bodybuilding gym"
        case .crossFit: "CrossFit gym"
        case .specialty: "Specialty gym"
        }
    }
}

public struct CustomExerciseSetup: Codable, Equatable, Sendable {
    public var gyms: Set<ExerciseGym>
    /// A nil value leaves requirements unspecified. An empty set explicitly needs no equipment.
    public var requiredEquipment: Set<GymEquipmentItem>?

    public init(gyms: Set<ExerciseGym> = [], requiredEquipment: Set<GymEquipmentItem>? = nil) {
        self.gyms = gyms
        self.requiredEquipment = requiredEquipment
    }

    public var isEmpty: Bool { gyms.isEmpty && requiredEquipment == nil }

    public func encode(to encoder: any Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(gyms.sorted { $0.rawValue < $1.rawValue }, forKey: .gyms)
        try box.encodeIfPresent(requiredEquipment?.sorted { $0.rawValue < $1.rawValue }, forKey: .requiredEquipment)
    }
}

public struct ExerciseGymFilter: Codable, Hashable, Sendable {
    public var gym: ExerciseGym?
    /// A nil inventory leaves equipment unrestricted. An empty inventory selects equipment-free exercises.
    public var availableEquipment: Set<GymEquipmentItem>?

    public init(gym: ExerciseGym? = nil, availableEquipment: Set<GymEquipmentItem>? = nil) {
        self.gym = gym
        self.availableEquipment = availableEquipment
    }

    public func matches(_ exercise: Exercise) -> Bool {
        exclusion(for: exercise) == nil
    }

    func exclusion(for exercise: Exercise) -> ExerciseSearchRecovery.Reason? {
        guard gym != nil || availableEquipment != nil else { return nil }
        let catalog = (exercise.catalogAliasID ?? exercise.presetID).flatMap { Self.setups[$0] }
        let custom = exercise.customSetup
        if let gym {
            guard let gyms = custom.gyms.isEmpty ? catalog?.gyms : custom.gyms else { return .gymsUnspecified }
            guard gyms.contains(gym) else { return .differentGym(gym) }
        }
        guard let availableEquipment else { return nil }
        if let required = custom.requiredEquipment {
            guard !required.isSubset(of: availableEquipment) else { return nil }
            let missing = required.subtracting(availableEquipment).sorted { $0.label < $1.label }
            return .missingEquipment(missing.map { [$0] })
        }
        guard let requirements = catalog?.requirements else { return .equipmentUnspecified }
        let missing = requirements.filter { availableEquipment.isDisjoint(with: $0) }
        return missing.isEmpty ? nil : .missingEquipment(missing)
    }

    // Each requirement lists interchangeable items. Every requirement must be met.
    // Grouping shared setups and gyms in the resource keeps the exercise IDs stable.
    private struct GymGroup: Decodable {
        let gyms: Set<ExerciseGym>
        let setups: [Setup]

        struct Setup: Decodable {
            let requirements: [[GymEquipmentItem]]
            let exerciseIDs: [String]
        }
    }

    private struct Availability {
        let gyms: Set<ExerciseGym>
        let requirements: [[GymEquipmentItem]]
    }

    private static let setups: [String: Availability] = {
        guard let url = Bundle.module.url(forResource: "ExerciseGymAvailability", withExtension: "json") else {
            preconditionFailure("Missing exercise gym availability")
        }
        do {
            let groups = try JSONDecoder().decode([GymGroup].self, from: Data(contentsOf: url))
            var index = [String: Availability]()
            for group in groups {
                for setup in group.setups {
                    let availability = Availability(gyms: group.gyms, requirements: setup.requirements)
                    for id in setup.exerciseIDs {
                        let previous = index.updateValue(availability, forKey: id)
                        precondition(previous == nil, "Duplicate gym availability for \(id)")
                    }
                }
            }
            return index
        } catch {
            preconditionFailure("Invalid exercise gym availability: \(error)")
        }
    }()
}
