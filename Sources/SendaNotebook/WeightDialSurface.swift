import SwiftUI
import SendaDomain
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct WeightDialSurface: View {
    let value: Int
    let unit: WeightUnit
    var accessibilityValue: String? = nil
    var adjustAccessibility: ((Bool) -> Bool)? = nil
    let beginInteraction: () -> Void
    let update: (Int) -> Bool

    private enum Touch {
        case deciding(origin: CGFloat, weight: Int)
        case dragging(origin: CGFloat, tick: Int, typedPosition: CGFloat?)
        case ignored
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var fingerDown = false
    @State private var touch: Touch?
    @State private var position: CGFloat?
    @State private var centering: WeightDialRelease?
    @State private var lastWrite: Int?
    #if os(iOS)
    @State private var clickGenerator: UISelectionFeedbackGenerator?
    #endif

    private var scale: WeightDialScale { WeightDialScale(unit: unit) }
    private var visiblePosition: CGFloat { position ?? scale.position(for: value) }

    var body: some View {
        let scale = self.scale
        let center = min(CGFloat(scale.lastTick), max(0, visiblePosition))
        Canvas { context, size in
            let pitch = WeightDialScale.tickSpacing
            let radius = size.width / (2 * pitch) + 2
            let first = max(0, Int(floor(center - radius)))
            let last = min(scale.lastTick, Int(ceil(center + radius)))
            for tick in first...last {
                let x = size.width / 2 + (CGFloat(tick) - center) * pitch
                let endpoint = tick == scale.lastTick
                let major = tick.isMultiple(of: 4) || endpoint
                let height: CGFloat = major ? 22 : 12
                let mark = CGRect(x: x - 0.5, y: 1, width: 1, height: height)
                context.fill(Path(mark), with: .color(NotebookStyle.quiet.opacity(major ? 0.85 : 0.50)))
                if major && (endpoint || scale.lastTick - tick > 1) {
                    let text = Text(unit.text(for: scale.weight(at: tick)))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(NotebookStyle.quiet)
                    context.draw(text, at: CGPoint(x: x, y: 27), anchor: .top)
                }
            }
            let pointer = CGRect(x: size.width / 2 - 1, y: 0, width: 2, height: 26)
            context.fill(Path(roundedRect: pointer, cornerRadius: 1), with: .color(NotebookStyle.clay))
        }
        .frame(height: 60)
        .contentShape(Rectangle())
        .simultaneousGesture(drag)
        .task(id: centering) {
            if let centering { await run(centering) }
        }
        .onChange(of: fingerDown) { _, down in
            // A parent scroll or system gesture can cancel a drag without sending onEnded.
            if !down, touch != nil { reset() }
        }
        .onChange(of: value) { _, newValue in
            if newValue != lastWrite { interrupt() }
        }
        .onChange(of: unit) { _, _ in interrupt() }
        .onChange(of: reduceMotion) { _, enabled in if enabled && centering != nil { interrupt() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { interrupt() } }
        .onDisappear { reset() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weight dial in \(unit.symbol)")
        .accessibilityValue(accessibilityValue ?? "\(unit.text(for: value)) \(unit.symbol)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(increasing: true)
            case .decrement: step(increasing: false)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("weight-dial")
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($fingerDown) { _, down, _ in down = true }
            .onChanged { gesture in
                if touch == nil {
                    let origin = visiblePosition
                    let weight = lastWrite ?? value
                    centering = nil
                    position = origin
                    touch = .deciding(origin: origin, weight: weight)
                    prepareClicks()
                }
                if case let .deciding(origin, weight) = touch {
                    let dx = abs(gesture.translation.width)
                    let dy = abs(gesture.translation.height)
                    guard max(dx, dy) >= 4 else { return }
                    guard dx > dy else {
                        interrupt()
                        return
                    }
                    let start = scale.position(for: weight)
                    let tick = scale.nearestTick(to: start)
                    let typedPosition = start == CGFloat(tick) ? nil : start
                    touch = .dragging(origin: origin, tick: tick, typedPosition: typedPosition)
                    beginInteraction()
                }
                if case let .dragging(origin, tick, typedPosition) = touch {
                    turn(from: origin, engaged: tick, typedPosition: typedPosition, translation: gesture.translation.width)
                }
            }
            .onEnded { _ in
                switch touch {
                case .deciding, .dragging:
                    let start = visiblePosition
                    let rest = scale.position(for: lastWrite ?? value)
                    touch = nil
                    if !reduceMotion && abs(rest - start) >= 0.001 {
                        centering = WeightDialRelease(from: start, to: rest)
                    } else {
                        reset()
                    }
                case .ignored, nil:
                    reset()
                }
            }
    }

    private func turn(from origin: CGFloat, engaged: Int, typedPosition: CGFloat?, translation: CGFloat) {
        let raw = scale.dragPosition(from: origin, translation: translation)
        let next = scale.engagedTick(at: raw, from: engaged, preserving: typedPosition)
        if next != engaged {
            let weight = scale.weight(at: next)
            guard update(weight) else { interrupt(); return }
            lastWrite = weight
            touch = .dragging(origin: origin, tick: next, typedPosition: nil)
            click(count: abs(next - engaged))
        }
        position = scale.dragDisplayPosition(at: raw, engaged: next)
    }

    private func run(_ motion: WeightDialRelease) async {
        let clock = ContinuousClock()
        let began = clock.now
        while !Task.isCancelled, centering == motion {
            let seconds = began.duration(to: clock.now) / .seconds(1)
            let next = motion.position(after: seconds)
            position = next
            if next == motion.end {
                reset()
                return
            }
            do { try await Task.sleep(for: .milliseconds(8)) } catch { return }
        }
    }

    private func step(increasing: Bool) {
        interrupt()
        beginInteraction()
        let weight = unit.stepped(value, increasing: increasing)
        guard weight != value else { return }
        if let adjustAccessibility {
            if adjustAccessibility(increasing) { click() }
        } else if update(weight) {
            click()
        }
    }

    private func prepareClicks() {
        #if os(iOS)
        if clickGenerator == nil { clickGenerator = UISelectionFeedbackGenerator() }
        clickGenerator?.prepare()
        #endif
    }

    private func click(count: Int = 1) {
        #if os(iOS)
        let generator = clickGenerator ?? UISelectionFeedbackGenerator()
        for _ in 0..<count { generator.selectionChanged() }
        generator.prepare()
        #elseif os(macOS)
        for _ in 0..<count {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        #endif
    }

    private func interrupt() {
        let hasTouch = touch != nil
        reset()
        if hasTouch { touch = .ignored }
    }

    private func reset() {
        centering = nil
        position = nil
        lastWrite = nil
        touch = nil
    }
}
