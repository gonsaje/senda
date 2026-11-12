import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger
@MainActor struct ProfileModelTests {
    @Test func savedDetailsReopenAndFailedSaveKeepsLastValues() throws {
        let store = ProfileFailureStore()
        let profile = ProfileModel(repository: store)
        #expect(profile.save(name: " Jae ", email: "jae@example.com"))
        store.rejectWrites = true
        #expect(!profile.save(name: "Different", email: "other@example.com"))
        #expect(profile.details.name == "Jae" && profile.errorMessage != nil)
        #expect(ProfileModel(repository: store).details.name == "Jae")
        store.rejectWrites = false
        #expect(profile.save(name: "Different", email: "other@example.com"))
        #expect(ProfileModel(repository: store).details.name == "Different")
    }
    @Test func unreadableProfileCannotBeOverwrittenAndDoesNotBlockLogging() throws {
        let store = ProfileFailureStore(); store.rejectReads = true
        let notebook = try TrainingNotebookModel(repository: MemoryJournalRepository(), profileRepository: store)
        #expect(notebook.profile.openingError != nil)
        #expect(!notebook.profile.save(name: "Replace", email: ""))
        #expect(store.saveCount == 0)
        #expect(notebook.openDay(notebook.today)); #expect(notebook.addExercise("bench"))
        store.rejectReads = false
        notebook.profile.reload()
        #expect(notebook.profile.openingError == nil)
        #expect(notebook.profile.save(name: "Jae", email: ""))
    }
    @Test func goalUpdatesPreserveIdentityAndFailedRemovalKeepsSavedGoal() {
        let store = ProfileFailureStore()
        let profile = ProfileModel(repository: store)
        let goal = StrengthGoal(exerciseID: "bench", target: SetValues(weight: 15_500, reps: 8))
        #expect(profile.saveGoal(goal))
        let edited = StrengthGoal(id: goal.id, exerciseID: goal.exerciseID, target: SetValues(weight: 16_000, reps: 8))
        #expect(profile.saveGoal(edited))
        #expect(profile.saveName("Jae"))
        #expect(profile.details.goals == [edited])
        store.rejectWrites = true
        #expect(!profile.removeGoal(goal.id))
        #expect(profile.errorMessage != nil)
        #expect(ProfileModel(repository: store).details == profile.details)
        store.rejectWrites = false
        #expect(profile.removeGoal(goal.id))
        #expect(profile.details.goals.isEmpty && profile.details.name == "Jae")
    }
    @Test func invalidDetailsNeverReachPersistence() {
        let store = ProfileFailureStore()
        let profile = ProfileModel(repository: store)
        #expect(!profile.save(name: "Jae", email: "invalid"))
        #expect(store.saveCount == 0 && profile.details == ProfileDetails())
    }
}
@MainActor private final class ProfileFailureStore: ProfileRepository {
    var details = ProfileDetails()
    var rejectReads = false, rejectWrites = false, saveCount = 0
    func load() throws -> ProfileDetails {
        if rejectReads { throw CocoaError(.fileReadCorruptFile) }
        return details
    }
    func save(_ next: ProfileDetails) throws {
        if rejectWrites { throw CocoaError(.fileWriteUnknown) }
        details = try next.validated(); saveCount += 1
    }
}
