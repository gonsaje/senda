import SwiftUI
import SendaDomain
import SendaLogger

/// A lazy ruler spans the full weight range without recentering as it moves.
struct WeightDial: View {
    @Bindable var model: LoggerModel
    @State private var position: Int?
    init(model: LoggerModel) {
        self.model = model
        _position = State(initialValue: Self.tick(for: model.weightAmount, unit: model.selectedWeightUnit))
    }
    private var unit: WeightUnit { model.selectedWeightUnit }
    private var step: Double { NSDecimalNumber(decimal: unit.step).doubleValue }
    private var maximum: Double { NSDecimalNumber(decimal: unit.maximumAmount).doubleValue }
    private var lastTick: Int { Int(ceil(maximum / step)) }
    private var nearestTick: Int { Self.tick(for: model.weightAmount, unit: unit) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 0) {
                        ForEach(0...lastTick, id: \.self) { tick in
                            mark(tick).id(tick)
                        }
                    }.scrollTargetLayout()
                }
                .contentMargins(.horizontal, max(0, (geometry.size.width - 12) / 2), for: .scrollContent)
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $position)
                Rectangle().fill(NotebookStyle.clay).frame(width: 2, height: 26)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 64).contentShape(Rectangle())
        .onChange(of: model.weightAmount) { _, _ in
            if position != nearestTick { position = nearestTick }
        }
        .onChange(of: position) { _, tick in
            // Programmatic positioning must not round an untouched weight.
            guard let tick, tick != nearestTick else { return }
            model.setWeightAmount(min(maximum, Double(tick) * step))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weight dial in \(unit.symbol)")
        .accessibilityValue("\(model.numberInputText) \(unit.symbol)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.stepNumber(increasing: true)
            case .decrement: model.stepNumber(increasing: false)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("weight-dial")
    }

    private static func tick(for amount: Double, unit: WeightUnit) -> Int {
        let step = NSDecimalNumber(decimal: unit.step).doubleValue
        let maximum = NSDecimalNumber(decimal: unit.maximumAmount).doubleValue
        return min(Int(ceil(maximum / step)), max(0, Int((amount / step).rounded())))
    }

    private func mark(_ tick: Int) -> some View {
        let major = tick.isMultiple(of: 4) || tick == lastTick
        return VStack(spacing: 5) {
            Rectangle().fill(NotebookStyle.quiet.opacity(major ? 0.7 : 0.35))
                .frame(width: 1, height: major ? 22 : 12)
            if major {
                Text(min(maximum, Double(tick) * step), format: .number.precision(.fractionLength(0...2)))
                    .font(.system(size: 10).monospacedDigit())
                    .fixedSize().foregroundStyle(NotebookStyle.quiet)
            }
        }.frame(width: 12, height: 48, alignment: .top)
    }
}
