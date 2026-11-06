import Testing
import Foundation
import SendaDomain
@testable import SendaPersistence

@MainActor
struct FileJournalTests {
    private func location() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("senda-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("journal.json")
    }

    private func draft() -> DraftBatch {
        DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10), SetValues(weight: 13_500, reps: 8)])
    }

    @Test func testRoundTripRetainsOrderedSetsCorrectionsAndConsumedUndoReceipt() throws {
        let url = try location()
        let store = FileJournalRepository(url: url)
        var journal = try store.load()
        let request = draft()
        let batch = try journal.record(request, at: Date())
        _ = try journal.correct(batchID: batch.id, revision: 1, sets: [SetValues(weight: 13_750, reps: 7)])
        try store.save(journal)
        #expect(try FileJournalRepository(url: url).load() == journal)
        _ = try journal.undo(batchID: batch.id, revision: 2)
        try store.save(journal)
        var reopened = try FileJournalRepository(url: url).load()
        #expect(reopened.batches.isEmpty)
        #expect(throws: (any Error).self) { try reopened.record(request, at: Date()) }
    }

    @Test func testCorruptOrFutureFileIsNotTreatedAsAnEmptyJournal() throws {
        let url = try location()
        for data in [Data("broken".utf8), Data("{\"version\":999,\"journal\":{}}".utf8)] {
            try data.write(to: url)
            #expect(throws: (any Error).self) { try FileJournalRepository(url: url).load() }
            #expect(try Data(contentsOf: url) == data)
        }
    }

    @Test func testWriteFailureLeavesPreviouslySavedBytesUnchanged() throws {
        let url = try location()
        let store = FileJournalRepository(url: url)
        var journal = Journal()
        _ = try journal.record(draft(), at: Date())
        try store.save(journal)
        let original = try Data(contentsOf: url)
        _ = try journal.record(draft(), at: Date())
        let failingStore = FileJournalRepository(url: url, writer: { _, _ in
            throw CocoaError(.fileWriteOutOfSpace)
        })
        #expect(throws: (any Error).self) { try failingStore.save(journal) }
        #expect(try Data(contentsOf: url) == original)
        #expect(try store.load().batches.count == 1)
    }

    @Test func testMissingFileStartsEmptyAndSaveCreatesParentDirectory() throws {
        let url = try location().deletingLastPathComponent().appendingPathComponent("nested/journal.json")
        let store = FileJournalRepository(url: url)
        #expect(try store.load() == Journal())
        try store.save(Journal())
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func futureVersionIsReportedBeforeTryingToDecodeItsUnknownSchema() throws {
        let url = try location()
        let bytes = Data("{\"version\":999,\"futureJournal\":[]}".utf8)
        try bytes.write(to: url)
        #expect(throws: StorageError.unsupportedVersion(999)) {
            try FileJournalRepository(url: url).load()
        }
        #expect(try Data(contentsOf: url) == bytes)
    }
}
