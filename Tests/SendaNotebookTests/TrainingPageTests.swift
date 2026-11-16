import SendaDomain
import Testing
@testable import SendaNotebook

struct TrainingPageTests {
    @Test func adjacentTabsEnterFromTheirDockSide() {
        let log = TrainingPage(section: .log, selectedDay: nil)
        let trends = TrainingPage(section: .trends, selectedDay: nil)
        let learn = TrainingPage(section: .learn, selectedDay: nil)
        let profile = TrainingPage(section: .profile, selectedDay: nil)
        for (leading, trailing) in [(log, trends), (trends, learn), (learn, profile)] {
            #expect(trailing.entryOffset(from: leading, layout: .leftToRight) > 0)
            #expect(leading.entryOffset(from: trailing, layout: .leftToRight) < 0)
            #expect(trailing.entryOffset(from: leading, layout: .rightToLeft) < 0)
            #expect(leading.entryOffset(from: trailing, layout: .rightToLeft) > 0)
        }
    }

    @Test func workoutPageRetainsIdentityWhenItsDayChanges() throws {
        let day = try TrainingDay("2026-11-16")
        let week = TrainingPage(section: .log, selectedDay: nil)
        let workout = TrainingPage(section: .log, selectedDay: day)
        let nextWorkout = TrainingPage(section: .log, selectedDay: try day.adding(days: 1))
        let trends = TrainingPage(section: .trends, selectedDay: day)
        #expect(workout.entryOffset(from: week, layout: .leftToRight) > 0)
        #expect(week.entryOffset(from: workout, layout: .leftToRight) < 0)
        #expect(nextWorkout.identity == workout.identity)
        #expect(nextWorkout.entryOffset(from: workout, layout: .leftToRight) == 0)
        #expect(trends.entryOffset(from: workout, layout: .leftToRight) > 0)
        #expect(trends == TrainingPage(section: .trends, selectedDay: nil))
    }
}
