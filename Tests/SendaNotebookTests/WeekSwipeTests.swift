import Foundation
import Testing
@testable import SendaNotebook

struct WeekSwipeTests {
    @Test func verticalSwipesMoveOneWeekAndOnlyOnceOnRelease() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: 2, height: -30))
        #expect(swipe.isVertical)
        #expect(swipe.finish(CGSize(width: 4, height: -160)) == 1)
        #expect(swipe.finish(CGSize(width: 4, height: -160)) == nil)
        swipe.move(CGSize(width: 2, height: 30))
        #expect(swipe.finish(CGSize(width: 4, height: 160)) == -1)
    }

    @Test func horizontalStartCannotBecomeWeekNavigation() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: -25, height: 2))
        swipe.move(CGSize(width: -60, height: -180))
        #expect(!swipe.isVertical)
        #expect(swipe.finish(CGSize(width: -60, height: -180)) == nil)
    }

    @Test func shortDragsAndDiagonalGesturesKeepCurrentWeek() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: 1, height: -20))
        #expect(swipe.finish(CGSize(width: 2, height: -24)) == nil)
        swipe.move(CGSize(width: -20, height: -20))
        #expect(swipe.finish(CGSize(width: -100, height: -100)) == nil)
        swipe.move(CGSize(width: 1, height: 30))
        #expect(swipe.finish(CGSize(width: 180, height: 40)) == nil)
    }

    @Test func cancelledSwipeDoesNotNavigateAndNextGestureStillWorks() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: 0, height: -160))
        swipe.cancel()
        #expect(!swipe.isVertical)
        #expect(swipe.finish(CGSize(width: 0, height: -160)) == nil)
        swipe.move(CGSize(width: 1, height: 30))
        #expect(swipe.finish(CGSize(width: 1, height: 120)) == -1)
    }

    @Test func invalidTranslationCannotNavigateOrLeaveControlsDisabled() {
        var swipe = WeekSwipeState()
        swipe.move(CGSize(width: 0, height: -120))
        swipe.move(CGSize(width: 0, height: CGFloat.nan))
        #expect(!swipe.isVertical)
        #expect(swipe.finish(CGSize(width: 0, height: -120)) == nil)
        swipe.move(CGSize(width: 0, height: -30))
        #expect(swipe.finish(CGSize(width: CGFloat.infinity, height: -160)) == nil)
        #expect(!swipe.isVertical)
    }
}
