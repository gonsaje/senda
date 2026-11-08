import Foundation
import Observation
import SendaDomain
import SendaPersistence

/// Resolves old explicit group edits before introducing per-row automatic logging.
@Observable @MainActor public final class LegacyRecoveryModel {
    public private(set) var logger: LoggerModel?
    public private(set) var isComplete = false
    public private(set) var errorMessage: String?
    @ObservationIgnored private let repository: any JournalRepository
    @ObservationIgnored private var memory: MemoryJournalRepository?
    @ObservationIgnored private var base: EntryWorkspace

    public init(repository: any JournalRepository) throws {
        self.repository = repository
        let source = try repository.loadSnapshot().validated()
        guard let workspace = source.workspace else { throw TrainingError.legacyReview }
        base = source.legacyBase ?? workspace
        try prepare(source)
    }
    public var reviewsSetCount: Bool {
        logger?.editor == nil && logger?.selectedField == .sets
    }
    @discardableResult public func accept() -> Bool {
        if isComplete { return true }
        do {
            guard let memory else { return false }
            var candidate = try memory.loadSnapshot()
            guard var workspace = candidate.workspace, workspace.editor == nil else { return false }
            workspace.selectedExerciseID = base.selectedExerciseID
            workspace.workoutExerciseIDs = base.workoutExerciseIDs
            workspace.weightUnit = base.weightUnit
            workspace.selectedField = base.selectedField
            workspace.selectedSetIndex = base.selectedSetIndex
            let phase = workspace.sessions[base.selectedExerciseID]!
            let values: [SetValues]
            switch phase {
            case .draft(let entry): values = entry.sets
            case .editing(let edit): values = edit.sets
            case .recorded(let id): values = candidate.journal.batches.first { $0.id == id }!.values
            }
            if base.numberInputDirty && base.selectedField != .sets,
               { if case .recorded = phase { false } else { true } }() {
                workspace.numberInputDirty = true; workspace.numberInputText = base.numberInputText
            } else {
                if case .recorded = phase { workspace.selectedSetIndex = nil; workspace.selectedField = .weight }
                if let index = workspace.selectedSetIndex, !values.indices.contains(index) { workspace.selectedSetIndex = nil }
                let selected = values[workspace.selectedSetIndex ?? 0]
                workspace.numberInputDirty = false
                switch workspace.selectedField {
                case .weight: workspace.numberInputText = (workspace.weightUnit ?? .pounds).text(for: selected.weight)
                case .reps: workspace.numberInputText = String(selected.reps)
                case .sets: workspace.numberInputText = String(values.count)
                }
            }
            candidate.workspace = workspace; candidate.legacyBase = nil
            try repository.saveSnapshot(candidate)
            base = workspace; errorMessage = nil
            try prepare(candidate)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    @discardableResult public func flushRecovery() -> Bool {
        if isComplete { return true }
        do {
            guard let memory else { return false }
            var candidate = try memory.loadSnapshot()
            let persisted = try repository.loadSnapshot()
            if !TrainingWorkspace.requiresLegacyReview(candidate) || candidate.journal != persisted.journal { return accept() }
            candidate.legacyBase = base
            try repository.saveSnapshot(candidate)
            errorMessage = nil; return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    @discardableResult public func discard() -> Bool {
        guard let logger else { return false }
        if logger.editor != nil { logger.cancelSetEdits() }
        else if logger.isEditingRecorded { logger.cancelEditing() }
        else { logger.cancelNumberInput(); _ = logger.closeNumberEditor() }
        return accept()
    }
    private func prepare(_ source: JournalSnapshot) throws {
        guard TrainingWorkspace.requiresLegacyReview(source), var workspace = source.workspace else {
            isComplete = true; logger = nil; return
        }
        if workspace.editor == nil && !(workspace.numberInputDirty && workspace.selectedField == .sets) {
            let pending = { () -> String? in
                if case .editing = workspace.sessions[workspace.selectedExerciseID]! { return workspace.selectedExerciseID }
                return workspace.sessions.keys.sorted().first { if case .editing = workspace.sessions[$0]! { true } else { false } }
            }()
            guard let pending else {
                memory = try MemoryJournalRepository(snapshot: source)
                logger = try LoggerModel(repository: memory!)
                _ = accept(); return
            }
            if pending != workspace.selectedExerciseID {
                workspace.selectedExerciseID = pending; workspace.selectedField = .weight; workspace.selectedSetIndex = nil
                if case .editing(let edit) = workspace.sessions[pending]! {
                    workspace.numberInputText = (workspace.weightUnit ?? .pounds).text(for: edit.sets[0].weight)
                    workspace.numberInputDirty = false
                }
            }
            var order = workspace.workoutExerciseIDs ?? ExerciseLibrary.initialWorkoutIDs
            if !order.contains(pending) { order.append(pending) }
            workspace.workoutExerciseIDs = order
        }
        var candidate = source; candidate.workspace = workspace
        let memory = try MemoryJournalRepository(snapshot: candidate)
        self.memory = memory; logger = try LoggerModel(repository: memory)
    }
}
