import Foundation

public struct TrainingRow: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var actionID: UUID
    public var weight: String
    public var reps: String
    public var unit: WeightUnit
    public var canonicalWeight: Int?
    /// The portion of this set's total supplied by the bar, in hundredths of a pound.
    public var barbellWeight: Int?
    public var weightIsDirty: Bool
    public var performedSetID: UUID?
    /// A durable draft correction. The linked performed set remains the source of recorded values.
    public var pendingCorrection: Bool?
    /// Missing legacy metadata remains unknown until the user classifies the set.
    public var kind: TrainingSetKind?
    /// Optional reported reserve; 5 represents five or more reps left.
    public var repsInReserve: Int?
    public var dropGroupID: UUID?
    public init(id: UUID = UUID(), actionID: UUID = UUID(), weight: String = "", reps: String = "", unit: WeightUnit,
                canonicalWeight: Int? = nil, weightIsDirty: Bool = false, performedSetID: UUID? = nil, pendingCorrection: Bool? = nil,
                kind: TrainingSetKind? = nil, repsInReserve: Int? = nil, dropGroupID: UUID? = nil) {
        self.id = id; self.actionID = actionID; self.weight = weight; self.reps = reps; self.unit = unit
        self.canonicalWeight = canonicalWeight; self.weightIsDirty = weightIsDirty; self.performedSetID = performedSetID
        self.pendingCorrection = pendingCorrection
        self.kind = kind; self.repsInReserve = repsInReserve; self.dropGroupID = dropGroupID
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
        // A recorded bodyweight load may still be blank after a custom exercise is retagged.
        let recordedZero = performedSetID != nil && canonicalWeight == 0 && !weightIsDirty && exercise.presetID == nil
        let value = weight.isEmpty && (!exercise.requiresWeight || recordedZero) ? 0 : parsedWeight
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
        if let barbellWeight, barbellWeight > values.weight { self.barbellWeight = nil }
        reps = String(values.reps); canonicalWeight = values.weight; weightIsDirty = false; performedSetID = setID; pendingCorrection = nil
    }
}

public struct TrainingSetEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let rows: [TrainingRow]
    public var dropGroupID: UUID? { rows.first?.dropGroupID }
    public var isDropSet: Bool { rows.first?.kind == .dropSet }

    public static func grouping(_ rows: [TrainingRow]) -> [TrainingSetEntry] {
        var entries: [TrainingSetEntry] = []
        var index = 0
        while index < rows.count {
            let row = rows[index]
            var end = index + 1
            if let group = row.dropGroupID {
                while end < rows.count, rows[end].dropGroupID == group { end += 1 }
            }
            entries.append(TrainingSetEntry(id: row.dropGroupID ?? row.id, rows: Array(rows[index..<end])))
            index = end
        }
        return entries
    }
}

public struct DayWorkout: Codable, Equatable, Sendable {
    public var exerciseIDs: [String]
    public var selectedExerciseID: String?
    public var rows: [String: [TrainingRow]]
    public var unit: WeightUnit
    public var exercisePlans: [String: ExercisePlan]?
    public var programSession: ScheduledProgramReference?
    public var supersets: [WorkoutSuperset]?
    public init(exerciseIDs: [String] = [], selectedExerciseID: String? = nil,
                rows: [String: [TrainingRow]] = [:], unit: WeightUnit = .pounds,
                exercisePlans: [String: ExercisePlan]? = nil, supersets: [WorkoutSuperset]? = nil) {
        self.exerciseIDs = exerciseIDs; self.selectedExerciseID = selectedExerciseID; self.rows = rows; self.unit = unit
        self.exercisePlans = exercisePlans
        self.supersets = supersets
    }
}
/// A removal affects the selected date's workout, including any hidden exercise rows.
public enum TrainingWorkoutRemoval: Codable, Equatable, Sendable {
    case exercise(String)
    case workout

    public func remainingWorkout(from original: DayWorkout) throws -> DayWorkout {
        switch self {
        case .workout:
            guard !original.rows.isEmpty else { throw TrainingError.missingRow }
            return DayWorkout(unit: original.unit)
        case .exercise(let id):
            guard original.rows[id] != nil else { throw TrainingError.missingRow }
            var remaining = original
            remaining.removeSuperset(containing: id)
            remaining.rows[id] = nil
            remaining.exercisePlans?[id] = nil
            if remaining.exercisePlans?.isEmpty == true { remaining.exercisePlans = nil }
            if let index = remaining.exerciseIDs.firstIndex(of: id) {
                remaining.exerciseIDs.remove(at: index)
                if remaining.selectedExerciseID == id {
                    remaining.selectedExerciseID = remaining.exerciseIDs.dropFirst(index).first ?? remaining.exerciseIDs.last
                }
            }
            if remaining.rows.isEmpty { remaining.programSession = nil }
            return remaining
        }
    }
}

public struct TrainingFocus: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let day: TrainingDay
    public let exerciseID: String
    public let rowID: UUID
    public let field: NumericField
    public var keyboard: Bool
    public init(id: UUID = UUID(), day: TrainingDay, exerciseID: String, rowID: UUID, field: NumericField, keyboard: Bool = true) {
        self.id = id; self.day = day; self.exerciseID = exerciseID; self.rowID = rowID; self.field = field; self.keyboard = keyboard
    }
}
public enum TrainingUndo: Codable, Equatable, Sendable {
    case hidSuperset(day: TrainingDay, id: UUID, index: Int, selected: String)
    case unpaired(day: TrainingDay, group: WorkoutSuperset, index: Int)
    case removedFromWorkout(day: TrainingDay, target: TrainingWorkoutRemoval, original: DayWorkout, removal: RemovedTrainingSets)
    case repeated(day: TrainingDay, exerciseID: String, rowID: UUID)
    case deleted(day: TrainingDay, exerciseID: String, index: Int, row: TrainingRow, removal: RemovedTrainingSet?)
    case deletedSupersetSet(day: TrainingDay, exerciseID: String, index: Int, row: TrainingRow, removal: RemovedTrainingSet?, superset: SupersetSetUndo)
    case repeatedGroup(day: TrainingDay, exerciseID: String, rowIDs: [UUID])
    case deletedGroup(day: TrainingDay, exerciseID: String, index: Int, rows: [TrainingRow], removal: RemovedTrainingSets)

    package var supersetSetUndo: SupersetSetUndo? {
        if case let .deletedSupersetSet(_, _, _, _, _, superset) = self { return superset }
        return nil
    }

    package var invalidatedByWorkoutEditOn: TrainingDay? {
        switch self {
        case let .hidSuperset(day, _, _, _), let .unpaired(day, _, _), let .removedFromWorkout(day, _, _, _), let .deletedSupersetSet(day, _, _, _, _, _): day
        default: nil
        }
    }
}
public struct TrainingWorkspace: Codable, Equatable, Sendable {
    public var visibleWeek: TrainingDay
    public var selectedDay: TrainingDay?
    public var preferredUnit: WeightUnit
    public var days: [String: DayWorkout]
    public var focus: TrainingFocus?
    public var undo: TrainingUndo?
    public var legacyExerciseIDs: [String]?
    public var programs: [TrainingProgram]?
    public var programEnrollments: [ProgramEnrollment]?
    public var workoutTemplates: [WorkoutTemplate]?
    public var trackedStrengthExerciseIDs: [String]?
    public init(visibleWeek: TrainingDay, selectedDay: TrainingDay? = nil, preferredUnit: WeightUnit = .pounds,
                days: [String: DayWorkout] = [:], focus: TrainingFocus? = nil, undo: TrainingUndo? = nil,
                legacyExerciseIDs: [String]? = nil, workoutTemplates: [WorkoutTemplate]? = nil,
                trackedStrengthExerciseIDs: [String]? = nil) {
        self.visibleWeek = visibleWeek; self.selectedDay = selectedDay; self.preferredUnit = preferredUnit
        self.days = days; self.focus = focus; self.undo = undo; self.legacyExerciseIDs = legacyExerciseIDs
        self.workoutTemplates = workoutTemplates
        self.trackedStrengthExerciseIDs = trackedStrengthExerciseIDs
    }
    private enum CodingKeys: String, CodingKey {
        case visibleWeek, selectedDay, preferredUnit, days, focus, undo, legacyExerciseIDs, workoutTemplates
        case trackedStrengthExerciseIDs, programs, programEnrollments
    }

    /// The file writer reuses unchanged encoded days; backups use the same metadata with every day inline.
    package struct StorageHeader: Encodable {
        let workspace: TrainingWorkspace

        public func encode(to encoder: any Encoder) throws {
            var fields = encoder.container(keyedBy: CodingKeys.self)
            try fields.encode(workspace.visibleWeek, forKey: .visibleWeek)
            try fields.encodeIfPresent(workspace.selectedDay, forKey: .selectedDay)
            try fields.encode(workspace.preferredUnit, forKey: .preferredUnit)
            try fields.encodeIfPresent(workspace.focus, forKey: .focus)
            try fields.encodeIfPresent(workspace.undo, forKey: .undo)
            try fields.encodeIfPresent(workspace.legacyExerciseIDs, forKey: .legacyExerciseIDs)
            try fields.encodeIfPresent(workspace.programs, forKey: .programs)
            try fields.encodeIfPresent(workspace.programEnrollments, forKey: .programEnrollments)
            try fields.encodeIfPresent(workspace.workoutTemplates, forKey: .workoutTemplates)
            try fields.encodeIfPresent(workspace.trackedStrengthExerciseIDs, forKey: .trackedStrengthExerciseIDs)
        }
    }

    package var storageHeader: StorageHeader { StorageHeader(workspace: self) }

    public func encode(to encoder: any Encoder) throws {
        try storageHeader.encode(to: encoder)
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(days, forKey: .days)
    }

    public func validated(against journal: Journal, exercises: [Exercise]) throws -> TrainingWorkspace {
        let legacy = legacyExerciseIDs ?? []
        guard Set(legacy).count == legacy.count, legacy.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 80 }) else { throw TrainingError.invalidWorkspace }
        let exercisesByID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let known = Set(exercisesByID.keys).union(journal.batches.map(\.exerciseID)).union(legacy)
        let enrollments = try validatePrograms(knownExercises: known)
        var templateIDs = Set<UUID>()
        var templateNames = Set<String>()
        for workout in workoutTemplates ?? [] {
            _ = try workout.validated(against: known)
            guard let id = UUID(uuidString: workout.id), templateIDs.insert(id).inserted else {
                throw WorkoutTemplateError.invalidID
            }
            let name = workout.name.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            guard templateNames.insert(name).inserted else { throw WorkoutTemplateError.duplicateName }
        }
        var sets: [UUID: (String, SetValues)] = [:]
        for batch in journal.batches {
            for set in batch.sets {
                guard sets.updateValue((batch.exerciseID, set.values), forKey: set.id) == nil else { throw TrainingError.invalidWorkspace }
            }
        }
        // Repeated loads are common within and across days. Format each canonical load once.
        var displayedWeights: [WeightUnit: [Int: String]] = [:]
        var rowIDs = Set<UUID>(), links = Set<UUID>(), actions = Set<UUID>(), groupIDs = Set<UUID>()
        guard try visibleWeek.week().first == visibleWeek else { throw TrainingError.invalidWorkspace }
        var scheduledSlots = Set<ScheduledProgramReference.Slot>()
        for (key, day) in days {
            let date = try TrainingDay(key)
            if let session = day.programSession {
                guard scheduledSlots.insert(session.slot).inserted else { throw TrainingError.invalidWorkspace }
                try session.validate(day: date, enrollments: enrollments)
            }
            guard Set(day.exerciseIDs).count == day.exerciseIDs.count,
                  day.exerciseIDs.allSatisfy({ known.contains($0) && day.rows[$0] != nil }),
                  day.selectedExerciseID.map(day.exerciseIDs.contains) ?? day.exerciseIDs.isEmpty else { throw TrainingError.invalidWorkspace }
            try day.validateSupersets()
            for (exercise, plan) in day.exercisePlans ?? [:] {
                guard day.rows[exercise] != nil else { throw TrainingError.invalidWorkspace }
                _ = try plan.validated()
            }
            for (exercise, rows) in day.rows {
                guard known.contains(exercise) else { throw TrainingError.invalidWorkspace }
                var previousGroup: UUID?
                for row in rows {
                    if let group = row.dropGroupID {
                        guard row.kind == .dropSet else { throw TrainingError.invalidWorkspace }
                        if group != previousGroup {
                            guard groupIDs.insert(group).inserted else { throw TrainingError.invalidWorkspace }
                        }
                    }
                    previousGroup = row.dropGroupID
                    guard rowIDs.insert(row.id).inserted, actions.insert(row.actionID).inserted,
                          row.weight.count <= 64, row.reps.count <= 64, row.unit == day.unit,
                          row.canonicalWeight.map(NumericField.weight.range.contains) ?? true,
                          row.barbellWeight.map({ $0 > 0 && $0 <= (row.parsedWeight ?? 0) }) ?? true,
                          row.repsInReserve.map({ (0...5).contains($0) }) ?? true else { throw TrainingError.invalidWorkspace }
                    if !row.weightIsDirty && !row.weight.isEmpty {
                        guard let canonical = row.canonicalWeight else { throw TrainingError.invalidWorkspace }
                        if displayedWeights[row.unit]?[canonical] == nil {
                            displayedWeights[row.unit, default: [:]][canonical] = row.unit.text(for: canonical)
                        }
                        guard row.weight == displayedWeights[row.unit]?[canonical] else { throw TrainingError.invalidWorkspace }
                    }
                    if let id = row.performedSetID {
                        guard sets[id]?.0 == exercise, links.insert(id).inserted else { throw TrainingError.invalidWorkspace }
                        if focus?.rowID != row.id && row.pendingCorrection != true {
                            let description = exercisesByID[exercise] ?? Exercise(id: exercise, name: exercise, shortName: exercise, startingWeight: 0)
                            guard row.parsed(for: description) == sets[id]?.1 else { throw TrainingError.invalidWorkspace }
                        }
                    } else if row.pendingCorrection == true || journal.hasConsumedAction(row.actionID) { throw TrainingError.invalidWorkspace }
                }
            }
        }
        guard links.count == sets.count, groupIDs.isDisjoint(with: rowIDs), groupIDs.isDisjoint(with: sets.keys),
              selectedDay.map({ days[$0.rawValue] != nil }) ?? true else { throw TrainingError.invalidWorkspace }
        if let focus {
            guard selectedDay == focus.day, focus.field != .sets,
                  let day = days[focus.day.rawValue], day.selectedExerciseID == focus.exerciseID,
                  day.rows[focus.exerciseID]?.contains(where: { $0.id == focus.rowID }) == true else { throw TrainingError.invalidWorkspace }
        }
        if let undo {
            switch undo {
            case .hidSuperset(let day, let id, let index, let selected):
                guard var workout = days[day.rawValue] else { throw TrainingError.invalidWorkspace }
                try workout.restoreHiddenSuperset(id, at: index, selected: selected)
            case .unpaired(let day, let group, let index):
                guard var workout = days[day.rawValue], (0...(workout.supersets?.count ?? 0)).contains(index) else {
                    throw TrainingError.invalidWorkspace
                }
                var groups = workout.supersets ?? []
                groups.insert(group, at: index)
                workout.supersets = groups
                try workout.validateSupersets()
            case .removedFromWorkout(let day, let target, let original, let removal):
                let remaining = try target.remainingWorkout(from: original)
                guard days[day.rawValue] == remaining else { throw TrainingError.invalidWorkspace }
                var restoredJournal = journal
                _ = try restoredJournal.restoreSets(removal)
                var restored = self
                restored.undo = nil
                restored.days[day.rawValue] = original
                _ = try restored.validated(against: restoredJournal, exercises: exercises)
            case .repeated(let day, let exercise, let rowID):
                guard let row = days[day.rawValue]?.rows[exercise]?.first(where: { $0.id == rowID }), row.performedSetID != nil else { throw TrainingError.invalidWorkspace }
            case .deleted(let day, let exercise, let index, let row, let removal),
                 .deletedSupersetSet(let day, let exercise, let index, let row, let removal, _):
                guard let rows = days[day.rawValue]?.rows[exercise], index >= 0, index <= rows.count,
                      !rowIDs.contains(row.id), !actions.contains(row.actionID),
                      row.weight.count <= 64, row.reps.count <= 64,
                      row.repsInReserve.map({ (0...5).contains($0) }) ?? true else { throw TrainingError.invalidWorkspace }
                var restoredJournal = journal
                if let removal {
                    guard removal.batch.exerciseID == exercise, row.performedSetID == removal.set.id else { throw TrainingError.invalidWorkspace }
                    _ = try restoredJournal.restoreSet(removal)
                    _ = try restoredJournal.validated()
                } else if row.performedSetID != nil || row.pendingCorrection == true { throw TrainingError.invalidWorkspace }
                try validateRestoredRows([row], on: day, exerciseID: exercise, at: index, journal: restoredJournal,
                                         exercises: exercises, superset: undo.supersetSetUndo)
            case .repeatedGroup(let day, let exercise, let ids):
                guard !ids.isEmpty, Set(ids).count == ids.count,
                      let rows = days[day.rawValue]?.rows[exercise],
                      TrainingSetEntry.grouping(rows).contains(where: {
                          $0.dropGroupID != nil && $0.rows.map(\.id) == ids && $0.rows.allSatisfy { $0.performedSetID != nil }
                      }) else { throw TrainingError.invalidWorkspace }
            case .deletedGroup(let day, let exercise, let index, let deleted, let removal):
                guard let current = days[day.rawValue]?.rows[exercise], index >= 0, index <= current.count,
                      let group = deleted.first?.dropGroupID, !deleted.isEmpty,
                      deleted.allSatisfy({ $0.dropGroupID == group && $0.kind == .dropSet }),
                      !groupIDs.contains(group),
                      Set(deleted.map(\.id)).isDisjoint(with: rowIDs),
                      Set(deleted.map(\.actionID)).isDisjoint(with: actions),
                      Set(deleted.compactMap(\.performedSetID)) == Set(removal.batches.flatMap(\.removedSetIDs)),
                      removal.batches.allSatisfy({ $0.batch.exerciseID == exercise }) else { throw TrainingError.invalidWorkspace }
                var restoredJournal = journal
                _ = try restoredJournal.restoreSets(removal)
                try validateRestoredRows(deleted, on: day, exerciseID: exercise, at: index, journal: restoredJournal, exercises: exercises)
            }
        }
        return self
    }

    private func validateRestoredRows(_ deleted: [TrainingRow], on day: TrainingDay, exerciseID: String, at index: Int,
                                      journal: Journal, exercises: [Exercise], superset: SupersetSetUndo? = nil) throws {
        var restored = self
        restored.undo = nil
        var workout = restored.days[day.rawValue]!
        var converted = deleted
        let currentUnit = workout.unit
        if !converted.indices.allSatisfy({ converted[$0].changeUnit(to: currentUnit) }) {
            let originalUnit = deleted[0].unit
            for key in workout.rows.keys {
                for position in workout.rows[key]!.indices {
                    guard workout.rows[key]![position].changeUnit(to: originalUnit) else { throw TrainingError.invalidWorkspace }
                }
            }
            workout.unit = originalUnit; converted = deleted
        }
        workout.rows[exerciseID]!.insert(contentsOf: converted, at: index)
        if let superset {
            // Undo is available with the editor closed. Its generated replacement may currently have focus.
            restored.focus = nil
            try superset.restore(in: &workout, exerciseID: exerciseID, rowID: deleted[0].id)
        }
        restored.days[day.rawValue] = workout
        _ = try restored.validated(against: journal, exercises: exercises)
    }
}
