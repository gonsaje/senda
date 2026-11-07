import Foundation
import Observation
import SendaDomain
import SendaPersistence

@Observable @MainActor
public final class LoggerModel {
    public private(set) var journal: Journal
    public private(set) var selectedExerciseID = "bench"
    public private(set) var selectedField = NumericField.weight
    public private(set) var selectedSetIndex: Int?
    public private(set) var selectedWeightUnit = WeightUnit.pounds
    public private(set) var numberInputText = "135"
    public private(set) var editor: SetEditSession?
    public var errorMessage: String?
    public private(set) var recoveryErrorMessage: String?
    public let isSample: Bool
    private var numberInputDirty = false
    private var sessions: [String: LoggerPhase] = [:]
    @ObservationIgnored private let repository: any JournalRepository
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var lastPersisted: JournalSnapshot?

    public init(repository: any JournalRepository, isSample: Bool = false, now: @escaping () -> Date = Date.init) throws {
        self.repository = repository; self.isSample = isSample; self.now = now
        let saved = try repository.loadSnapshot().validated()
        journal = saved.journal
        lastPersisted = saved
        if let workspace = saved.workspace { restore(workspace) }
        else {
            sessions["bench"] = .draft(makeDraft(for: Exercise.catalog[0]))
            resetNumberInput()
        }
    }

    public var exercise: Exercise { Exercise.catalog.first { $0.id == selectedExerciseID }! }
    public var phase: LoggerPhase { sessions[selectedExerciseID]! }
    public var draft: DraftBatch? { if case .draft(let entry) = phase { entry } else { nil } }
    public var isEditingRecorded: Bool { if case .editing = phase { true } else { false } }
    public var showsNumericDock: Bool { draft != nil || isEditingRecorded }
    public var recorded: RecordedBatch? {
        let id: UUID
        switch phase {
        case .draft: return nil
        case .recorded(let value): id = value
        case .editing(let edit): id = edit.batchID
        }
        return journal.batches.first { $0.id == id }
    }
    public var values: [SetValues] {
        switch phase {
        case .draft(let entry): entry.sets
        case .editing(let edit): edit.sets
        case .recorded: recorded?.values ?? []
        }
    }
    public var priorReference: RecordedBatch? {
        if let recorded { return journal.comparison(for: recorded.id)?.previous }
        return journal.entries(for: selectedExerciseID).last
    }
    public var comparison: EntryComparison? {
        guard case .recorded(let id) = phase else { return nil }
        return journal.comparison(for: id)
    }
    public var today: Date { now() }
    public var recordSetCount: Int {
        if selectedField == .sets, numberInputDirty, let count = selectedField.parse(numberInputText) { return count }
        return values.count
    }
    public var numberInputIsValid: Bool { !numberInputDirty || parseInput(numberInputText, field: selectedField) != nil }
    public var canConfirmSetEdits: Bool { editor?.isValid == true }
    public var recentExercises: [Exercise] {
        Exercise.catalog.enumerated().sorted {
            let left = journal.entries(for: $0.element.id).last?.recordedAt ?? .distantPast
            let right = journal.entries(for: $1.element.id).last?.recordedAt ?? .distantPast
            return left == right ? $0.offset < $1.offset : left > right
        }.map(\.element)
    }

    public func selectField(_ field: NumericField) {
        guard editor == nil else { return }
        if case .recorded(let id) = phase, let original = recorded {
            sessions[selectedExerciseID] = .editing(RecordedEdit(batchID: id, revision: original.revision, sets: original.values, setIDs: original.sets.map { Optional($0.id) }))
        } else if !applyInput() { return }
        selectedSetIndex = nil
        selectedField = field
        resetNumberInput()
        _ = flushRecovery()
    }
    public func typeNumber(_ text: String) {
        guard showsNumericDock, editor == nil else { return }
        numberInputText = String(text.prefix(64)); numberInputDirty = true
        _ = flushRecovery()
    }
    @discardableResult public func applyNumberInput() -> Bool {
        guard applyInput() else { return false }
        _ = flushRecovery()
        return true
    }
    public func cancelNumberInput() { resetNumberInput(); _ = flushRecovery() }
    @discardableResult public func setValue(_ value: Int, for field: NumericField) -> Bool {
        guard applyValue(value, for: field) else { return false }
        _ = flushRecovery()
        return true
    }
    @discardableResult public func stepNumber(increasing: Bool) -> Bool {
        guard showsNumericDock, editor == nil else { return false }
        let current: Int
        if numberInputDirty {
            guard let parsed = parseInput(numberInputText, field: selectedField) else { return false }
            current = parsed
        } else { current = numericValue(selectedField, values: values, index: selectedSetIndex) }
        if selectedField == .weight { return setValue(selectedWeightUnit.stepped(current, increasing: increasing), for: .weight) }
        let proposed = current + (increasing ? selectedField.step : -selectedField.step)
        return setValue(min(selectedField.range.upperBound, max(selectedField.range.lowerBound, proposed)), for: selectedField)
    }
    public func selectExercise(_ id: String) {
        guard editor == nil, let exercise = Exercise.catalog.first(where: { $0.id == id }), applyInput() else { return }
        if sessions[id] == nil { sessions[id] = .draft(makeDraft(for: exercise)) }
        selectedExerciseID = id
        selectedSetIndex = nil
        resetNumberInput(); errorMessage = nil
        _ = flushRecovery()
    }

    @discardableResult public func record() -> Bool {
        guard editor == nil, draft != nil, applyInput(), let entry = draft else { return false }
        do {
            var candidate = journal
            let batch = try candidate.record(entry, at: now())
            var workspace = currentWorkspace()
            workspace.sessions[selectedExerciseID] = .recorded(batch.id)
            resetInput(in: &workspace, values: batch.values)
            return commit(JournalSnapshot(journal: candidate, workspace: workspace))
        } catch { errorMessage = error.localizedDescription; return false }
    }
    @discardableResult public func finishEditing() -> Bool {
        guard editor == nil, isEditingRecorded, applyInput(), case .editing(let edit) = phase else { return false }
        do {
            let original = try existingBatch(edit.batchID, revision: edit.revision)
            var candidate = journal
            if hasChanges(edit.sets, retainedIDs: edit.setIDs, from: original) {
                _ = try candidate.correct(batchID: original.id, revision: edit.revision, sets: edit.sets, retainedSetIDs: edit.setIDs)
            }
            var workspace = currentWorkspace()
            workspace.sessions[selectedExerciseID] = .recorded(original.id)
            resetInput(in: &workspace, values: edit.sets)
            return commit(JournalSnapshot(journal: candidate, workspace: workspace))
        } catch { errorMessage = error.localizedDescription; return false }
    }
    public func cancelEditing() {
        guard case .editing(let edit) = phase else { return }
        sessions[selectedExerciseID] = .recorded(edit.batchID)
        if let index = selectedSetIndex, index >= values.count { selectedSetIndex = values.count - 1 }
        editor = nil; resetNumberInput(); errorMessage = nil
        _ = flushRecovery()
    }
    @discardableResult public func undo() -> Bool {
        guard editor == nil, !isEditingRecorded, let original = recorded else { return false }
        do {
            var candidate = journal
            let entry = try candidate.undo(batchID: original.id, revision: original.revision)
            var workspace = currentWorkspace()
            workspace.sessions[selectedExerciseID] = .draft(entry)
            resetInput(in: &workspace, values: entry.sets)
            return commit(JournalSnapshot(journal: candidate, workspace: workspace))
        } catch { errorMessage = error.localizedDescription; return false }
    }
    public func anotherBatch() {
        guard editor == nil, !isEditingRecorded, let original = recorded else { return }
        sessions[selectedExerciseID] = .draft(DraftBatch(exerciseID: selectedExerciseID, sets: original.values))
        selectedSetIndex = nil
        resetNumberInput(); errorMessage = nil
        _ = flushRecovery()
    }

    public func beginEditingSets(batchID: UUID? = nil) {
        guard editor == nil else { return }
        if let id = batchID {
            guard let batch = journal.batches.first(where: { $0.id == id && $0.exerciseID == selectedExerciseID }) else { return }
            if case .editing(let edit) = phase, edit.batchID == id { return }
            // An older entry is independent of the current, possibly incomplete number buffer.
            editor = SetEditSession(source: .recorded(id), revision: batch.revision, sets: batch.values, unit: selectedWeightUnit)
        } else {
            guard applyInput() else { return }
            editor = SetEditSession(source: phase, revision: recorded?.revision, sets: values, unit: selectedWeightUnit)
        }
        errorMessage = nil
        _ = flushRecovery()
    }
    public func cancelSetEdits() { editor = nil; _ = flushRecovery() }
    @discardableResult public func updateEditedSet(at index: Int, values: SetValues) -> Bool {
        guard var edit = editor, edit.sets.indices.contains(index), (try? SetValidation.validate([values])) != nil else { return false }
        edit.sets[index] = values; edit.inputs[index] = SetInput(values: values, unit: editorWeightUnit)
        editor = edit; _ = flushRecovery()
        return true
    }
    public func typeEditedSet(at index: Int, field: NumericField, text: String) {
        guard var edit = editor, edit.sets.indices.contains(index), field != .sets else { return }
        if field == .weight { edit.inputs[index].weight = String(text.prefix(64)); edit.inputs[index].weightIsDirty = true }
        else { edit.inputs[index].reps = String(text.prefix(64)) }
        if let parsed = edit.inputs[index].parsed {
            let weight = edit.inputs[index].weightIsDirty == true ? parsed.weight : edit.sets[index].weight
            edit.sets[index] = SetValues(weight: weight, reps: parsed.reps)
        }
        editor = edit; _ = flushRecovery()
    }
    @discardableResult public func stepEditedSet(at index: Int, field: NumericField, increasing: Bool) -> Bool {
        guard let edit = editor, edit.inputs.indices.contains(index), field != .sets else { return false }
        let text = field == .weight ? edit.inputs[index].weight : edit.inputs[index].reps
        let unit = edit.inputs[index].unit ?? .pounds
        if field == .weight {
            guard let value = unit.parse(text) else { return false }
            let next = unit.stepped(value, increasing: increasing)
            typeEditedSet(at: index, field: field, text: unit.text(for: next))
        } else {
            guard let value = field.parse(text) else { return false }
            let next = min(field.range.upperBound, max(field.range.lowerBound, value + (increasing ? 1 : -1)))
            typeEditedSet(at: index, field: field, text: field.text(next))
        }
        return true
    }
    public func setEditorFocus(index: Int, field: NumericField?) {
        guard var edit = editor, edit.sets.indices.contains(index), field != .sets else { return }
        if let field { edit.focus = SetFieldFocus(index: index, field: field) }
        else if edit.focus?.index == index { edit.focus = nil }
        editor = edit; _ = flushRecovery()
    }
    @discardableResult public func confirmSetEdits() -> Bool {
        guard let edit = editor, edit.isValid else { return false }
        do {
            var candidate = journal
            var workspace = currentWorkspace()
            workspace.editor = nil
            switch edit.source {
            case .draft(var entry):
                guard phase == edit.source else { throw JournalError.staleRevision }
                entry.sets = edit.sets
                workspace.sessions[selectedExerciseID] = .draft(entry)
                resetInput(in: &workspace, values: entry.sets)
            case .editing(let correction):
                guard phase == edit.source else { throw JournalError.staleRevision }
                let original = try existingBatch(correction.batchID, revision: correction.revision)
                if hasChanges(edit.sets, retainedIDs: correction.setIDs, from: original) {
                    _ = try candidate.correct(batchID: original.id, revision: original.revision, sets: edit.sets, retainedSetIDs: correction.setIDs)
                }
                workspace.sessions[selectedExerciseID] = .recorded(original.id)
                resetInput(in: &workspace, values: edit.sets)
            case .recorded(let id):
                guard let revision = edit.revision else { throw JournalError.staleRevision }
                let original = try existingBatch(id, revision: revision)
                if original.values != edit.sets {
                    _ = try candidate.correct(batchID: id, revision: revision, sets: edit.sets)
                }
                if case .recorded(let visibleID) = phase, visibleID == id {
                    resetInput(in: &workspace, values: edit.sets)
                }
            }
            return commit(JournalSnapshot(journal: candidate, workspace: workspace))
        } catch { errorMessage = error.localizedDescription; return false }
    }

    @discardableResult public func flushRecovery() -> Bool {
        let snapshot = JournalSnapshot(journal: journal, workspace: currentWorkspace())
        if snapshot == lastPersisted { recoveryErrorMessage = nil; return true }
        do {
            try repository.saveSnapshot(snapshot)
            lastPersisted = snapshot; recoveryErrorMessage = nil
            return true
        } catch {
            recoveryErrorMessage = "Your changes are open here, but couldn’t be kept for reopening. \(error.localizedDescription)"
            return false
        }
    }

    public var showsNumberEditor: Bool {
        showsNumericDock && (selectedSetIndex != nil || numberInputDirty || selectedField == .sets || isEditingRecorded)
    }
    @discardableResult public func closeNumberEditor() -> Bool {
        if isEditingRecorded { return finishEditing() }
        guard editor == nil, applyInput() else { return false }
        selectedSetIndex = nil; selectedField = .weight
        resetNumberInput(); _ = flushRecovery(); return true
    }
    public var editorWeightUnit: WeightUnit { editor?.inputs.first?.unit ?? selectedWeightUnit }
    public var weightAmount: Double {
        let value = selectedField == .weight && numberInputDirty
            ? (selectedWeightUnit.parse(numberInputText) ?? numericValue(.weight, values: values, index: selectedSetIndex))
            : numericValue(.weight, values: values, index: selectedSetIndex)
        return NSDecimalNumber(decimal: selectedWeightUnit.amount(for: value)).doubleValue
    }
    public func selectSet(_ index: Int, field: NumericField, unit: WeightUnit? = nil) {
        guard editor == nil, values.indices.contains(index), field != .sets, applyInput() else { return }
        beginCorrectionIfNeeded()
        selectedSetIndex = index; selectedField = field
        if let unit { selectedWeightUnit = unit }
        resetNumberInput(); _ = flushRecovery()
    }
    @discardableResult public func selectWeightUnit(_ unit: WeightUnit) -> Bool {
        guard editor == nil else { return false }
        if selectedField == .weight && !applyInput() { return false }
        selectedWeightUnit = unit
        if selectedField == .weight { resetNumberInput() }
        _ = flushRecovery(); return true
    }
    @discardableResult public func selectEditorWeightUnit(_ unit: WeightUnit) -> Bool {
        guard var edit = editor, edit.isValid else { return false }
        edit.inputs = edit.sets.map { SetInput(values: $0, unit: unit) }
        editor = edit; _ = flushRecovery(); return true
    }
    @discardableResult public func setWeightAmount(_ amount: Double) -> Bool {
        guard amount.isFinite, amount >= 0, showsNumericDock, selectedField == .weight else { return false }
        let maximum = NSDecimalNumber(decimal: selectedWeightUnit.maximumAmount).doubleValue
        guard amount <= maximum else { return false }
        if amount == maximum { return setValue(NumericField.weight.range.upperBound, for: .weight) }
        let text = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), amount)
        guard let value = selectedWeightUnit.parse(text) else { return false }
        return setValue(value, for: .weight)
    }
    @discardableResult public func addSet() -> Bool {
        guard editor == nil, values.count < 30, applyInput(), let last = values.last else { return false }
        beginCorrectionIfNeeded()
        switch phase {
        case .draft(var entry): entry.sets.append(last); sessions[selectedExerciseID] = .draft(entry)
        case .editing(var edit):
            var retained = ids(for: edit); retained.append(nil)
            edit.sets.append(last); edit.setIDs = retained; sessions[selectedExerciseID] = .editing(edit)
        case .recorded: return false
        }
        selectedSetIndex = values.count - 1; selectedField = .weight
        resetNumberInput(); _ = flushRecovery(); return true
    }
    @discardableResult public func removeSet(at index: Int) -> Bool {
        guard editor == nil, values.count > 1, values.indices.contains(index), applyInput() else { return false }
        beginCorrectionIfNeeded()
        switch phase {
        case .draft(var entry): entry.sets.remove(at: index); sessions[selectedExerciseID] = .draft(entry)
        case .editing(var edit):
            var retained = ids(for: edit); retained.remove(at: index)
            edit.sets.remove(at: index); edit.setIDs = retained; sessions[selectedExerciseID] = .editing(edit)
        case .recorded: return false
        }
        if let selected = selectedSetIndex {
            selectedSetIndex = max(0, min(values.count - 1, selected - (index < selected ? 1 : 0)))
        }
        resetNumberInput(); _ = flushRecovery(); return true
    }
    private func beginCorrectionIfNeeded() {
        if case .recorded(let id) = phase, let original = recorded {
            sessions[selectedExerciseID] = .editing(RecordedEdit(batchID: id, revision: original.revision,
                sets: original.values, setIDs: original.sets.map { Optional($0.id) }))
        }
    }
    private func ids(for edit: RecordedEdit) -> [UUID?] {
        if let ids = edit.setIDs { return ids }
        let original = journal.batches.first { $0.id == edit.batchID }?.sets.map { Optional($0.id) } ?? []
        return Array(original.prefix(edit.sets.count)) + Array(repeating: nil, count: max(0, edit.sets.count - original.count))
    }
    private func hasChanges(_ values: [SetValues], retainedIDs: [UUID?]?, from original: RecordedBatch) -> Bool {
        original.values != values || (retainedIDs != nil && retainedIDs != original.sets.map { Optional($0.id) })
    }
    private func parseInput(_ text: String, field: NumericField) -> Int? {
        field == .weight ? selectedWeightUnit.parse(text) : field.parse(text)
    }

    private func applyInput() -> Bool {
        guard numberInputDirty else { return true }
        guard let value = parseInput(numberInputText, field: selectedField) else { return false }
        return applyValue(value, for: selectedField)
    }
    private func applyValue(_ value: Int, for field: NumericField) -> Bool {
        guard editor == nil, showsNumericDock, field.range.contains(value), let first = values.first else { return false }
        var changed = values
        switch field {
        case .weight:
            if let index = selectedSetIndex { changed[index].weight = value }
            else { changed = changed.map { SetValues(weight: value, reps: $0.reps) } }
        case .reps:
            if let index = selectedSetIndex { changed[index].reps = value }
            else { changed = changed.map { SetValues(weight: $0.weight, reps: value) } }
        case .sets:
            if value <= changed.count { changed = Array(changed.prefix(value)) }
            else { changed += Array(repeating: first, count: value - changed.count) }
        }
        switch phase {
        case .draft(var entry): entry.sets = changed; sessions[selectedExerciseID] = .draft(entry)
        case .editing(var edit):
            var ids = ids(for: edit)
            if ids.count > changed.count { ids = Array(ids.prefix(changed.count)) }
            else { ids += Array(repeating: nil, count: changed.count - ids.count) }
            edit.sets = changed; edit.setIDs = ids; sessions[selectedExerciseID] = .editing(edit)
        case .recorded: return false
        }
        if let index = selectedSetIndex, index >= changed.count { selectedSetIndex = changed.count - 1 }
        resetNumberInput(); errorMessage = nil
        return true
    }
    private func currentWorkspace() -> EntryWorkspace {
        EntryWorkspace(selectedExerciseID: selectedExerciseID, selectedField: selectedField, sessions: sessions,
                       numberInputText: numberInputText, numberInputDirty: numberInputDirty, editor: editor,
                       selectedSetIndex: selectedSetIndex, weightUnit: selectedWeightUnit)
    }
    private func restore(_ workspace: EntryWorkspace) {
        selectedExerciseID = workspace.selectedExerciseID; selectedField = workspace.selectedField
        sessions = workspace.sessions; numberInputText = workspace.numberInputText
        numberInputDirty = workspace.numberInputDirty; editor = workspace.editor
        selectedSetIndex = workspace.selectedSetIndex; selectedWeightUnit = workspace.weightUnit ?? .pounds
    }
    private func resetNumberInput() {
        let value = numericValue(selectedField, values: values, index: selectedSetIndex)
        numberInputText = selectedField == .weight ? selectedWeightUnit.text(for: value) : selectedField.text(value)
        numberInputDirty = false
    }
    private func resetInput(in workspace: inout EntryWorkspace, values: [SetValues]) {
        if let index = workspace.selectedSetIndex, index >= values.count { workspace.selectedSetIndex = values.count - 1 }
        let value = numericValue(workspace.selectedField, values: values, index: workspace.selectedSetIndex)
        workspace.numberInputText = workspace.selectedField == .weight
            ? (workspace.weightUnit ?? .pounds).text(for: value) : workspace.selectedField.text(value)
        workspace.numberInputDirty = false
    }
    private func numericValue(_ field: NumericField, values: [SetValues], index: Int?) -> Int {
        let row = values.indices.contains(index ?? 0) ? values[index ?? 0] : values.first
        return switch field { case .weight: row?.weight ?? 0; case .reps: row?.reps ?? 10; case .sets: values.count }
    }
    private func makeDraft(for exercise: Exercise) -> DraftBatch {
        let suggestions = journal.entries(for: exercise.id).last?.values
            ?? Array(repeating: SetValues(weight: exercise.startingWeight, reps: 10), count: 4)
        return DraftBatch(exerciseID: exercise.id, sets: suggestions)
    }
    private func existingBatch(_ id: UUID, revision: Int) throws -> RecordedBatch {
        guard let batch = journal.batches.first(where: { $0.id == id && $0.exerciseID == selectedExerciseID }) else {
            throw JournalError.missingBatch
        }
        guard batch.revision == revision else { throw JournalError.staleRevision }
        return batch
    }
    private func commit(_ snapshot: JournalSnapshot) -> Bool {
        do {
            try repository.saveSnapshot(snapshot)
            journal = snapshot.journal
            if let workspace = snapshot.workspace { restore(workspace) }
            lastPersisted = snapshot; errorMessage = nil; recoveryErrorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
}
