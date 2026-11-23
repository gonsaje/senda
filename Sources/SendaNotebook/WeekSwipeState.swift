import Foundation

struct WeekSwipeState {
    private enum Direction { case horizontal, vertical }
    private var direction: Direction?
    var isVertical: Bool { direction == .vertical }

    mutating func move(_ translation: CGSize) {
        guard translation.width.isFinite, translation.height.isFinite else { cancel(); return }
        if direction == nil {
            direction = abs(translation.height) > abs(translation.width) * 1.2 ? .vertical : .horizontal
        }
    }

    mutating func finish(_ translation: CGSize) -> Int? {
        defer { cancel() }
        guard isVertical, translation.width.isFinite, translation.height.isFinite,
              abs(translation.height) >= 50,
              abs(translation.height) > abs(translation.width) * 1.2 else { return nil }
        return translation.height < 0 ? 1 : -1
    }

    mutating func cancel() { direction = nil }
}
