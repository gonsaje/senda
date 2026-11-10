import Foundation
import Testing
@testable import SendaNotebook

struct WeekSwipeTests {
    @Test func horizontalSwipesMoveOneWeekAndOnlyOnceOnRelease() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: -30, height: 2))
        #expect(swipe.isHorizontal)
        #expect(swipe.finish(CGSize(width: -160, height: 4)) == 1)
        #expect(swipe.finish(CGSize(width: -160, height: 4)) == nil)
        swipe.move(CGSize(width: 30, height: 2))
        #expect(swipe.finish(CGSize(width: 160, height: 4)) == -1)
    }

    @Test func verticalStartCannotBecomeWeekNavigation() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: 2, height: -25))
        swipe.move(CGSize(width: -180, height: -60))
        #expect(!swipe.isHorizontal)
        #expect(swipe.finish(CGSize(width: -180, height: -60)) == nil)
    }

    @Test func shortDragsAndDiagonalGesturesKeepCurrentWeek() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: -20, height: 1))
        #expect(swipe.finish(CGSize(width: -24, height: 2)) == nil)
        swipe.move(CGSize(width: -20, height: -20))
        #expect(swipe.finish(CGSize(width: -100, height: -100)) == nil)
        swipe.move(CGSize(width: 30, height: 1))
        #expect(swipe.finish(CGSize(width: 40, height: 180)) == nil)
    }

    @Test func cancelledSwipeDoesNotNavigateAndNextGestureStillWorks() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: -160, height: 0))
        swipe.cancel()
        #expect(!swipe.isHorizontal)
        #expect(swipe.finish(CGSize(width: -160, height: 0)) == nil)
        swipe.move(CGSize(width: 30, height: 1))
        #expect(swipe.finish(CGSize(width: 120, height: 1)) == -1)
    }

    @Test func invalidTranslationCannotNavigateOrLeaveControlsDisabled() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: -120, height: 0))
        swipe.move(CGSize(width: CGFloat.nan, height: 0))
        #expect(!swipe.isHorizontal)
        #expect(swipe.finish(CGSize(width: -120, height: 0)) == nil)
        swipe.move(CGSize(width: -30, height: 0))
        #expect(swipe.finish(CGSize(width: -160, height: CGFloat.infinity)) == nil)
        #expect(!swipe.isHorizontal)
    }
}
