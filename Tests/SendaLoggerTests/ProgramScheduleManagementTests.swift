import Foundation
import SendaDomain
import SendaLogger
import SendaPersistence
import Testing

@MainActor struct ProgramScheduleManagementTests {
    let start = try! TrainingDay("2026-11-23")
    var program: TrainingProgram { TrainingProgram.catalog[0] }

    private func makeModel(_ store: MemoryJournalRepository, today: TrainingDay) throws -> TrainingNotebookModel {
        let date = today.date()
        return try TrainingNotebookModel(repository: store, now: { date })
    }

    @Test func preservingPastDraftsAndModifiedPrescriptionsDuringEndAndUndo() throws {
        let repo = MemoryJournalRepository()
        let model = try makeModel(repo, today: start.adding(days: 3))
        #expect(model.scheduleProgram(program, starting: start))
        let enrollment = try #require(model.workspace.activeProgramEnrollments.first)
        let draft = try start.adding(days: 3)
        let customized = try start.adding(days: 7)
        #expect(model.openDay(draft))
        #expect(model.addExercise("deadlift"))
        #expect(model.openDay(customized))
        #expect(model.startSuperset(try #require(model.supersets.first?.id)))
        #expect(model.showWeek())
        let original = model.workspace
        let plan = try model.previewScheduleChange(enrollment, action: .end)
        #expect(plan.preserved.map(\.day) == [start, draft, customized])
        #expect(plan.changes.count == 5)
        #expect(model.applyScheduleChange(plan))
        for day in [start, draft, customized] { #expect(model.workspace.days[day.rawValue] == original.days[day.rawValue]) }
        #expect(model.workspace.days.count == 3 && model.workspace.programEnrollments?.first?.endedOn == model.today)
        let again = try makeModel(repo, today: model.today)
        #expect(again.programSession(on: customized)?.week == 2)
        #expect(model.undoScheduleChange(plan))
        #expect(model.workspace == original)
    }

    @Test func movingOverlappingDaysIsAtomicAndKeepsPrescriptionsAcrossRelaunch() throws {
        let repo = MemoryJournalRepository()
        let model = try makeModel(repo, today: start)
        #expect(model.scheduleProgram(program, starting: start))
        let enrollment = try #require(model.workspace.activeProgramEnrollments.first)
        let conflict = try start.adding(days: 31)
        #expect(model.openDay(conflict) && model.addExercise("deadlift") && model.showWeek())
        let original = model.workspace
        let blocked = try model.previewScheduleChange(enrollment, action: .move(firstDay: start.adding(days: 7)))
        #expect(blocked.conflicts == [conflict])
        #expect(!model.applyScheduleChange(blocked) && model.workspace == original)
        let next = try start.adding(days: 3)
        let move = try model.previewScheduleChange(enrollment, action: .move(firstDay: next))
        #expect(move.canApply && move.changes.count == 8)
        #expect(model.applyScheduleChange(move))
        let moved = model.workspace
        #expect(model.applyScheduleChange(move) && model.workspace == moved)
        let reloaded = try makeModel(repo, today: start)
        #expect(reloaded.programSession(on: next)?.week == 1)
        #expect(reloaded.programSession(on: try next.adding(days: 7))?.week == 2)
        #expect(try reloaded.previewProgram(program, starting: start).map(\.day) == move.changes.compactMap(\.destination))
        #expect(try NotebookBackupCodec.decode(reloaded.backupData()).snapshot == model.snapshot)
        #expect(model.undoScheduleChange(move) && model.workspace == original)
    }

    @Test func loggedSessionsAndPartiallyTypedSetsStayOnTheirDates() throws {
        let model = try makeModel(MemoryJournalRepository(), today: start)
        #expect(model.scheduleProgram(program, starting: start))
        let enrollment = try #require(model.workspace.activeProgramEnrollments.first)
        let draft = try start.adding(days: 3)
        #expect(model.openDay(start))
        let row = try #require(model.rows.first?.id)
        #expect(model.selectInput(row, field: .weight))
        model.typeInput("135", focus: try #require(model.focus))
        #expect(model.selectInput(row, field: .reps))
        model.typeInput("8", focus: try #require(model.focus))
        #expect(model.openDay(draft))
        #expect(model.selectInput(try #require(model.rows.first?.id), field: .weight))
        model.typeInput("32", focus: try #require(model.focus))
        #expect(model.showWeek())
        let original = model.snapshot
        let plan = try model.previewScheduleChange(enrollment, action: .end)
        #expect(plan.preserved.map(\.day) == [start, draft])
        #expect(model.applyScheduleChange(plan))
        #expect(model.workspace.days[start.rawValue] == original.training?.days[start.rawValue])
        #expect(model.workspace.days[draft.rawValue] == original.training?.days[draft.rawValue])
        #expect(model.snapshot.journal == original.journal)
    }

    @Test func oldSchedulesKeepDaysWithAnIndividualUnitChange() throws {
        let original = try makeModel(MemoryJournalRepository(), today: start)
        #expect(original.scheduleProgram(program, starting: start))
        var legacy = original.snapshot
        let days = original.workspace.days.keys
        for day in days { legacy.training?.days[day]?.programSession?.initialUnit = nil }
        let enrollment = try #require(original.workspace.activeProgramEnrollments.first)
        let restored = try makeModel(MemoryJournalRepository(snapshot: legacy), today: start)
        #expect(restored.openDay(start) && restored.changeUnit(.kilograms) && restored.showWeek())
        let plan = try restored.previewScheduleChange(enrollment, action: .end)
        #expect(plan.preserved.map(\.day) == [start] && plan.changes.count == 7)

        var mixedLegacy = restored.snapshot
        mixedLegacy.training?.days[start.rawValue]?.programSession?.initialUnit = nil
        let mixed = try makeModel(MemoryJournalRepository(snapshot: mixedLegacy), today: start)
        let uncertain = try mixed.previewScheduleChange(enrollment, action: .end)
        #expect(uncertain.changes.isEmpty && uncertain.preserved.count == 8)
    }

    @Test func staleActionsAndUndoCannotOverwriteEdits() throws {
        let repo = MemoryJournalRepository()
        let model = try makeModel(repo, today: start)
        #expect(model.scheduleProgram(program, starting: start))
        let enrollment = try #require(model.workspace.activeProgramEnrollments.first)
        let stale = try model.previewScheduleChange(enrollment, action: .end)
        #expect(model.openDay(start) && model.addExercise("deadlift") && model.showWeek())
        let edited = model.workspace
        #expect(!model.applyScheduleChange(stale) && model.workspace == edited)
        let valid = try model.previewScheduleChange(enrollment, action: .end)
        #expect(model.applyScheduleChange(valid))
        let removedDay = try #require(valid.changes.first?.day)
        #expect(model.openDay(removedDay) && model.addExercise("row") && model.showWeek())
        let withNewWorkout = model.workspace
        #expect(!model.undoScheduleChange(valid) && model.workspace == withNewWorkout)
    }

    @Test func endingAllRemainingWorkoutsCanBeUndoneEvenWithNoRemainingEnrollment() throws {
        let model = try makeModel(MemoryJournalRepository(), today: start)
        #expect(model.scheduleProgram(program, starting: start))
        let enrollment = try #require(model.workspace.activeProgramEnrollments.first)
        let change = try model.previewScheduleChange(enrollment, action: .end)
        let all = model.workspace
        #expect(change.changes.count == 8 && model.applyScheduleChange(change))
        #expect(model.workspace.programEnrollments == nil && model.workspace.days.isEmpty)
        #expect(model.undoScheduleChange(change) && model.workspace == all)
        #expect(model.undoScheduleChange(change) && model.workspace == all)
    }
}
