import Foundation
import SendaDomain
import SendaLogger
import SendaPersistence
import Testing

@MainActor struct TrainingProgramTests {
    private let start = try! TrainingDay("2026-11-23")

    @Test func catalogPreviewsWorkoutsAndSchedulesOnlyAvailableDates() throws {
        let repo = MemoryJournalRepository()
        let model = try TrainingNotebookModel(repository: repo)
        let program = try #require(TrainingProgram.catalog.last)
        let planned = try start.adding(days: 2)
        #expect(model.openDay(planned))
        #expect(model.addExercise("bench"))
        let preserved = try #require(model.workout)
        let slots = try model.previewProgram(program, starting: start)
        #expect(slots.count == 36 && slots.filter(\.isOccupied).count == 1)
        #expect(slots[12].blockTitle == "Build" && slots[24].week == 9)
        #expect(model.scheduleProgram(program, starting: start))
        #expect(model.workspace.days[planned.rawValue] == preserved)
        let upper = try #require(model.workspace.days[start.rawValue])
        #expect(upper.programSession?.week == 1)
        #expect(upper.exercisePlans?["bench"]?.workingSets == 2)
        #expect(upper.supersets?.first?.plan.first == "bench")
        #expect(upper.rows.values.flatMap { $0 }.allSatisfy { $0.performedSetID == nil })
        let persisted = try TrainingNotebookModel(repository: repo)
        #expect(persisted.isProgramScheduled(program, starting: start))
        let again = try persisted.previewProgram(program, starting: start)
        #expect(again.filter(\.isScheduled).count == 35)
        #expect(persisted.scheduleProgram(program, starting: start))
        #expect(persisted.snapshot == model.snapshot)
    }

    @Test func authoredProgramTransfersAndScheduledCopySurvivesEditingDeletionAndBackup() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = FileJournalRepository(url: tmp.appendingPathComponent("journal.json"))
        let model = try TrainingNotebookModel(repository: repo)
        var program = TrainingProgram.catalog[0].copyForEditing()
        program.title = "Club training"
        program.author = "Taylor"
        program.credential = "CSCS"
        #expect(model.saveProgram(program))
        #expect(try model.importProgram(program.exportData()) == program)
        #expect(model.customPrograms.count == 1)
        #expect(model.scheduleProgram(program, starting: start))
        let original = try #require(model.workspace.days[start.rawValue])
        let scheduledDefinition = program
        let personalCopy = program.copyForEditing()
        #expect(personalCopy.author == nil && personalCopy.credential == nil && personalCopy.sourceURL == program.sourceURL)
        program.title = "Updated program"
        program.blocks[0].weeks = 2
        program.blocks[0].sessions.removeLast()
        #expect(model.saveProgram(program))
        let reopened = try TrainingNotebookModel(repository: repo)
        #expect(reopened.customPrograms.first?.title == "Updated program")
        #expect(reopened.scheduledProgram(program, starting: start) == scheduledDefinition)
        #expect(try reopened.previewProgram(program, starting: start).count == 8)
        #expect(reopened.deleteProgram(id: program.id))
        #expect(reopened.workspace.days[start.rawValue] == original)
        #expect(reopened.programSession(on: start)?.author == "Taylor")
        let archive = try NotebookBackupCodec.decode(reopened.backupData())
        #expect(archive.snapshot.training == reopened.workspace)
    }

    @Test func malformedOrUnknownImportLeavesSavedWorkAlone() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        var original = TrainingProgram.catalog[0].copyForEditing()
        #expect(model.saveProgram(original))
        let snapshot = model.snapshot
        original.blocks[0].sessions[0].exercises[0].exerciseID = "unknown-id"
        #expect(throws: (any Error).self) { try model.importProgram(original.exportData()) }
        #expect(model.snapshot == snapshot)
        #expect(!model.deleteProgram(id: TrainingProgram.catalog[0].id))
        #expect(model.snapshot == snapshot)
    }

    @Test func programsTravelWithReferencedCustomExercisesAndProtectExistingDefinitions() throws {
        let sender = try TrainingNotebookModel(repository: MemoryJournalRepository())
        #expect(sender.createLibraryExercise(named: "Porch press", group: .chest, equipment: .dumbbell))
        #expect(sender.createLibraryExercise(named: "Club curl", group: .arms, equipment: .cable))
        let porch = try #require(sender.snapshot.customExercises?.first)
        var program = TrainingProgram.catalog[0].copyForEditing()
        program.blocks[0].sessions[0].exercises[2].exerciseID = porch.id
        #expect(sender.saveProgram(program))
        let file = try sender.exportProgram(program)
        let store = ProgramWriteStore()
        let recipient = try TrainingNotebookModel(repository: store)
        let prior = recipient.snapshot, priorStored = store.snapshot
        store.reject = true
        #expect(throws: (any Error).self) { try recipient.importProgram(file) }
        #expect(recipient.snapshot == prior && store.snapshot == priorStored)
        store.reject = false
        #expect(recipient.retrySave())
        #expect(try recipient.importProgram(file) == program)
        #expect(recipient.customPrograms == [program] && recipient.snapshot.customExercises == [porch])
        #expect(recipient.scheduleProgram(program, starting: start))
        #expect(recipient.programSession(on: start)?.exercises.last?.exerciseID == porch.id)
        #expect(recipient.updateCustomExercise(porch.id, named: "Porch incline press", group: .chest, equipment: .dumbbell))
        let modified = recipient.snapshot
        #expect(throws: (any Error).self) { try recipient.importProgram(file) }
        #expect(recipient.snapshot == modified)
        #expect(recipient.archiveCustomExercise(porch.id))
        let removed = recipient.snapshot
        #expect(throws: (any Error).self) { try recipient.importProgram(file) }
        #expect(!recipient.scheduleProgram(program, starting: try start.adding(days: 35)))
        #expect(recipient.unavailableProgramExercises(program).map(\.id) == [porch.id])
        #expect(recipient.snapshot == removed)
    }

    @Test func resetSingleExerciseAndUndoPreserveProgramHistory() throws {
        let repo = MemoryJournalRepository()
        let model = try TrainingNotebookModel(repository: repo)
        let program = TrainingProgram(title: "One lift", blocks: [
            .init(title: "Practice", weeks: 1, sessions: [.init(title: "Pull", exercises: [.init(exerciseID: "row")])])
        ])
        #expect(model.scheduleProgram(program, starting: start) && model.openDay(start))
        let original = try #require(model.workout)
        for target in [TrainingWorkoutRemoval.exercise("row"), .workout] {
            #expect(model.deleteFromWorkout(target, on: start))
            #expect(model.programSession(on: start) == nil)
            #expect(model.workspace.activeProgramEnrollments.isEmpty && !model.isProgramScheduled(program, starting: start))
            let overlapping = try model.previewProgram(TrainingProgram.catalog[0], starting: start)
            #expect(overlapping.first?.isOccupied == true)
            let relaunched = try TrainingNotebookModel(repository: repo)
            #expect(try NotebookBackupCodec.decode(relaunched.backupData()).snapshot.training == relaunched.workspace)
            #expect(model.undoChange() && model.workout == original)
            #expect(model.programSession(on: start)?.sessionTitle == "Pull")
        }
        #expect(model.deleteFromWorkout(.workout, on: start) && model.showWeek())
        #expect(model.workspace.programEnrollments == nil)
        var updated = program
        updated.blocks[0].sessions[0].title = "Club row"
        #expect(model.scheduleProgram(updated, starting: start))
        #expect(model.programSession(on: start)?.sessionTitle == "Club row")
    }

    @Test func largestProgramCalendarAndFullBackupRoundTrip() throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository())
        let ids = Exercise.catalog.prefix(30).map(\.id)
        let plans = ids.map { ProgramExercise(exerciseID: $0, targetRIR: 2, restSeconds: 90) }
        let pairs = stride(from: 0, to: ids.count, by: 2).map {
            SupersetPlan(first: ids[$0], second: ids[$0 + 1], rounds: 2, restSeconds: 90)
        }
        let sessions = (0..<7).map { ProgramSession(title: "Day " + String($0 + 1), dayOffset: $0, exercises: plans, supersets: pairs) }
        let blocks = (1...52).map { ProgramBlock(title: "Block " + String($0), weeks: 1, sessions: sessions) }
        let program = TrainingProgram(title: "Year plan", blocks: blocks)
        #expect(model.saveProgram(program) && model.scheduleProgram(program, starting: start))
        #expect(model.workspace.days.values.filter { $0.programSession != nil }.count == 364)
        #expect(try NotebookBackupCodec.decode(model.backupData()).snapshot == model.snapshot)
        do { #expect(try TrainingProgram.decodeFile(model.exportProgram(program)) == program) }
        catch ProgramError.exportTooLarge { /* legitimately above the transport limit */ }
    }

    @Test func storageDetectsMissingProgramOrPairData() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let journalURL = folder.appendingPathComponent("journal.json")
        let store = FileJournalRepository(url: journalURL)
        let model = try TrainingNotebookModel(repository: store)
        let program = TrainingProgram.catalog[0].copyForEditing()
        #expect(model.saveProgram(program) && model.scheduleProgram(program, starting: start))
        var local = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: journalURL)) as? [String: Any])
        #expect(local["version"] as? Int == 11)
        var training = try #require(local["training"] as? [String: Any])
        training.removeValue(forKey: "programs")
        local["training"] = training
        try JSONSerialization.data(withJSONObject: local).write(to: journalURL)
        #expect(throws: StorageError.incompleteStructuredTraining) { try store.loadSnapshot() }

        var backup = try #require(JSONSerialization.jsonObject(with: model.backupData()) as? [String: Any])
        #expect(backup["version"] as? Int == 10)
        var counts = try #require(backup["structuredTraining"] as? [String: Int])
        counts["supersets"] = 0
        backup["structuredTraining"] = counts
        #expect(throws: NotebookBackupError.invalidBackup) {
            try NotebookBackupCodec.decode(JSONSerialization.data(withJSONObject: backup))
        }
    }

    @Test func failedScheduleDoesNotPartiallyPopulateTheCalendar() throws {
        let store = ProgramWriteStore()
        let model = try TrainingNotebookModel(repository: store)
        let before = model.snapshot, beforeStored = store.snapshot
        store.reject = true
        #expect(!model.scheduleProgram(TrainingProgram.catalog[1], starting: start))
        #expect(model.snapshot == before && store.snapshot == beforeStored)
        store.reject = false
        #expect(model.retrySave())
        #expect(try model.previewProgram(TrainingProgram.catalog[1], starting: start).filter(\.isScheduled).count == 36)
    }
}

@MainActor private final class ProgramWriteStore: JournalRepository {
    var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ candidate: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try candidate.validated()
    }
}
