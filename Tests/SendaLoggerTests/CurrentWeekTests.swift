import Foundation
import Testing
import SendaDomain
import SendaPersistence
@testable import SendaLogger

@MainActor struct CurrentWeekTests {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private var today: TrainingDay { try! TrainingDay("2026-11-08") }
    @Test func todayReturnsToCurrentWeekWithoutCreatingAWorkout() throws {
        let store = MemoryJournalRepository()
        let model = try TrainingNotebookModel(repository: store, calendar: calendar, now: { today.date(in: calendar) })
        #expect(model.openDay(try TrainingDay("2026-11-23"))); #expect(model.showWeek())
        #expect(model.showCurrentWeek())
        #expect(model.workspace.visibleWeek.rawValue == "2026-11-02")
        #expect(model.selectedDay == nil && model.workspace.days[today.rawValue] == nil)
        #expect(model.journal.batches.isEmpty)
        let reopened = try TrainingNotebookModel(repository: store, calendar: calendar, now: { today.date(in: calendar) })
        #expect(reopened.workspace.visibleWeek.rawValue == "2026-11-02" && reopened.selectedDay == nil)
    }
    @Test func failedTodayNavigationKeepsInputAndRetryRecordsOnlyOnce() throws {
        let store = CurrentWeekFailureStore()
        let model = try TrainingNotebookModel(repository: store, calendar: calendar, now: { today.date(in: calendar) })
        #expect(model.openDay(try TrainingDay("2026-11-23"))); #expect(model.addExercise("bench"))
        let row = try #require(model.rows.first)
        #expect(model.selectInput(row.id, field: .weight)); model.typeInput("135", focus: try #require(model.focus))
        #expect(model.selectInput(row.id, field: .reps)); model.typeInput("10", focus: try #require(model.focus))
        let before = model.snapshot
        store.reject = true
        #expect(!model.showCurrentWeek())
        #expect(model.snapshot == before && model.focus != nil)
        store.reject = false
        #expect(model.showCurrentWeek()); #expect(model.showCurrentWeek())
        #expect(model.workspace.visibleWeek.rawValue == "2026-11-02" && model.journal.batches.count == 1)
    }
    @Test func todayUsesTheLocalCalendarAcrossYearAndWeekBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let localDate = try TrainingDay("2026-12-31").date(in: calendar)
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), calendar: calendar, now: { localDate })
        #expect(model.changeWeek(-1)); #expect(model.showCurrentWeek())
        #expect(model.workspace.visibleWeek.rawValue == "2026-12-28")
        #expect(model.weekDays.last?.rawValue == "2027-01-03")
    }
}
@MainActor private final class CurrentWeekFailureStore: JournalRepository {
    private var snapshot = JournalSnapshot()
    var reject = false
    func loadSnapshot() throws -> JournalSnapshot { snapshot }
    func saveSnapshot(_ next: JournalSnapshot) throws {
        if reject { throw CocoaError(.fileWriteUnknown) }
        snapshot = try next.validated()
    }
}
