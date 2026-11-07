import Foundation

public struct RecordedEdit: Codable, Equatable, Sendable {
    public let batchID: UUID
    public let revision: Int
    public var sets: [SetValues]
    public var setIDs: [UUID?]?
    public init(batchID: UUID, revision: Int, sets: [SetValues], setIDs: [UUID?]? = nil) {
        self.batchID = batchID; self.revision = revision; self.sets = sets; self.setIDs = setIDs
    }
}

public enum LoggerPhase: Codable, Equatable, Sendable {
    case draft(DraftBatch)
    case recorded(UUID)
    case editing(RecordedEdit)
}

public struct SetInput: Codable, Equatable, Sendable {
    public var weight: String
    public var reps: String
    public var unit: WeightUnit?
    public var weightIsDirty: Bool?
    public init(values: SetValues, unit: WeightUnit = .pounds) {
        weight = unit.text(for: values.weight); reps = String(values.reps)
        self.unit = unit; weightIsDirty = false
    }
    public var parsed: SetValues? {
        guard let weight = (unit ?? .pounds).parse(weight), let reps = NumericField.reps.parse(reps) else { return nil }
        return SetValues(weight: weight, reps: reps)
    }
}

public struct SetFieldFocus: Codable, Equatable, Sendable {
    public let index: Int
    public let field: NumericField
    public init(index: Int, field: NumericField) { self.index = index; self.field = field }
}

public struct SetEditSession: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let source: LoggerPhase
    public let revision: Int?
    public var sets: [SetValues]
    public var inputs: [SetInput]
    public var focus: SetFieldFocus?
    public init(id: UUID = UUID(), source: LoggerPhase, revision: Int?, sets: [SetValues], unit: WeightUnit = .pounds) {
        self.id = id; self.source = source; self.revision = revision
        self.sets = sets; self.inputs = sets.map { SetInput(values: $0, unit: unit) }; self.focus = nil
    }
    public var isValid: Bool { inputs.count == sets.count && inputs.allSatisfy { $0.parsed != nil } }
}

public struct EntryWorkspace: Codable, Equatable, Sendable {
    public var selectedExerciseID: String
    public var selectedField: NumericField
    public var sessions: [String: LoggerPhase]
    public var numberInputText: String
    public var numberInputDirty: Bool
    public var editor: SetEditSession?
    public var selectedSetIndex: Int?
    public var weightUnit: WeightUnit?
    public var workoutExerciseIDs: [String]?
    public init(selectedExerciseID: String = "bench", selectedField: NumericField = .weight,
                sessions: [String: LoggerPhase], numberInputText: String = "135",
                numberInputDirty: Bool = false, editor: SetEditSession? = nil,
                selectedSetIndex: Int? = nil, weightUnit: WeightUnit? = nil, workoutExerciseIDs: [String]? = nil) {
        self.selectedExerciseID = selectedExerciseID; self.selectedField = selectedField
        self.sessions = sessions; self.numberInputText = numberInputText
        self.numberInputDirty = numberInputDirty; self.editor = editor
        self.selectedSetIndex = selectedSetIndex; self.weightUnit = weightUnit
        self.workoutExerciseIDs = workoutExerciseIDs
    }
    public func validated(against journal: Journal, exercises: [Exercise] = Exercise.catalog) throws -> EntryWorkspace {
        let known = Set(exercises.map(\.id))
        let order = workoutExerciseIDs ?? ExerciseLibrary.initialWorkoutIDs
        guard known.contains(selectedExerciseID), sessions[selectedExerciseID] != nil,
              !sessions.isEmpty, sessions.count <= known.count, numberInputText.count <= 64,
              !order.isEmpty, Set(order).count == order.count, order.allSatisfy(known.contains),
              order.contains(selectedExerciseID) else {
            throw RecoveryError.invalidWorkspace
        }
        var actions = Set<UUID>()
        for (exerciseID, phase) in sessions {
            guard known.contains(exerciseID) else { throw RecoveryError.invalidWorkspace }
            switch phase {
            case .draft(let entry):
                try SetValidation.validate(entry.sets)
                guard entry.exerciseID == exerciseID, actions.insert(entry.actionID).inserted,
                      !journal.hasConsumedAction(entry.actionID) else { throw RecoveryError.invalidWorkspace }
            case .recorded(let id):
                _ = try batch(id, exerciseID: exerciseID, journal: journal)
            case .editing(let edit):
                let original = try batch(edit.batchID, exerciseID: exerciseID, journal: journal)
                try SetValidation.validate(edit.sets)
                guard original.revision == edit.revision else { throw RecoveryError.invalidWorkspace }
                if let ids = edit.setIDs {
                    let retained = ids.compactMap { $0 }
                    guard ids.count == edit.sets.count, Set(retained).count == retained.count,
                          Set(retained).isSubset(of: Set(original.sets.map(\.id))) else { throw RecoveryError.invalidWorkspace }
                }
            }
        }
        let values = try values(of: sessions[selectedExerciseID]!, journal: journal)
        let index = selectedSetIndex ?? 0
        guard values.indices.contains(index), !(selectedField == .sets && selectedSetIndex != nil) else {
            throw RecoveryError.invalidWorkspace
        }
        if !numberInputDirty {
            let value = switch selectedField {
            case .weight: values[index].weight
            case .reps: values[index].reps
            case .sets: values.count
            }
            let text = selectedField == .weight ? (weightUnit ?? .pounds).text(for: value) : selectedField.text(value)
            guard numberInputText == text else { throw RecoveryError.invalidWorkspace }
        } else if case .recorded = sessions[selectedExerciseID]! {
            throw RecoveryError.invalidWorkspace
        }
        if let editor {
            try SetValidation.validate(editor.sets)
            guard editor.inputs.count == editor.sets.count,
                  editor.inputs.allSatisfy({ $0.weight.count <= 64 && $0.reps.count <= 64 }) else {
                throw RecoveryError.invalidWorkspace
            }
            for (index, input) in editor.inputs.enumerated() {
                if let parsed = input.parsed {
                    guard parsed.reps == editor.sets[index].reps,
                          input.weightIsDirty != true || parsed.weight == editor.sets[index].weight else {
                        throw RecoveryError.invalidWorkspace
                    }
                }
            }
            if let focus = editor.focus {
                guard editor.sets.indices.contains(focus.index), focus.field != .sets else { throw RecoveryError.invalidWorkspace }
            }
            switch editor.source {
            case .draft:
                guard editor.source == sessions[selectedExerciseID], editor.revision == nil else {
                    throw RecoveryError.invalidWorkspace
                }
            case .recorded(let id):
                let original = try batch(id, exerciseID: selectedExerciseID, journal: journal)
                guard original.revision == editor.revision else { throw RecoveryError.invalidWorkspace }
                if case .editing(let edit) = sessions[selectedExerciseID], edit.batchID == id {
                    throw RecoveryError.invalidWorkspace
                }
            case .editing(let edit):
                guard editor.source == sessions[selectedExerciseID], editor.revision == edit.revision else {
                    throw RecoveryError.invalidWorkspace
                }
            }
        }
        return self
    }

    private func batch(_ id: UUID, exerciseID: String, journal: Journal) throws -> RecordedBatch {
        guard let result = journal.batches.first(where: { $0.id == id }), result.exerciseID == exerciseID else {
            throw RecoveryError.invalidWorkspace
        }
        return result
    }
    private func values(of phase: LoggerPhase, journal: Journal) throws -> [SetValues] {
        switch phase {
        case .draft(let entry): return entry.sets
        case .recorded(let id): return try batch(id, exerciseID: selectedExerciseID, journal: journal).values
        case .editing(let edit): return edit.sets
        }
    }
}

public struct JournalSnapshot: Codable, Equatable, Sendable {
    public var journal: Journal
    public var workspace: EntryWorkspace?
    public var customExercises: [Exercise]?
    public init(journal: Journal = Journal(), workspace: EntryWorkspace? = nil, customExercises: [Exercise]? = nil) {
        self.journal = journal; self.workspace = workspace
        self.customExercises = customExercises?.isEmpty == false ? customExercises : nil
    }
    public func validated() throws -> JournalSnapshot {
        _ = try journal.validated()
        let exercises = try ExerciseLibrary.validated(custom: customExercises ?? [])
        _ = try workspace?.validated(against: journal, exercises: exercises)
        var result = self
        if result.customExercises?.isEmpty == true { result.customExercises = nil }
        return result
    }
}

public enum RecoveryError: LocalizedError, Equatable {
    case invalidWorkspace
    public var errorDescription: String? {
        "The saved entry could not be restored. The journal file has been left untouched."
    }
}
