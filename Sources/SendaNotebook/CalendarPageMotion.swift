import SwiftUI

/// Only the moving strip observes the offset. Date cells and workout summaries stay laid out during a pan.
@MainActor @Observable
final class CalendarPageMotion {
    private(set) var offset: CGFloat = 0
    private(set) var isMoving = false
    @ObservationIgnored private var dragOrigin: CGFloat?
    @ObservationIgnored private var flight: Flight?
    nonisolated private static let spring = Spring(duration: 0.28, bounce: 0)

    private struct Flight {
        let id = UUID()
        let start = ProcessInfo.processInfo.systemUptime
        let from: CGFloat
        let to: CGFloat
        let velocity: CGFloat
        let changePage: (() -> Bool)?

        var position: CGFloat {
            CalendarPageMotion.spring.value(fromValue: from, toValue: to, initialVelocity: velocity,
                time: ProcessInfo.processInfo.systemUptime - start)
        }
    }

    func drag(_ translation: CGFloat, within range: ClosedRange<CGFloat>) {
        if dragOrigin == nil {
            // A second swipe can catch the strip while it is still settling.
            isMoving = true
            dragOrigin = finishFlight(at: flight?.position ?? offset, interrupted: true)
        }
        offset = min(max((dragOrigin ?? 0) + translation, range.lowerBound), range.upperBound)
    }

    func release(to target: CGFloat, velocity: CGFloat, changePage: (() -> Bool)? = nil) {
        dragOrigin = nil
        let distance = target - offset
        guard abs(distance) > 0.5 else {
            reset()
            _ = changePage?()
            return
        }
        let speed = min(8, max(0, velocity / distance))
        let next = Flight(from: offset, to: target, velocity: speed * distance, changePage: changePage)
        isMoving = true
        flight = next
        withAnimation(.interpolatingSpring(Self.spring, initialVelocity: speed), completionCriteria: .removed) {
            offset = target
        } completion: {
            guard self.flight?.id == next.id else { return }
            _ = self.finishFlight(at: target, interrupted: false)
        }
    }

    func cancelDrag() {
        guard dragOrigin != nil else { return }
        release(to: 0, velocity: 0)
    }

    func reset() {
        dragOrigin = nil
        flight = nil
        isMoving = false
        offset = 0
    }

    private func finishFlight(at position: CGFloat, interrupted: Bool) -> CGFloat {
        guard let flight else { return position }
        self.flight = nil
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return withTransaction(transaction) {
            let advanced = flight.changePage?() == true
            let remaining = position - (advanced ? flight.to : 0)
            // A failed save or a cancelled swipe leaves the original page centered.
            offset = interrupted ? remaining : 0
            isMoving = interrupted
            return offset
        }
    }
}

struct CalendarStripOffset: ViewModifier {
    let motion: CalendarPageMotion

    func body(content: Content) -> some View {
        content.offset(y: motion.offset)
    }
}
