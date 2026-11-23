import Foundation
import Testing
import SendaDomain
import SendaPersistence
import SendaLogger

@MainActor struct TrainerWorkflowTests {
    @Test func repeatSavesAndRotationKeepEditableCopiesWithoutScheduling() throws {
        let repository = MemoryJournalRepository()
        let model = try TrainingNotebookModel(repository: repository)
        let page = model.sampleTrainer
        try page.validate()
        let original = page.workouts[0]
        try #require(model.saveWorkout(WorkoutTemplate(name: original.name, exerciseIDs: ["bench"])))
        let days = model.workspace.days
        try #require(model.saveTrainerWorkout(original, from: page))
        let saved = try #require(model.savedWorkouts.first { $0.id == original.id })
        #expect(saved.name == original.name + " (2)" && saved.trainerCredit == page.name)
        let edited = WorkoutTemplate(id: saved.id, name: "Monday session", exerciseIDs: ["bench"], trainerCredit: saved.trainerCredit)
        try #require(model.saveWorkout(edited))
        try #require(model.saveTrainerWorkout(original, from: page))
        try #require(model.saveTrainerProgram(page))
        let program = try #require(model.customPrograms.first)
        #expect(program.blocks[0].sessions.count == 3 && program.weeks == 4)
        try #require(model.saveTrainerProgram(page))
        let reopened = try TrainingNotebookModel(repository: repository)
        #expect(reopened.savedWorkouts.first { $0.id == saved.id } == edited)
        #expect(reopened.customPrograms == [program])
        #expect(reopened.workspace.days == days && reopened.workspace.activeProgramEnrollments.isEmpty)
    }

    @Test func localListingRequiresReviewPublicationAndCurrentCredential() throws {
        let today = try TrainingDay("2026-11-23")
        var application = TrainerApplication(name: "Trainer", credential: "Sample CPT", credentialID: "DEMO-1", expires: today)
        var page = TrainerPage.sample
        page.id = UUID()
        application.preview = page
        #expect(application.listing(on: today) == nil)
        application.locallyApproved = true
        #expect(application.listing(on: today) == nil)
        let available = Set(page.workouts.flatMap(\.exerciseIDs))
        try application.publish(on: today, availableExercises: available)
        let live = try #require(application.listing(on: today))
        #expect(live.workouts == page.workouts && live.version == 1)
        #expect(try application.listing(on: today.adding(days: 1)) == nil)
        let profiles = MemoryProfileRepository()
        let model = ProfileModel(repository: profiles)
        try #require(model.saveTrainerApplication(application))
        try #require(model.saveName("Private notebook"))
        #expect(ProfileModel(repository: profiles).details.trainerApplication == application)

        application.preview?.workouts.removeLast()
        try #require(model.saveTrainerApplication(application))
        #expect(ProfileModel(repository: profiles).details.trainerApplication?.listing(on: today) == live)
        #expect(throws: TrainerPageError.self) { try application.publish(on: today, availableExercises: available) }
        #expect(application.listing(on: today) == live)
    }

    @Test func publicationRevisionsPreserveSavedWorkoutsAndScheduledTargets() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        var page = model.sampleTrainer
        page.id = UUID()
        var application = TrainerApplication(name: "Example", credential: "Sample", credentialID: "LOCAL", expires: model.today)
        application.preview = page
        application.locallyApproved = true
        let available = Set(model.activeExercises.map(\.id))
        try application.publish(on: model.today, availableExercises: available)
        let first = try #require(application.published)
        let a = first.workouts[0]
        let original = try #require(try first.makeProgram())
        try #require(model.saveTrainerProgram(first))
        try #require(model.saveTrainerWorkout(a, from: first))
        try #require(model.scheduleProgram(original, starting: model.today))
        #expect(model.nextScheduledSession?.day == model.today)
        let schedule = model.workspace.days
        var draft = first
        let lift = a.exerciseIDs[0]
        draft.workouts[0].exercisePlans[lift] = .init(workingSets: 4, minimumReps: 5, maximumReps: 7)
        draft.workouts[0].trainerDetails?.notes = "Rest between sets."
        application.preview = draft
        try application.publish(on: model.today, availableExercises: available)
        let revision = try #require(application.published)
        #expect(revision.version == 2 && revision.workouts[1] == first.workouts[1])
        #expect(revision.workouts[0].id != a.id && revision.workouts[0].trainerOriginID == a.id)
        try #require(model.saveTrainerWorkout(revision.workouts[0], from: revision))
        try #require(model.saveTrainerProgram(revision))
        #expect(model.customPrograms.count == 2 && model.savedWorkouts.count == 2)
        let latest = try #require(try revision.makeProgram())
        #expect(latest.blocks[0].sessions[0].exercises[0].plan == draft.workouts[0].exercisePlans[lift])
        #expect(latest.blocks[0].sessions[0].trainerDetails == draft.workouts[0].trainerDetails)
        #expect(model.workspace.days == schedule && model.workspace.activeProgramEnrollments[0].program == original)
        try application.publish(on: model.today, availableExercises: available)
        #expect(application.published == revision)

        draft = revision
        draft.workouts[0].exercisePlans[lift] = nil
        #expect(throws: TrainerPageError.self) { try draft.makeProgram() }
        draft.groupsIntoProgram = false
        #expect(throws: TrainerPageError.self) { try draft.validate() }
        draft.workouts[0].exercisePlans[lift] = a.exercisePlans[lift]
        draft.programTitle = ""
        try draft.validate()
        #expect(try draft.makeProgram() == nil)
    }

    @Test func notebookBackupOmitsApplicationAndRestorePreservesDeviceReview() throws {
        let repo = MemoryJournalRepository()
        let profiles = MemoryProfileRepository()
        let model = try TrainingNotebookModel(repository: repo)
        var privateProfile = ProfileDetails(name: "Local")
        var app = TrainerApplication(name: "Trainer", credential: "Sample", credentialID: "SECRET-CREDENTIAL", expires: model.today)
        app.locallyApproved = true
        privateProfile.trainerApplication = app
        try profiles.save(privateProfile)
        let archive = NotebookArchive(snapshot: model.snapshot, profile: privateProfile)
        let encoded = try NotebookBackupCodec.encode(archive)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("SECRET-CREDENTIAL"))
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["profile"] = ["name": "Restored", "email": "", "trainerApplication": ["locallyApproved": true]]
        let incoming = try NotebookBackupCodec.decode(JSONSerialization.data(withJSONObject: object))
        #expect(incoming.profile.trainerApplication == nil)
        try MemoryNotebookRestoreStore(repository: repo, profileRepository: profiles).restore(incoming, current: nil)
        #expect(try profiles.load().name == "Restored")
        #expect(try profiles.load().trainerApplication == app)
    }
}
