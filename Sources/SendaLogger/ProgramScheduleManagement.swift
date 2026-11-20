import Foundation
import SendaDomain

public enum ProgramScheduleAction: Equatable, Sendable {
    case move(firstDay: TrainingDay)
    case end
}

public struct ProgramScheduleChange: Equatable, Sendable {
    public struct Entry: Identifiable, Equatable, Sendable {
        public var id: TrainingDay { day }
        public let day: TrainingDay
        public let title: String
        public let destination: TrainingDay?
    }

    public let enrollment: ProgramEnrollment
    public let action: ProgramScheduleAction
    public let changes: [Entry]
    public let preserved: [Entry]
    public let conflicts: [TrainingDay]
    public var canApply: Bool {
        guard conflicts.isEmpty else { return false }
        switch action {
        case .move: return changes.contains { $0.day != $0.destination }
        case .end: return true
        }
    }

    fileprivate let before: [TrainingDay: DayWorkout]
    fileprivate let after: [TrainingDay: DayWorkout]
    fileprivate let affected: Set<TrainingDay>
    fileprivate let enrollmentAfter: ProgramEnrollment?
}

extension TrainingNotebookModel {
    public func scheduledWorkoutDates(_ enrollment: ProgramEnrollment) -> [TrainingDay] {
        workspace.days.compactMap { day, workout in
            guard let reference = workout.programSession, reference.programID == enrollment.programID,
                  reference.start == enrollment.start else { return nil }
            return TrainingDay(rawValue: day)
        }.sorted()
    }

    public func previewScheduleChange(_ enrollment: ProgramEnrollment, action: ProgramScheduleAction) throws -> ProgramScheduleChange {
        guard enrollment.endedOn == nil, workspace.activeProgramEnrollments.contains(enrollment) else { throw ProgramError.scheduleChanged }
        var movable: [(day: TrainingDay, workout: DayWorkout, title: String)] = []
        var preserved: [ProgramScheduleChange.Entry] = []
        let dates = scheduledWorkoutDates(enrollment)
        // Older schedules did not store original units. Keep mixed-unit legacy sessions
        // in place because a unit change may be their only individual edit.
        let legacyUnits = Set(dates.compactMap { day -> WeightUnit? in
            guard let workout = workspace.days[day.rawValue], workout.programSession?.initialUnit == nil else { return nil }
            return workout.unit
        })
        let legacyUnit = legacyUnits.count == 1 ? legacyUnits.first : nil
        for day in dates {
            guard let workout = workspace.days[day.rawValue], let ref = workout.programSession,
                  let (_, prescription) = enrollment.prescription(for: ref) else { throw ProgramError.scheduleChanged }
            if day >= today, !isBeingEdited(day), workout.matchesScheduledPrescription(prescription, originalUnit: ref.initialUnit ?? legacyUnit) {
                movable.append((day, workout, ref.sessionTitle))
            } else {
                preserved.append(.init(day: day, title: ref.sessionTitle, destination: nil))
            }
        }

        var shift: Int?
        if case let .move(firstDay) = action {
            guard firstDay >= today else { throw ProgramError.invalidMoveDate }
            if let first = movable.first?.day {
                shift = try first.days(until: firstDay)
            }
        }
        let sources = Set(movable.map(\.day))
        var changes: [ProgramScheduleChange.Entry] = []
        var conflicts: [TrainingDay] = []
        var after: [TrainingDay: DayWorkout] = [:]
        // The selected day needs an empty workout even when its session moves away.
        if let day = workspace.selectedDay, sources.contains(day), let workout = workspace.days[day.rawValue] {
            after[day] = DayWorkout(unit: workout.unit)
        }
        for (day, workout, title) in movable {
            let destination = try shift.map { try day.adding(days: $0) }
            if let destination {
                if !sources.contains(destination) && (isBeingEdited(destination) || workspace.days[destination.rawValue]?.occupiesProgramDate == true) {
                    conflicts.append(destination)
                }
                var relocated = workout
                relocated.programSession?.rescheduledTo = destination
                after[destination] = relocated
            }
            changes.append(.init(day: day, title: title, destination: destination))
        }

        let affected = sources.union(after.keys)
        let before: [TrainingDay: DayWorkout] = Dictionary(uniqueKeysWithValues: affected.compactMap { day in
            workspace.days[day.rawValue].map { (day, $0) }
        })
        var enrollmentAfter: ProgramEnrollment? = enrollment
        if case .end = action {
            enrollmentAfter?.endedOn = today
            // Keep the frozen prescription while a reset workout can still be restored.
            let reservedForUndo: Bool
            if case let .removedFromWorkout(_, _, original, _)? = workspace.undo {
                reservedForUndo = original.programSession?.programID == enrollment.programID && original.programSession?.start == enrollment.start
            } else { reservedForUndo = false }
            if preserved.isEmpty && !reservedForUndo { enrollmentAfter = nil }
        }
        return ProgramScheduleChange(enrollment: enrollment, action: action, changes: changes, preserved: preserved,
                                     conflicts: conflicts, before: before, after: after, affected: affected, enrollmentAfter: enrollmentAfter)
    }

    @discardableResult public func applyScheduleChange(_ change: ProgramScheduleChange) -> Bool {
        commit(synchronizeInput: false) { state in
            guard change.canApply else { throw ProgramError.dateConflict }
            if scheduleMatches(change, applied: true) { return }
            let current = try previewScheduleChange(change.enrollment, action: change.action)
            guard current == change else { throw ProgramError.scheduleChanged }
            updateSchedule(change, undo: false, in: &state.training!)
        }
    }

    @discardableResult public func undoScheduleChange(_ change: ProgramScheduleChange) -> Bool {
        commit(synchronizeInput: false) { state in
            if scheduleMatches(change, applied: false) { return }
            guard scheduleMatches(change, applied: true), !change.affected.contains(where: isBeingEdited) else {
                throw ProgramError.scheduleChanged
            }
            updateSchedule(change, undo: true, in: &state.training!)
        }
    }

    private func scheduleMatches(_ change: ProgramScheduleChange, applied: Bool) -> Bool {
        let enrollment = workspace.programEnrollments?.first {
            $0.programID == change.enrollment.programID && $0.start == change.enrollment.start
        }
        let days = applied ? change.after : change.before
        return enrollment == (applied ? change.enrollmentAfter : change.enrollment) &&
            change.affected.allSatisfy { workspace.days[$0.rawValue] == days[$0] }
    }

    private func isBeingEdited(_ day: TrainingDay) -> Bool {
        workspace.focus?.day == day || (workspace.undo != nil && workspace.selectedDay == day)
    }

    private func updateSchedule(_ change: ProgramScheduleChange, undo: Bool, in workspace: inout TrainingWorkspace) {
        let values = undo ? change.before : change.after
        for day in change.affected {
            if values[day] == nil, day == workspace.selectedDay {
                workspace.days[day.rawValue] = DayWorkout(unit: workspace.days[day.rawValue]?.unit ?? workspace.preferredUnit)
            } else { workspace.days[day.rawValue] = values[day] }
        }
        var enrollments = workspace.programEnrollments ?? []
        let index = enrollments.firstIndex { $0.programID == change.enrollment.programID && $0.start == change.enrollment.start }
        if let updated = undo ? change.enrollment : change.enrollmentAfter {
            if let index { enrollments[index] = updated } else { enrollments.append(updated) }
        } else if let index { enrollments.remove(at: index) }
        workspace.programEnrollments = enrollments.isEmpty ? nil : enrollments
    }
}

extension DayWorkout {
    var occupiesProgramDate: Bool {
        !exerciseIDs.isEmpty || !rows.isEmpty || exercisePlans?.isEmpty == false || programSession != nil
    }

    fileprivate func matchesScheduledPrescription(_ session: ProgramSession, originalUnit: WeightUnit?) -> Bool {
        let ids = session.exercises.map(\.exerciseID)
        let plans = Dictionary(uniqueKeysWithValues: session.exercises.map { ($0.exerciseID, $0.plan) })
        guard unit == originalUnit, exerciseIDs == ids, rows.count == ids.count, exercisePlans == plans,
              (supersets ?? []).map(\.plan) == session.supersets, (supersets ?? []).allSatisfy({ $0.phase == .ready })
        else { return false }
        return ids.allSatisfy { id in
            guard let entries = rows[id], entries.count == 1, let row = entries.first else { return false }
            return row == TrainingRow(id: row.id, actionID: row.actionID, unit: unit, kind: .working)
        }
    }
}
