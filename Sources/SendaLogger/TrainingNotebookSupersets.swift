import Foundation
import SendaDomain
import SendaPersistence

extension TrainingNotebookModel {
    /// Presentation order follows the movable exercise groups, including after a reorder.
    public var supersets: [WorkoutSuperset] {
        guard let workout, let groups = workout.supersets else { return [] }
        let byFirst = Dictionary(uniqueKeysWithValues: groups.map { ($0.plan.first, $0) })
        return workout.exerciseIDs.compactMap { byFirst[$0] }
    }

    @discardableResult public func createSuperset(_ plan: SupersetPlan) -> Bool {
        guard !canRetrySave, let day = selectedDay, var workout,
              plan.first != plan.second, plan.exerciseIDs.allSatisfy(workout.exerciseIDs.contains),
              !supersets.contains(where: { !Set($0.plan.exerciseIDs).isDisjoint(with: plan.exerciseIDs) }) else { return false }
        return commit(synchronizeInput: false) { state in
            try workout.pair(plan)
            state.training!.days[day.rawValue] = workout
        }
    }

    @discardableResult public func unlinkSuperset(_ id: UUID) -> Bool {
        guard !canRetrySave, let day = selectedDay, let pair = supersets.first(where: { $0.id == id }) else { return false }
        return commit(synchronizeInput: false) { state in
            state.training!.days[day.rawValue]!.removeSuperset(containing: pair.plan.first)
        }
    }

    @discardableResult public func startSuperset(_ id: UUID) -> Bool {
        editSuperset(id, closeInput: true) { group, workout in
            if group.phase == .ready { group.phase = .working }
            group.bindCurrentRow(in: &workout)
            workout.selectedExerciseID = group.currentExerciseID
        }
    }

    public func canAdvanceSuperset(_ id: UUID) -> Bool {
        guard !canRetrySave, let group = workout?.supersets?.first(where: { $0.id == id }),
              group.phase == .working, exercise?.id == group.currentExerciseID,
              let rowID = group.currentRowID, focus == nil || focus?.rowID == rowID,
              let row = rows.first(where: { $0.id == rowID }) else { return false }
        return row.kind?.countsTowardWorkingPlan == true && rowStatus(for: row) == .recorded
    }

    @discardableResult public func advanceSuperset(_ id: UUID) -> Bool {
        guard canAdvanceSuperset(id) else { return false }
        return editSuperset(id, closeInput: true) { group, workout in
            group.completedTurns += 1
            group.timer = nil
            if group.completedTurns == group.plan.rounds * 2 {
                group.phase = .finished
            } else if group.completedTurns.isMultiple(of: 2) {
                group.phase = .resting
                if group.plan.restSeconds > 0 {
                    group.timer = .running(until: now().addingTimeInterval(Double(group.plan.restSeconds)))
                }
            } else {
                group.bindCurrentRow(in: &workout)
            }
            workout.selectedExerciseID = group.currentExerciseID
        }
    }

    @discardableResult public func startNextSupersetRound(_ id: UUID) -> Bool {
        guard supersets.first(where: { $0.id == id })?.phase == .resting else { return false }
        return editSuperset(id, closeInput: true) { group, workout in
            group.phase = .working
            group.timer = nil
            group.bindCurrentRow(in: &workout)
            workout.selectedExerciseID = group.currentExerciseID
        }
    }

    @discardableResult public func setSupersetTimer(_ action: SupersetTimerAction, for id: UUID) -> Bool {
        guard let group = supersets.first(where: { $0.id == id }), group.phase == .resting || group.phase == .working else { return false }
        let instant = now()
        let seconds = group.timer?.remaining(at: instant) ?? 0
        let next: SupersetRestTimer?
        switch action {
        case .start:
            guard group.timer == nil else { return false }
            next = .running(until: instant.addingTimeInterval(Double(group.plan.restSeconds > 0 ? group.plan.restSeconds : 60)))
        case .pause:
            guard group.timer?.isPaused == false, seconds > 0 else { return false }
            next = .paused(seconds: seconds)
        case .resume:
            guard group.timer?.isPaused == true, seconds > 0 else { return false }
            next = .running(until: instant.addingTimeInterval(Double(seconds)))
        case .adjust(let delta):
            guard let timer = group.timer else { return false }
            let adjusted = min(3600, max(0, seconds + min(3600, max(-3600, delta))))
            next = timer.isPaused ? .paused(seconds: adjusted) : .running(until: instant.addingTimeInterval(Double(adjusted)))
        case .end:
            guard group.timer != nil else { return false }
            next = nil
        }
        return editSuperset(id, closeInput: false) { group, _ in group.timer = next }
    }

    private func editSuperset(_ id: UUID, closeInput: Bool,
                              change: (inout WorkoutSuperset, inout DayWorkout) -> Void) -> Bool {
        guard !canRetrySave, let day = selectedDay,
              let index = workout?.supersets?.firstIndex(where: { $0.id == id }) else { return false }
        return commit(synchronizeInput: false, onSuccess: { [weak self] in
            if closeInput {
                self?.revealRowID = self?.supersets.first(where: { $0.id == id })?.currentRowID
            }
        }) { state in
            if closeInput { try finalize(&state) }
            var workout = state.training!.days[day.rawValue]!
            var group = workout.supersets![index]
            change(&group, &workout)
            workout.supersets![index] = group
            state.training!.days[day.rawValue] = workout
        }
    }
}
