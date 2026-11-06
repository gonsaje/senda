import Foundation
import SendaDomain

/// One main-actor owner serializes local mutations. Implementations must save all or throw.
@MainActor public protocol JournalRepository {
    func load() throws -> Journal
    func save(_ journal: Journal) throws
}

@MainActor public final class MemoryJournalRepository: JournalRepository {
    private var journal: Journal
    public init(journal: Journal = Journal()) { self.journal = journal }
    public func load() throws -> Journal { journal }
    public func save(_ journal: Journal) throws { self.journal = journal }
}
