import Foundation

struct WeekSwipeState {
    private enum Direction { case horizontal, vertical }
    private var direction: Direction?
    var isHorizontal: Bool { direction == .horizontal }

    mutating func move(_ translation: CGSize) {
        guard translation.width.isFinite, translation.height.isFinite else { cancel(); return }
        if direction == nil {
            direction = abs(translation.width) > abs(translation.height) * 1.2 ? .horizontal : .vertical
        }
    }

    mutating func finish(_ translation: CGSize) -> Int? {
        defer { cancel() }
        guard isHorizontal, translation.width.isFinite, translation.height.isFinite,
              abs(translation.width) >= 50,
              abs(translation.width) > abs(translation.height) * 1.2 else { return nil }
        return translation.width < 0 ? 1 : -1
    }

    mutating func cancel() { direction = nil }
}
