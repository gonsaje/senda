import Foundation
import Observation
import SendaDomain
import SendaPersistence

public struct TrainingDaySummary: Equatable, Sendable {
    public let exercises: [String]
    public let muscleGroups: [MuscleGroup]
    public let setCount: Int
}
public struct TrainingPerformanceReference: Equatable, Sendable {
    public let day: TrainingDay
    public let exerciseID: String
    public let rowID: UUID
    public let values: SetValues
}

@Observable @MainActor public final class TrainingNotebookModel {
    public private(set) var snapshot: JournalSnapshot
    public private(set) var errorMessage: String?
    public private(set) var revealRowID: UUID?
    public let isSample: Bool
    public let calendar: Calendar
    @ObservationIgnored private let repository: any JournalRepository
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var lastWritten: JournalSnapshot

    public init(repository: any JournalRepository, isSample: Bool = false, calendar: Calendar = .current,
                now: @escaping () -> Date = Date.init) throws {
        self.repository = repository; self.isSample = isSample; self.calendar = calendar; self.now = now
        let saved = try repository.loadSnapshot().validated()
        lastWritten = saved
        let training = try TrainingWorkspace.migrate(saved, today: TrainingDay(now(), calendar: calendar), calendar: calendar)
        snapshot = try JournalSnapshot(journal: saved.journal, customExercises: saved.customExercises, training: training).validated()
    }
    public var journal: Journal { snapshot.journal }
    public var workspace: TrainingWorkspace { snapshot.training! }
    public var today: TrainingDay { TrainingDay(now(), calendar: calendar) }
    public var selectedDay: TrainingDay? { workspace.selectedDay }
    public var focus: TrainingFocus? { workspace.focus }
    public var workout: DayWorkout? { selectedDay.flatMap { workspace.days[$0.rawValue] } }
    public var exercise: Exercise? { workout?.selectedExerciseID.map { exercise($0) } }
    public var exercises: [Exercise] {
        let known = Exercise.catalog + (snapshot.customExercises ?? [])
        let ids = Set(known.map(\.id))
        return known + (workspace.legacyExerciseIDs ?? []).filter { !ids.contains($0) }.map {
            Exercise(id: $0, name: $0, shortName: $0, startingWeight: 0)
        }
    }
    public var tabs: [Exercise] { workout?.exerciseIDs.map { exercise($0) } ?? [] }
    public var unit: WeightUnit { workout?.unit ?? workspace.preferredUnit }
    public var rows: [TrainingRow] { exercise.flatMap { workout?.rows[$0.id] } ?? [] }
    public var weekDays: [TrainingDay] { (try? workspace.visibleWeek.week()) ?? [] }
    public var weekSetCount: Int { weekDays.reduce(0) { $0 + summary(for: $1).setCount } }
    public var trainingDayCount: Int { weekDays.filter { summary(for: $0).setCount > 0 }.count }
    public var canRepeat: Bool { if let exercise, let last = rows.last { last.parsed(for: exercise) != nil } else { false } }
    public var undoLabel: String? {
        switch workspace.undo { case .repeated: "Set repeated"; case .deleted: "Set removed"; case nil: nil }
    }
    public var saveStatus: String {
        if errorMessage != nil { return "Changes need saving" }
        if focus != nil { return "Editing set" }
        let unfinished = rows.filter { $0.performedSetID == nil }.count
        return unfinished > 0 ? "\(unfinished) unfinished \(unfinished == 1 ? "set" : "sets") kept" : "All changes saved"
    }
    public func exercise(_ id: String) -> Exercise {
        exercises.first { $0.id == id } ?? Exercise(id: id, name: id, shortName: id, startingWeight: 0)
    }
    public func loggedSetCount(for exerciseID: String, on day: TrainingDay) -> Int {
        workspace.days[day.rawValue]?.rows[exerciseID]?.filter { $0.performedSetID != nil }.count ?? 0
    }
    public func summary(for day: TrainingDay) -> TrainingDaySummary {
        guard let workout = workspace.days[day.rawValue] else { return TrainingDaySummary(exercises: [], muscleGroups: [], setCount: 0) }
        let order = workout.exerciseIDs + workout.rows.keys.sorted().filter { !workout.exerciseIDs.contains($0) }
        let performed = order.filter { id in workout.rows[id]?.contains { $0.performedSetID != nil } == true }
        let trained = Set(performed.map { exercise($0).group })
        return TrainingDaySummary(exercises: performed.map { exercise($0).name },
            muscleGroups: MuscleGroup.allCases.filter { trained.contains($0) },
            setCount: workout.rows.values.flatMap { $0 }.filter { $0.performedSetID != nil }.count)
    }
    public var lastReference: TrainingPerformanceReference? {
        guard let selectedDay else { return nil }
        let prior = references.filter { $0.day < selectedDay }
        guard let lastDay = prior.map(\.day).max() else { return nil }
        return best(prior.filter { $0.day == lastDay })
    }
    public var personalBest: TrainingPerformanceReference? { best(references) }
    private var references: [TrainingPerformanceReference] {
        guard let exercise else { return [] }
        return workspace.days.keys.sorted().flatMap { key -> [TrainingPerformanceReference] in
            guard let day = try? TrainingDay(key) else { return [] }
            return (workspace.days[key]?.rows[exercise.id] ?? []).compactMap { row in
                guard let id = row.performedSetID, let set = journal.reference(to: id)?.set else { return nil }
                return TrainingPerformanceReference(day: day, exerciseID: exercise.id, rowID: row.id, values: set.values)
            }
        }
    }
    private func best(_ refs: [TrainingPerformanceReference]) -> TrainingPerformanceReference? {
        refs.enumerated().max {
            if $0.element.values.weight != $1.element.values.weight { return $0.element.values.weight < $1.element.values.weight }
            if $0.element.values.reps != $1.element.values.reps { return $0.element.values.reps < $1.element.values.reps }
            return $0.offset < $1.offset
        }?.element
    }
    @discardableResult public func openDay(_ day: TrainingDay) -> Bool {
        revealRowID = nil
        return commit { state in
            try finalize(&state)
            state.training!.selectedDay = day; state.training!.visibleWeek = try day.week()[0]
            if state.training!.days[day.rawValue] == nil { state.training!.days[day.rawValue] = DayWorkout(unit: state.training!.preferredUnit) }
            state.training!.undo = nil
        }
    }
    @discardableResult public func changeDay(_ direction: Int) -> Bool {
        guard let selectedDay, let destination = try? selectedDay.adding(days: direction < 0 ? -1 : 1) else { return false }
        return openDay(destination)
    }
    @discardableResult public func showWeek() -> Bool {
        revealRowID = nil
        return commit { state in try finalize(&state); state.training!.selectedDay = nil; state.training!.undo = nil }
    }
    @discardableResult public func changeWeek(_ direction: Int) -> Bool {
        commit { state in
            try finalize(&state)
            state.training!.visibleWeek = try state.training!.visibleWeek.adding(days: direction < 0 ? -7 : 7)
            state.training!.selectedDay = nil; state.training!.undo = nil
        }
    }
    @discardableResult public func addExercise(_ id: String) -> Bool {
        guard exercises.contains(where: { $0.id == id }) else { return false }
        return commit { state in try finalize(&state); try add(id, in: &state) }
    }
    @discardableResult public func createExercise(named name: String, group: MuscleGroup, equipment: ExerciseEquipment) -> Bool {
        commit { state in
            let created = try ExerciseLibrary.custom(named: name, existing: exercises, muscleGroup: group, equipment: equipment)
            try finalize(&state)
            state.customExercises = (state.customExercises ?? []) + [created]
            try add(created.id, in: &state)
        }
    }
    private func add(_ id: String, in state: inout JournalSnapshot) throws {
        guard let day = state.training!.selectedDay, var workout = state.training!.days[day.rawValue] else { throw TrainingError.invalidDay }
        if !workout.exerciseIDs.contains(id) { workout.exerciseIDs.append(id) }
        if workout.rows[id] == nil { workout.rows[id] = [TrainingRow(unit: workout.unit)] }
        workout.selectedExerciseID = id
        state.training!.days[day.rawValue] = workout; state.training!.undo = nil
    }
    @discardableResult public func selectExercise(_ id: String) -> Bool {
        commit { state in
            try finalize(&state)
            guard let day = state.training!.selectedDay, state.training!.days[day.rawValue]!.exerciseIDs.contains(id) else { throw TrainingError.missingRow }
            state.training!.days[day.rawValue]!.selectedExerciseID = id; state.training!.undo = nil
        }
    }
    @discardableResult public func removeExercise(_ id: String) -> Bool {
        commit { state in
            try finalize(&state)
            guard let day = state.training!.selectedDay, var workout = state.training!.days[day.rawValue] else { throw TrainingError.invalidDay }
            workout.exerciseIDs.removeAll { $0 == id }
            if workout.selectedExerciseID == id { workout.selectedExerciseID = workout.exerciseIDs.first }
            state.training!.days[day.rawValue] = workout; state.training!.undo = nil
        }
    }
    @discardableResult public func newSet() -> Bool {
        commit { state in
            try finalize(&state)
            let (day, id) = try context(state)
            let row = TrainingRow(unit: state.training!.days[day.rawValue]!.unit)
            state.training!.days[day.rawValue]!.rows[id, default: []].append(row)
            state.training!.focus = TrainingFocus(day: day, exerciseID: id, rowID: row.id,
                                                  field: exercise(id).requiresWeight ? .weight : .reps)
            state.training!.undo = nil
        }
    }
    @discardableResult public func selectInput(_ rowID: UUID, field: NumericField, keyboard: Bool = true) -> Bool {
        guard field != .sets else { return false }
        revealRowID = nil
        return commit { state in
            let (day, id) = try context(state)
            if state.training!.focus?.rowID != rowID { try finalize(&state) }
            guard state.training!.days[day.rawValue]!.rows[id]?.contains(where: { $0.id == rowID }) == true else { throw TrainingError.missingRow }
            state.training!.focus = TrainingFocus(day: day, exerciseID: id, rowID: rowID, field: field, keyboard: keyboard)
        }
    }
    public func inputText(for token: TrainingFocus) -> String {
        guard focus?.id == token.id, let row = focusedRow else { return "" }
        return token.field == .weight ? row.weight : row.reps
    }
    public var focusedRow: TrainingRow? {
        guard let focus else { return nil }
        return workspace.days[focus.day.rawValue]?.rows[focus.exerciseID]?.first { $0.id == focus.rowID }
    }
    public func typeInput(_ text: String, focus token: TrainingFocus) {
        guard focus?.id == token.id, String(text.prefix(64)) != inputText(for: token) else { return }
        _ = commit(recover: true) { state in
            guard state.training!.focus?.id == token.id else { return }
            var rows = state.training!.days[token.day.rawValue]!.rows[token.exerciseID]!
            let index = rows.firstIndex { $0.id == token.rowID }!
            if token.field == .weight { rows[index].weight = String(text.prefix(64)); rows[index].weightIsDirty = true }
            else { rows[index].reps = String(text.prefix(64)) }
            state.training!.days[token.day.rawValue]!.rows[token.exerciseID] = rows
            state.training!.undo = nil
        }
    }
    @discardableResult public func finishEditing() -> Bool { commit { try finalize(&$0) } }
    private func finalize(_ state: inout JournalSnapshot) throws {
        guard let focus = state.training!.focus,
              var rows = state.training!.days[focus.day.rawValue]?.rows[focus.exerciseID],
              let index = rows.firstIndex(where: { $0.id == focus.rowID }) else { state.training!.focus = nil; return }
        let before = state.journal
        var row = rows[index]
        if let value = row.parsed(for: exercise(focus.exerciseID)) {
            let set: PerformedSet
            if let id = row.performedSetID { set = try state.journal.updateSet(id, values: value) }
            else {
                let date = focus.day == today ? now() : focus.day.date(in: calendar)
                set = try state.journal.record(DraftBatch(actionID: row.actionID, exerciseID: focus.exerciseID, sets: [value]), at: date).sets[0]
            }
            row.accept(value, setID: set.id)
        } else if let id = row.performedSetID {
            _ = try state.journal.removeSet(id)
            row.performedSetID = nil; row.actionID = UUID()
        }
        rows[index] = row
        state.training!.days[focus.day.rawValue]!.rows[focus.exerciseID] = rows
        state.training!.focus = nil
        if state.journal != before { state.training!.undo = nil }
    }
    @discardableResult public func changeUnit(_ next: WeightUnit) -> Bool {
        commit { state in
            let (day, _) = try context(state)
            var workout = state.training!.days[day.rawValue]!
            for id in workout.rows.keys {
                var rows = workout.rows[id]!
                for index in rows.indices { guard rows[index].changeUnit(to: next) else { throw TrainingError.incompleteWeight } }
                workout.rows[id] = rows
            }
            workout.unit = next; state.training!.days[day.rawValue] = workout; state.training!.preferredUnit = next
            if let old = state.training!.focus {
                state.training!.focus = TrainingFocus(day: old.day, exerciseID: old.exerciseID, rowID: old.rowID, field: old.field, keyboard: false)
            }
        }
    }
    @discardableResult public func repeatLastSet(actionID: UUID = UUID()) -> Bool {
        if journal.hasConsumedAction(actionID) {
            return rows.contains { $0.actionID == actionID && $0.performedSetID != nil }
        }
        return commit { state in
            try finalize(&state)
            let (day, id) = try context(state)
            guard let previous = state.training!.days[day.rawValue]!.rows[id]?.last,
                  let values = previous.parsed(for: exercise(id)) else { throw TrainingError.missingRow }
            let date = day == today ? now() : day.date(in: calendar)
            let set = try state.journal.record(DraftBatch(actionID: actionID, exerciseID: id, sets: [values]), at: date).sets[0]
            var row = TrainingRow(actionID: actionID, weight: previous.weight.isEmpty ? "" : previous.unit.text(for: values.weight),
                                  reps: String(values.reps), unit: previous.unit, canonicalWeight: values.weight)
            row.performedSetID = set.id
            state.training!.days[day.rawValue]!.rows[id, default: []].append(row)
            state.training!.undo = .repeated(day: day, exerciseID: id, rowID: row.id)
        }
    }
    @discardableResult public func deleteSet(_ rowID: UUID) -> Bool {
        commit { state in
            try finalize(&state)
            let (day, id) = try context(state)
            var rows = state.training!.days[day.rawValue]!.rows[id]!
            guard let index = rows.firstIndex(where: { $0.id == rowID }) else { throw TrainingError.missingRow }
            let row = rows.remove(at: index)
            let removal = try row.performedSetID.map { try state.journal.removeSet($0) }
            state.training!.days[day.rawValue]!.rows[id] = rows
            state.training!.undo = .deleted(day: day, exerciseID: id, index: index, row: row, removal: removal)
        }
    }
    @discardableResult public func undoChange() -> Bool {
        guard focus == nil, let undo = workspace.undo else { return false }
        return commit { state in
            switch undo {
            case .repeated(let day, let id, let rowID):
                var rows = state.training!.days[day.rawValue]!.rows[id]!
                guard let index = rows.firstIndex(where: { $0.id == rowID }), let set = rows[index].performedSetID else { throw TrainingError.missingRow }
                _ = try state.journal.removeSet(set); rows.remove(at: index)
                state.training!.days[day.rawValue]!.rows[id] = rows
            case .deleted(let day, let id, let index, let row, let removal):
                if let removal { _ = try state.journal.restoreSet(removal) }
                var restored = row
                var workout = state.training!.days[day.rawValue]!
                if !restored.changeUnit(to: workout.unit) {
                    // An incomplete deleted weight keeps its original unit. Other
                    // values remain exact while restoring that input context.
                    for key in workout.rows.keys {
                        var current = workout.rows[key]!
                        for i in current.indices { guard current[i].changeUnit(to: row.unit) else { throw TrainingError.incompleteWeight } }
                        workout.rows[key] = current
                    }
                    workout.unit = row.unit
                }
                var rows = workout.rows[id]!
                rows.insert(restored, at: min(index, rows.count)); workout.rows[id] = rows
                state.training!.days[day.rawValue] = workout
            }
            state.training!.undo = nil
        }
    }
    @discardableResult public func openReference(_ reference: TrainingPerformanceReference) -> Bool {
        let result = commit { state in
            try finalize(&state)
            state.training!.selectedDay = reference.day; state.training!.visibleWeek = try reference.day.week()[0]
            try add(reference.exerciseID, in: &state)
        }
        if result { revealRowID = reference.rowID }
        return result
    }
    @discardableResult public func stepInput(increasing: Bool, focus token: TrainingFocus) -> Bool {
        guard focus?.id == token.id, let row = focusedRow else { return false }
        if token.field == .weight {
            guard let current = row.parsedWeight ?? (row.weight.isEmpty ? 0 : nil) else { return false }
            return setInputWeight(row.unit.stepped(current, increasing: increasing), focus: token)
        }
        guard let current = NumericField.reps.parse(row.reps) ?? (row.reps.isEmpty ? 0 : nil) else { return false }
        typeInput(String(min(999, max(1, current + (increasing ? 1 : -1)))), focus: token)
        return true
    }
    @discardableResult public func setInputWeight(_ weight: Int, focus token: TrainingFocus) -> Bool {
        guard focus?.id == token.id, token.field == .weight, NumericField.weight.range.contains(weight) else { return false }
        return commit(recover: true) { state in
            var rows = state.training!.days[token.day.rawValue]!.rows[token.exerciseID]!
            let index = rows.firstIndex { $0.id == token.rowID }!
            rows[index].canonicalWeight = weight; rows[index].weightIsDirty = false; rows[index].weight = rows[index].unit.text(for: weight)
            state.training!.days[token.day.rawValue]!.rows[token.exerciseID] = rows; state.training!.undo = nil
        }
    }
    public func dismissError() { errorMessage = nil }
    @discardableResult public func flushRecovery() -> Bool { commit { _ in } }
    private func context(_ state: JournalSnapshot) throws -> (TrainingDay, String) {
        guard let day = state.training!.selectedDay, let id = state.training!.days[day.rawValue]?.selectedExerciseID else { throw TrainingError.missingRow }
        return (day, id)
    }
    private func commit(recover: Bool = false, _ update: (inout JournalSnapshot) throws -> Void) -> Bool {
        var candidate = snapshot
        do { try update(&candidate); _ = try candidate.validated() }
        catch { errorMessage = error.localizedDescription; return false }
        do {
            if candidate != lastWritten { try repository.saveSnapshot(candidate) }
            lastWritten = candidate; snapshot = candidate; errorMessage = nil
            return true
        } catch {
            if recover && candidate.journal == snapshot.journal { snapshot = candidate }
            errorMessage = error.localizedDescription; return false
        }
    }
}
