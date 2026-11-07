import Foundation
import SendaDomain

/// A performed-history change and its matching recovery state are one transaction.
@MainActor public protocol JournalRepository {
    func loadSnapshot() throws -> JournalSnapshot
    func saveSnapshot(_ snapshot: JournalSnapshot) throws
}

public extension JournalRepository {
    func load() throws -> Journal { try loadSnapshot().journal }
    /// Legacy journal-only callers preserve recovery, and fail if their change makes it inconsistent.
    func save(_ journal: Journal) throws {
        let previous = try loadSnapshot()
        try saveSnapshot(JournalSnapshot(journal: journal, workspace: previous.workspace, customExercises: previous.customExercises))
    }
}

@MainActor public final class MemoryJournalRepository: JournalRepository {
    private var snapshot: JournalSnapshot
    public init(journal: Journal = Journal(), workspace: EntryWorkspace? = nil) {
        snapshot = JournalSnapshot(journal: journal, workspace: workspace)
    }
    public func loadSnapshot() throws -> JournalSnapshot { try snapshot.validated() }
    public func saveSnapshot(_ snapshot: JournalSnapshot) throws { self.snapshot = try snapshot.validated() }
}
