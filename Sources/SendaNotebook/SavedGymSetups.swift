import Foundation
import SendaDomain

struct SavedGymSetup: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var filter: ExerciseGymFilter
}

/// A temporary library search can change or clear its filters without rewriting anyone's saved equipment.
struct SavedGymSetups: Equatable, Codable {
    private(set) var setups: [SavedGymSetup] = []
    private(set) var selectedID: UUID?
    private var temporary = ExerciseGymFilter()

    init() {}

    init(data: Data, legacy: Data) {
        if !data.isEmpty, let stored = try? JSONDecoder().decode(Self.self, from: data) {
            self = stored
        } else if let old = try? JSONDecoder().decode(ExerciseGymFilter.self, from: legacy), old != .init() {
            // A stable ID lets several views read the same legacy preference before the first edit.
            let id = UUID(uuidString: "88182F93-410F-44F6-9E58-9EDBB1A592AD")!
            setups = [.init(id: id, name: suggestedName(for: old), filter: old)]
            selectedID = id
        }
    }

    var selected: SavedGymSetup? { setups.first { $0.id == selectedID } }
    var filter: ExerciseGymFilter { selected?.filter ?? temporary }

    mutating func select(_ id: UUID?) {
        guard id == nil || setups.contains(where: { $0.id == id }) else { return }
        selectedID = id
        temporary = .init()
    }

    mutating func applyTemporary(_ next: ExerciseGymFilter) {
        guard next != filter || next == .init() else { return }
        selectedID = nil
        temporary = next
    }

    func allowsName(_ name: String, editing id: UUID?) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !setups.contains {
            $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    func suggestedName(for filter: ExerciseGymFilter) -> String {
        let base = filter.gym?.label ?? "My gym"
        var name = base
        var suffix = 2
        while !allowsName(name, editing: nil) {
            name = "\(base) \(suffix)"
            suffix += 1
        }
        return name
    }

    @discardableResult mutating func save(_ filter: ExerciseGymFilter, named name: String, editing id: UUID?) -> Bool {
        let requested = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = requested.isEmpty ? suggestedName(for: filter) : requested
        guard allowsName(name, editing: id) else { return false }
        if let id {
            guard let index = setups.firstIndex(where: { $0.id == id }) else { return false }
            setups[index] = SavedGymSetup(id: id, name: name, filter: filter)
            select(id)
        } else {
            let setup = SavedGymSetup(id: UUID(), name: name, filter: filter)
            setups.append(setup)
            select(setup.id)
        }
        return true
    }

    mutating func remove(_ id: UUID) {
        setups.removeAll { $0.id == id }
        if selectedID == id { select(nil) }
    }
}
