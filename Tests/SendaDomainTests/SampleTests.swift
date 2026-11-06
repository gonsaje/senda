import Testing
import Foundation
@testable import SendaDomain

struct SampleTests {
    @Test func sampleContainsOnlyPriorPerformedEntries() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sample = try SampleJournal.make(relativeTo: now)
        #expect(sample.batches.count == 3)
        #expect(sample.batches.allSatisfy { $0.recordedAt < now })
        #expect(sample.entries(for: "bench").last?.values.map(\.reps) == [10, 10, 10, 10])
        #expect(try sample.validated() == sample)
    }
}
