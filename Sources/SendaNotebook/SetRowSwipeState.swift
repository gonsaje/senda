import Foundation

struct SetRowSwipeState {
    enum Result { case unchanged, closed, revealed, delete }
    private enum Direction { case horizontal, vertical }
    static let revealWidth: CGFloat = 56
    private var direction: Direction?
    private var origin: CGFloat = 0
    private(set) var offset: CGFloat?
    var isHorizontal: Bool { direction == .horizontal }

    mutating func move(_ translation: CGSize, opened: Bool, width: CGFloat) {
        guard translation.width.isFinite, translation.height.isFinite else { cancel(); return }
        if direction == nil {
            direction = abs(translation.width) > abs(translation.height) * 1.2 ? .horizontal : .vertical
            origin = opened ? -Self.revealWidth : 0
        }
        guard isHorizontal else { return }
        offset = min(0, max(-max(0, width.isFinite ? width : 0), origin + translation.width))
    }

    mutating func finish(_ translation: CGSize, width: CGFloat) -> Result {
        defer { cancel() }
        guard isHorizontal, translation.width.isFinite, width.isFinite, width > 0 else { return .unchanged }
        let travel = min(width, max(0, -(origin + translation.width)))
        if travel >= max(120, width * 0.6) { return .delete }
        return travel >= Self.revealWidth / 2 ? .revealed : .closed
    }

    mutating func cancel() { direction = nil; origin = 0; offset = nil }
}
