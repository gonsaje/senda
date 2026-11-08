import Foundation

public extension TrainingWorkspace {
    static func requiresLegacyReview(_ snapshot: JournalSnapshot) -> Bool {
        guard snapshot.training == nil, let old = snapshot.workspace else { return false }
        if snapshot.legacyBase != nil { return true }
        if old.editor != nil || (old.numberInputDirty && old.selectedField == .sets) { return true }
        return old.sessions.values.contains { if case .editing = $0 { true } else { false } }
    }
    static func migrate(_ snapshot: JournalSnapshot, today: TrainingDay, calendar: Calendar) throws -> TrainingWorkspace {
        guard !requiresLegacyReview(snapshot) else { throw TrainingError.legacyReview }
        let known = Set(Exercise.catalog.map(\.id) + (snapshot.customExercises ?? []).map(\.id))
        let unknown = Set(snapshot.journal.batches.map(\.exerciseID)).subtracting(known)
        if var existing = snapshot.training {
            let retained = Set(existing.legacyExerciseIDs ?? []).union(unknown)
            existing.legacyExerciseIDs = retained.isEmpty ? nil : retained.sorted()
            return existing
        }
        let unit = snapshot.workspace?.weightUnit ?? .pounds
        var result = TrainingWorkspace(visibleWeek: try today.week()[0], preferredUnit: unit, legacyExerciseIDs: unknown.isEmpty ? nil : unknown.sorted())
        for batch in snapshot.journal.batches.enumerated().sorted(by: {
            $0.element.recordedAt == $1.element.recordedAt ? $0.offset < $1.offset : $0.element.recordedAt < $1.element.recordedAt
        }).map(\.element) {
            guard (-62_135_596_800...253_402_300_799).contains(batch.recordedAt.timeIntervalSince1970) else { throw TrainingError.invalidDay }
            let day = try TrainingDay(TrainingDay(batch.recordedAt, calendar: calendar).rawValue)
            var workout = result.days[day.rawValue] ?? DayWorkout(unit: unit)
            if !workout.exerciseIDs.contains(batch.exerciseID) { workout.exerciseIDs.append(batch.exerciseID) }
            workout.selectedExerciseID = workout.selectedExerciseID ?? batch.exerciseID
            workout.rows[batch.exerciseID, default: []].append(contentsOf: batch.sets.map { TrainingRow(set: $0, unit: unit) })
            result.days[day.rawValue] = workout
        }
        if let old = snapshot.workspace {
            var workout = result.days[today.rawValue] ?? DayWorkout(unit: unit)
            let oldOrder = old.workoutExerciseIDs ?? ExerciseLibrary.initialWorkoutIDs
            workout.exerciseIDs = oldOrder + unknown.sorted().filter { workout.rows[$0] != nil && !oldOrder.contains($0) }
            workout.selectedExerciseID = old.selectedExerciseID
            for id in workout.exerciseIDs where workout.rows[id] == nil { workout.rows[id] = [] }
            for (id, phase) in old.sessions {
                guard case .draft(let draft) = phase else { continue }
                let start = workout.rows[id]?.count ?? 0
                var rows = draft.sets.map { TrainingRow(weight: unit.text(for: $0.weight), reps: String($0.reps), unit: unit, canonicalWeight: $0.weight) }
                if id == old.selectedExerciseID, old.numberInputDirty {
                    let indices = old.selectedSetIndex.map { [$0] } ?? Array(rows.indices)
                    for index in indices where rows.indices.contains(index) {
                        if old.selectedField == .weight { rows[index].weight = old.numberInputText; rows[index].weightIsDirty = true }
                        else if old.selectedField == .reps { rows[index].reps = old.numberInputText }
                    }
                }
                workout.rows[id, default: []].append(contentsOf: rows)
                if id == old.selectedExerciseID, !rows.isEmpty, old.selectedSetIndex != nil || old.numberInputDirty {
                    let index = start + min(old.selectedSetIndex ?? 0, rows.count - 1)
                    result.selectedDay = today
                    result.focus = TrainingFocus(day: today, exerciseID: id, rowID: workout.rows[id]![index].id,
                                                 field: old.selectedField == .sets ? .weight : old.selectedField)
                }
            }
            result.days[today.rawValue] = workout
        }
        return try result.validated(against: snapshot.journal, exercises: ExerciseLibrary.validated(custom: snapshot.customExercises ?? []))
    }
}
