import Foundation

/// Structure copied into templates and programs, without performed sets or timer state.
public struct SupersetPlan: Codable, Equatable, Sendable {
    public let first: String
    public let second: String
    public let rounds: Int
    public let restSeconds: Int
    public var exerciseIDs: [String] { [first, second] }

    public init(first: String, second: String, rounds: Int, restSeconds: Int) {
        self.first = first
        self.second = second
        self.rounds = rounds
        self.restSeconds = restSeconds
    }

    package static func validate(_ plans: [Self], order: [String]) throws {
        var occupied = Set<String>()
        for plan in plans {
            guard (1...20).contains(plan.rounds), (0...3600).contains(plan.restSeconds),
                  let start = order.firstIndex(of: plan.first), start + 1 < order.count,
                  order[start + 1] == plan.second,
                  occupied.insert(plan.first).inserted, occupied.insert(plan.second).inserted else {
                throw TrainingError.invalidWorkspace
            }
        }
    }
}

public enum SupersetPhase: String, Codable, Sendable {
    case ready, working, resting, finished
}

public enum SupersetRestTimer: Codable, Equatable, Sendable {
    case running(until: Date)
    case paused(seconds: Int)

    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    public func remaining(at now: Date) -> Int {
        switch self {
        case .running(let deadline):
            return Int(min(3600, max(0, ceil(deadline.timeIntervalSince(now)))))
        case .paused(let seconds): return seconds
        }
    }
}

public enum SupersetTimerAction: Sendable {
    case start, pause, resume, adjust(Int), end
}

public struct WorkoutSuperset: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let plan: SupersetPlan
    public package(set) var phase: SupersetPhase = .ready
    public package(set) var completedTurns = 0
    public package(set) var timer: SupersetRestTimer?
    // Explicit row assignments keep edited and deleted sets distinct from ordinary extra sets.
    package var rowIDs: [UUID?] = []

    public init(plan: SupersetPlan) {
        self.id = UUID()
        self.plan = plan
    }

    public var round: Int {
        phase == .resting ? completedTurns / 2 : min(plan.rounds, completedTurns / 2 + 1)
    }

    public var currentExerciseID: String {
        if phase == .resting || phase == .finished { return plan.second }
        return completedTurns.isMultiple(of: 2) ? plan.first : plan.second
    }

    public var currentRowID: UUID? {
        guard phase == .working, rowIDs.indices.contains(completedTurns) else { return nil }
        return rowIDs[completedTurns]
    }

    private func exerciseID(at turn: Int) -> String { turn.isMultiple(of: 2) ? plan.first : plan.second }

    package func validate(in workout: DayWorkout) throws {
        let total = plan.rounds * 2
        let bindings = rowIDs.compactMap { $0 }
        guard (0...total).contains(completedTurns), rowIDs.count <= total,
              completedTurns <= rowIDs.count, Set(bindings).count == bindings.count else { throw TrainingError.invalidWorkspace }
        switch phase {
        case .ready: guard completedTurns == 0 && rowIDs.isEmpty && timer == nil else { throw TrainingError.invalidWorkspace }
        case .working: guard completedTurns < total && currentRowID != nil else { throw TrainingError.invalidWorkspace }
        case .resting: guard completedTurns > 0 && completedTurns < total && completedTurns.isMultiple(of: 2) else { throw TrainingError.invalidWorkspace }
        case .finished: guard completedTurns == total && timer == nil else { throw TrainingError.invalidWorkspace }
        }
        if case .paused(let seconds) = timer, !(0...3600).contains(seconds) { throw TrainingError.invalidWorkspace }
        for (turn, id) in rowIDs.enumerated() {
            if turn < completedTurns && id == nil { throw TrainingError.invalidWorkspace }
            if let id {
                guard let row = workout.rows[exerciseID(at: turn)]?.first(where: { $0.id == id }),
                      row.kind?.countsTowardWorkingPlan == true,
                      turn >= completedTurns || row.performedSetID != nil else { throw TrainingError.invalidWorkspace }
            }
        }
    }

    package mutating func bindCurrentRow(in workout: inout DayWorkout) {
        guard phase == .working && currentRowID == nil else { return }
        let id = currentExerciseID
        let assigned = Set(rowIDs.compactMap { $0 })
        let rowID: UUID
        if let available = workout.rows[id]?.last(where: {
            $0.performedSetID == nil && $0.kind?.countsTowardWorkingPlan == true && !assigned.contains($0.id)
        }) {
            rowID = available.id
        } else {
            let row = TrainingRow(unit: workout.unit, kind: .working)
            workout.rows[id, default: []].append(row)
            rowID = row.id
        }
        if completedTurns == rowIDs.count { rowIDs.append(rowID) } else { rowIDs[completedTurns] = rowID }
    }

    /// Row deletion and reclassification can happen from the ordinary set editor.
    /// Reopen the first affected turn. Later surviving rows keep their assignments.
    package mutating func reconcileRows(in workout: inout DayWorkout) {
        for (turn, id) in rowIDs.enumerated() {
            guard let id else { continue }
            let row = workout.rows[exerciseID(at: turn)]?.first { $0.id == id }
            if row?.kind?.countsTowardWorkingPlan != true || (turn < completedTurns && row?.performedSetID == nil) {
                rowIDs[turn] = nil
                if turn < completedTurns {
                    completedTurns = turn
                    phase = .working
                    timer = nil
                }
            }
        }
        bindCurrentRow(in: &workout)
    }
}

extension DayWorkout {
    package mutating func removeSuperset(containing id: String) {
        supersets?.removeAll { $0.plan.exerciseIDs.contains(id) }
        if supersets?.isEmpty == true { supersets = nil }
    }

    package mutating func reconcileSupersetRows() {
        guard var groups = supersets else { return }
        for index in groups.indices { groups[index].reconcileRows(in: &self) }
        supersets = groups
    }

    /// Keep both lifts together at the earlier of their existing workout positions.
    package mutating func pair(_ plan: SupersetPlan) throws {
        guard let first = exerciseIDs.firstIndex(of: plan.first), let second = exerciseIDs.firstIndex(of: plan.second),
              first != second else { throw TrainingError.invalidWorkspace }
        var order = exerciseIDs.filter { $0 != plan.first && $0 != plan.second }
        order.insert(contentsOf: plan.exerciseIDs, at: min(first, second))
        let groups = (supersets ?? []) + [WorkoutSuperset(plan: plan)]
        try SupersetPlan.validate(groups.map(\.plan), order: order)
        exerciseIDs = order
        supersets = groups
    }
}

/// Restore the paired turn together with the ordinary set-deletion undo.
public struct SupersetSetUndo: Codable, Equatable, Sendable {
    package let original: WorkoutSuperset
    package let generatedRowID: UUID?

    package init(original: WorkoutSuperset, generatedRowID: UUID?) {
        self.original = original
        self.generatedRowID = generatedRowID
    }

    package func restore(in workout: inout DayWorkout, exerciseID: String, rowID: UUID) throws {
        guard original.rowIDs.contains(rowID), original.plan.exerciseIDs.contains(exerciseID),
              let index = workout.supersets?.firstIndex(where: { $0.id == original.id && $0.plan == original.plan })
        else { throw TrainingError.invalidWorkspace }
        if let generatedRowID {
            guard workout.supersets?[index].currentRowID == generatedRowID,
                  !original.rowIDs.contains(generatedRowID),
                  let generated = workout.rows[exerciseID]?.first(where: { $0.id == generatedRowID }),
                  generated.performedSetID == nil, generated.weight.isEmpty, generated.reps.isEmpty
            else { throw TrainingError.invalidWorkspace }
            workout.rows[exerciseID]?.removeAll { $0.id == generatedRowID }
        }
        workout.supersets?[index] = original
    }
}
