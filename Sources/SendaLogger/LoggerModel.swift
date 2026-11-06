import Foundation
import Observation
import SendaDomain
import SendaPersistence

public enum LoggerPhase: Equatable, Sendable {
    case draft(DraftBatch)
    case recorded(UUID)
}

public struct SetEditSession: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let source: LoggerPhase
    public let revision: Int?
    public var sets: [SetValues]
}

@Observable @MainActor
public final class LoggerModel {
    public private(set) var journal: Journal
    public private(set) var selectedExerciseID = "bench"
    public private(set) var selectedField = NumericField.weight
    public private(set) var numberInputText = "135"
    private var numberInputDirty = false
    public private(set) var editor: SetEditSession?
    public var errorMessage: String?
    public let isSample: Bool
    @ObservationIgnored private let repository: any JournalRepository
    @ObservationIgnored private let now: () -> Date
    private var sessions: [String: LoggerPhase] = [:]

    public init(repository: any JournalRepository, isSample: Bool = false, now: @escaping () -> Date = Date.init) throws {
        self.repository = repository
        self.journal = try repository.load()
        self.isSample = isSample
        self.now = now
        sessions["bench"] = .draft(makeDraft(for: exercise))
        resetNumberInput()
    }

    public var exercise: Exercise { Exercise.catalog.first { $0.id == selectedExerciseID }! }
    public var phase: LoggerPhase { sessions[selectedExerciseID]! }
    public var draft: DraftBatch? { if case .draft(let draft) = phase { draft } else { nil } }
    public var recorded: RecordedBatch? {
        if case .recorded(let id) = phase { journal.batches.first { $0.id == id } } else { nil }
    }
    public var values: [SetValues] { draft?.sets ?? recorded?.values ?? [] }
    public var priorReference: RecordedBatch? {
        if let recorded { return journal.comparison(for: recorded.id)?.previous }
        return journal.entries(for: selectedExerciseID).last
    }
    public var comparison: EntryComparison? { recorded.flatMap { journal.comparison(for: $0.id) } }
    public var today: Date { now() }
    public var recordSetCount: Int {
        if selectedField == .sets, numberInputDirty, let count = selectedField.parse(numberInputText) { return count }
        return values.count
    }
    public var numberInputIsValid: Bool { !numberInputDirty || selectedField.parse(numberInputText) != nil }
    public func selectField(_ field: NumericField) {
        guard field != selectedField, applyNumberInput() else { return }
        selectedField = field
        resetNumberInput()
    }

    /// Keyboard text is a buffer: intermediate digits must never resize the draft.
    public func typeNumber(_ text: String) {
        guard draft != nil, editor == nil else { return }
        numberInputText = text
        numberInputDirty = true
    }
    @discardableResult public func applyNumberInput() -> Bool {
        guard numberInputDirty else { return true }
        guard let value = selectedField.parse(numberInputText) else { return false }
        return setValue(value, for: selectedField)
    }
    public func cancelNumberInput() { resetNumberInput() }

    @discardableResult public func stepNumber(increasing: Bool) -> Bool {
        guard draft != nil, editor == nil else { return false }
        let current: Int
        if numberInputDirty {
            guard let parsed = selectedField.parse(numberInputText) else { return false }
            current = parsed
        } else {
            current = switch selectedField {
        case .weight: values.first?.weight ?? 0
        case .reps: values.first?.reps ?? 10
        case .sets: values.count
            }
        }
        // Resolve buffered input and the step as one intent, then resize exactly once.
        let proposed = current + (increasing ? selectedField.step : -selectedField.step)
        return setValue(min(selectedField.range.upperBound, max(selectedField.range.lowerBound, proposed)), for: selectedField)
    }

    private func resetNumberInput() {
        let value = switch selectedField {
        case .weight: values.first?.weight ?? 0
        case .reps: values.first?.reps ?? 10
        case .sets: values.count
        }
        numberInputText = selectedField.text(value)
        numberInputDirty = false
    }
    public var recentExercises: [Exercise] {
        Exercise.catalog.enumerated().sorted {
            let left = journal.entries(for: $0.element.id).last?.recordedAt ?? .distantPast
            let right = journal.entries(for: $1.element.id).last?.recordedAt ?? .distantPast
            return left == right ? $0.offset < $1.offset : left > right
        }.map(\.element)
    }
    public func selectExercise(_ id: String) {
        guard let exercise = Exercise.catalog.first(where: { $0.id == id }), applyNumberInput() else { return }
        editor = nil
        errorMessage = nil
        if sessions[id] == nil { sessions[id] = .draft(makeDraft(for: exercise)) }
        selectedExerciseID = id
        resetNumberInput()
    }

    @discardableResult public func setValue(_ value: Int, for field: NumericField) -> Bool {
        guard editor == nil, var draft, field.range.contains(value), let first = draft.sets.first else { return false }
        switch field {
        case .weight: draft.sets = draft.sets.map { SetValues(weight: value, reps: $0.reps) }
        case .reps: draft.sets = draft.sets.map { SetValues(weight: $0.weight, reps: value) }
        case .sets:
            if value <= draft.sets.count { draft.sets = Array(draft.sets.prefix(value)) }
            else { draft.sets += Array(repeating: first, count: value - draft.sets.count) }
        }
        sessions[selectedExerciseID] = .draft(draft)
        resetNumberInput()
        errorMessage = nil
        return true
    }

    @discardableResult public func record() -> Bool {
        guard editor == nil, applyNumberInput(), let draft else { return false }
        return perform {
            var candidate = journal
            let batch = try candidate.record(draft, at: now())
            try repository.save(candidate)
            journal = candidate
            sessions[selectedExerciseID] = .recorded(batch.id)
            resetNumberInput()
        }
    }

    @discardableResult public func undo() -> Bool {
        guard editor == nil, let recorded else { return false }
        return perform {
            var candidate = journal
            let draft = try candidate.undo(batchID: recorded.id, revision: recorded.revision)
            try repository.save(candidate)
            journal = candidate
            sessions[selectedExerciseID] = .draft(draft)
            resetNumberInput()
        }
    }

    public func anotherBatch() {
        guard editor == nil, let recorded else { return }
        sessions[selectedExerciseID] = .draft(DraftBatch(exerciseID: selectedExerciseID, sets: recorded.values))
        resetNumberInput()
        errorMessage = nil
    }

    public func beginEditingSets() {
        guard editor == nil, applyNumberInput() else { return }
        editor = SetEditSession(id: UUID(), source: phase, revision: recorded?.revision, sets: values)
        errorMessage = nil
    }
    public func cancelSetEdits() { editor = nil }
    @discardableResult public func updateEditedSet(at index: Int, values: SetValues) -> Bool {
        guard var editor, editor.sets.indices.contains(index),
              (try? SetValidation.validate([values])) != nil else { return false }
        editor.sets[index] = values
        self.editor = editor
        return true
    }

    @discardableResult public func confirmSetEdits() -> Bool {
        guard let editor else { return false }
        return perform {
            guard editor.source == phase else { throw JournalError.staleRevision }
            try SetValidation.validate(editor.sets)
            switch editor.source {
            case .draft(var draft):
                draft.sets = editor.sets
                sessions[selectedExerciseID] = .draft(draft)
            case .recorded(let id):
                guard let revision = editor.revision else { throw JournalError.staleRevision }
                var candidate = journal
                _ = try candidate.correct(batchID: id, revision: revision, sets: editor.sets)
                try repository.save(candidate)
                journal = candidate
            }
            self.editor = nil
            resetNumberInput()
        }
    }

    private func makeDraft(for exercise: Exercise) -> DraftBatch {
        let suggestions = journal.entries(for: exercise.id).last?.values
            ?? Array(repeating: SetValues(weight: exercise.startingWeight, reps: 10), count: 4)
        return DraftBatch(exerciseID: exercise.id, sets: suggestions)
    }

    private func perform(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
