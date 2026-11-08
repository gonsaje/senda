import Foundation

public struct TrainingRow: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var actionID: UUID
    public var weight: String
    public var reps: String
    public var unit: WeightUnit
    public var canonicalWeight: Int?
    public var weightIsDirty: Bool
    public var performedSetID: UUID?
    public init(id: UUID = UUID(), actionID: UUID = UUID(), weight: String = "", reps: String = "", unit: WeightUnit,
                canonicalWeight: Int? = nil, weightIsDirty: Bool = false, performedSetID: UUID? = nil) {
        self.id = id; self.actionID = actionID; self.weight = weight; self.reps = reps; self.unit = unit
        self.canonicalWeight = canonicalWeight; self.weightIsDirty = weightIsDirty; self.performedSetID = performedSetID
    }
    public init(set: PerformedSet, unit: WeightUnit) {
        self.init(id: set.id, weight: unit.text(for: set.values.weight), reps: String(set.values.reps), unit: unit,
                  canonicalWeight: set.values.weight, performedSetID: set.id)
    }
    public var parsedWeight: Int? {
        guard !weight.isEmpty else { return nil }
        if !weightIsDirty, let canonicalWeight { return canonicalWeight }
        return unit.parse(weight)
    }
    public func parsed(for exercise: Exercise) -> SetValues? {
        guard let reps = NumericField.reps.parse(reps) else { return nil }
        let value = weight.isEmpty && !exercise.requiresWeight ? 0 : parsedWeight
        guard let value else { return nil }
        return SetValues(weight: value, reps: reps)
    }
    @discardableResult public mutating func changeUnit(to next: WeightUnit) -> Bool {
        guard next != unit else { return true }
        if weight.isEmpty { unit = next; return true }
        guard let value = parsedWeight else { return false }
        canonicalWeight = value; weightIsDirty = false; unit = next; weight = next.text(for: value)
        return true
    }
    public mutating func accept(_ values: SetValues, setID: UUID) {
        if !weight.isEmpty { weight = unit.text(for: values.weight) }
        reps = String(values.reps); canonicalWeight = values.weight; weightIsDirty = false; performedSetID = setID
    }
}

public struct DayWorkout: Codable, Equatable, Sendable {
    public var exerciseIDs: [String]
    public var selectedExerciseID: String?
    public var rows: [String: [TrainingRow]]
    public var unit: WeightUnit
    public init(exerciseIDs: [String] = [], selectedExerciseID: String? = nil,
                rows: [String: [TrainingRow]] = [:], unit: WeightUnit = .pounds) {
        self.exerciseIDs = exerciseIDs; self.selectedExerciseID = selectedExerciseID; self.rows = rows; self.unit = unit
    }
}
public struct TrainingFocus: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let day: TrainingDay
    public let exerciseID: String
    public let rowID: UUID
    public let field: NumericField
    public let keyboard: Bool
    public init(id: UUID = UUID(), day: TrainingDay, exerciseID: String, rowID: UUID, field: NumericField, keyboard: Bool = true) {
        self.id = id; self.day = day; self.exerciseID = exerciseID; self.rowID = rowID; self.field = field; self.keyboard = keyboard
    }
}
public enum TrainingUndo: Codable, Equatable, Sendable {
    case repeated(day: TrainingDay, exerciseID: String, rowID: UUID)
    case deleted(day: TrainingDay, exerciseID: String, index: Int, row: TrainingRow, removal: RemovedTrainingSet?)
}
public struct TrainingWorkspace: Codable, Equatable, Sendable {
    public var visibleWeek: TrainingDay
    public var selectedDay: TrainingDay?
    public var preferredUnit: WeightUnit
    public var days: [String: DayWorkout]
    public var focus: TrainingFocus?
    public var undo: TrainingUndo?
    public init(visibleWeek: TrainingDay, selectedDay: TrainingDay? = nil, preferredUnit: WeightUnit = .pounds,
                days: [String: DayWorkout] = [:], focus: TrainingFocus? = nil, undo: TrainingUndo? = nil) {
        self.visibleWeek = visibleWeek; self.selectedDay = selectedDay; self.preferredUnit = preferredUnit
        self.days = days; self.focus = focus; self.undo = undo
    }
    public func validated(against journal: Journal, exercises: [Exercise]) throws -> TrainingWorkspace {
        let known = Set(exercises.map(\.id) + journal.batches.map(\.exerciseID))
        let samples = journal.batches.flatMap { batch in batch.sets.map { ($0.id, (batch.exerciseID, $0.values)) } }
        guard Set(samples.map { $0.0 }).count == samples.count else { throw TrainingError.invalidWorkspace }
        let sets = Dictionary(uniqueKeysWithValues: samples)
        var rowIDs = Set<UUID>(), links = Set<UUID>(), actions = Set<UUID>()
        guard try visibleWeek.week().first == visibleWeek else { throw TrainingError.invalidWorkspace }
        for (key, day) in days {
            _ = try TrainingDay(key)
            guard Set(day.exerciseIDs).count == day.exerciseIDs.count,
                  day.exerciseIDs.allSatisfy({ known.contains($0) && day.rows[$0] != nil }),
                  day.selectedExerciseID.map(day.exerciseIDs.contains) ?? day.exerciseIDs.isEmpty else { throw TrainingError.invalidWorkspace }
            for (exercise, rows) in day.rows {
                guard known.contains(exercise) else { throw TrainingError.invalidWorkspace }
                for row in rows {
                    guard rowIDs.insert(row.id).inserted, actions.insert(row.actionID).inserted,
                          row.weight.count <= 64, row.reps.count <= 64, row.unit == day.unit,
                          row.canonicalWeight.map(NumericField.weight.range.contains) ?? true else { throw TrainingError.invalidWorkspace }
                    if !row.weightIsDirty && !row.weight.isEmpty {
                        guard let canonical = row.canonicalWeight, row.weight == row.unit.text(for: canonical) else { throw TrainingError.invalidWorkspace }
                    }
                    if let id = row.performedSetID {
                        guard sets[id]?.0 == exercise, links.insert(id).inserted else { throw TrainingError.invalidWorkspace }
                        if focus?.rowID != row.id {
                            let description = exercises.first { $0.id == exercise } ?? Exercise(id: exercise, name: exercise, shortName: exercise, startingWeight: 0)
                            guard row.parsed(for: description) == sets[id]?.1 else { throw TrainingError.invalidWorkspace }
                        }
                    } else if journal.hasConsumedAction(row.actionID) { throw TrainingError.invalidWorkspace }
                }
            }
        }
        guard links == Set(sets.keys), selectedDay.map({ days[$0.rawValue] != nil }) ?? true else { throw TrainingError.invalidWorkspace }
        if let focus {
            guard selectedDay == focus.day, focus.field != .sets,
                  let day = days[focus.day.rawValue], day.selectedExerciseID == focus.exerciseID,
                  day.rows[focus.exerciseID]?.contains(where: { $0.id == focus.rowID }) == true else { throw TrainingError.invalidWorkspace }
        }
        if let undo {
            switch undo {
            case .repeated(let day, let exercise, let rowID):
                guard let row = days[day.rawValue]?.rows[exercise]?.first(where: { $0.id == rowID }), row.performedSetID != nil else { throw TrainingError.invalidWorkspace }
            case .deleted(let day, let exercise, let index, let row, let removal):
                guard let rows = days[day.rawValue]?.rows[exercise], index >= 0, index <= rows.count,
                      !rowIDs.contains(row.id), !actions.contains(row.actionID), row.unit == days[day.rawValue]?.unit,
                      row.weight.count <= 64, row.reps.count <= 64 else { throw TrainingError.invalidWorkspace }
                if let removal {
                    guard removal.batch.exerciseID == exercise, row.performedSetID == removal.set.id else { throw TrainingError.invalidWorkspace }
                    var restored = journal
                    _ = try restored.restoreSet(removal)
                    _ = try restored.validated()
                } else if row.performedSetID != nil { throw TrainingError.invalidWorkspace }
            }
        }
        return self
    }
}
