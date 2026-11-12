import Foundation
import Testing
import SendaDomain
@testable import SendaPersistence
@MainActor struct ProfileStorageTests {
    @Test func missingFileStartsEmptyAndDetailsRoundtripIndependently() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let profile = FileProfileRepository(url: directory.appendingPathComponent("profile.json"))
        let journal = FileJournalRepository(url: directory.appendingPathComponent("journal.json"))
        try journal.saveSnapshot(JournalSnapshot())
        let before = try Data(contentsOf: directory.appendingPathComponent("journal.json"))
        #expect(try profile.load() == ProfileDetails())
        try profile.save(ProfileDetails(name: "Jae", email: "jae@example.com"))
        #expect(try profile.load() == ProfileDetails(name: "Jae", email: "jae@example.com"))
        #expect(try Data(contentsOf: directory.appendingPathComponent("journal.json")) == before)
    }
    @Test func versionOneProfileWithoutGoalsLoadsAndCanSaveGoals() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("profile-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let legacy = Data(#"{"version":1,"details":{"name":"Jae","email":""}}"#.utf8)
        try legacy.write(to: url)
        let store = FileProfileRepository(url: url)
        var details = try store.load()
        #expect(details.name == "Jae" && details.goals.isEmpty)
        details.goals = [StrengthGoal(exerciseID: "bench", target: SetValues(weight: 15_500, reps: 8))]
        try store.save(details)
        #expect(try FileProfileRepository(url: url).load() == details)
        let withGoals = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(withGoals?["version"] as? Int == 2)

        details.goals = []
        try store.save(details)
        let withoutGoals = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(withoutGoals?["version"] as? Int == 1)
        #expect(try FileProfileRepository(url: url).load() == details)
    }
    @Test func failedWriteKeepsLastProfileBytes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("profile-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileProfileRepository(url: url)
        try store.save(ProfileDetails(name: "Before"))
        let bytes = try Data(contentsOf: url)
        let failing = FileProfileRepository(url: url) { _, _ in throw CocoaError(.fileWriteUnknown) }
        #expect(throws: (any Error).self) { try failing.save(ProfileDetails(name: "After")) }
        #expect(try Data(contentsOf: url) == bytes)
    }
    @Test func corruptAndFutureFilesAreLeftUntouched() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("profile-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        for text in ["broken json", "{\"version\":999,\"details\":{\"name\":\"Jae\",\"email\":\"\"}}"] {
            let bytes = Data(text.utf8); try bytes.write(to: url)
            #expect(throws: (any Error).self) { try FileProfileRepository(url: url).load() }
            #expect(try Data(contentsOf: url) == bytes)
        }
    }
}
