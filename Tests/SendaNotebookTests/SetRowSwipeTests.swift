import Foundation
import Testing
@testable import SendaNotebook

struct SetRowSwipeTests {
    @Test func shortLeftSwipeRevealsWithoutDeleting() {
        var swipe = SetRowSwipeState()
        swipe.move(CGSize(width: -45, height: 2), opened: false, width: 320)
        #expect(swipe.offset == -45)
        #expect(swipe.finish(CGSize(width: -45, height: 2), width: 320) == .revealed)
        #expect(swipe.offset == nil)
    }
    @Test func fullSwipeRequiresActualDistance() {
        var swipe = SetRowSwipeState()
        swipe.move(CGSize(width: -40, height: 1), opened: false, width: 320)
        #expect(swipe.finish(CGSize(width: -190, height: 1), width: 320) == .revealed)
        swipe.move(CGSize(width: -30, height: 1), opened: false, width: 320)
        #expect(swipe.finish(CGSize(width: -200, height: 1), width: 320) == .delete)
    }
    @Test func verticalGestureCannotTurnIntoDeletion() {
        var swipe = SetRowSwipeState()
        swipe.move(CGSize(width: -3, height: 20), opened: false, width: 320)
        swipe.move(CGSize(width: -280, height: 30), opened: false, width: 320)
        #expect(swipe.offset == nil)
        #expect(swipe.finish(CGSize(width: -280, height: 30), width: 320) == .unchanged)
    }
    @Test func rightSwipeClosesAnOpenRow() {
        var swipe = SetRowSwipeState()
        swipe.move(CGSize(width: 35, height: 0), opened: true, width: 320)
        #expect(swipe.finish(CGSize(width: 65, height: 0), width: 320) == .closed)
    }
    @Test func cancellationResetsWithoutDeletingAndNextGestureStillWorks() {
        var swipe = SetRowSwipeState()
        swipe.move(CGSize(width: -250, height: 0), opened: false, width: 320)
        swipe.cancel()
        #expect(swipe.offset == nil)
        #expect(swipe.finish(CGSize(width: -250, height: 0), width: 320) == .unchanged)
        swipe.move(CGSize(width: -40, height: 0), opened: false, width: 320)
        #expect(swipe.finish(CGSize(width: -40, height: 0), width: 320) == .revealed)
    }
    @Test func unmeasuredWidthCannotDelete() {
        var swipe = SetRowSwipeState()
        swipe.move(CGSize(width: -300, height: 0), opened: false, width: 0)
        #expect(swipe.finish(CGSize(width: -300, height: 0), width: 0) != .delete)
    }
    @Test func smallMotionClosesWithoutDeleting() {
        var swipe = SetRowSwipeState()
        swipe.move(CGSize(width: -14, height: 0), opened: false, width: 320)
        #expect(swipe.finish(CGSize(width: -14, height: 0), width: 320) == .closed)
    }
}
