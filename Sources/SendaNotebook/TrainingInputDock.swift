import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingInputDock: View {
    @Bindable var model: TrainingNotebookModel
    let focus: TrainingFocus
    @FocusState private var typing: Bool
    var body: some View {
        VStack(spacing: 8) {
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
            HStack(spacing: 8) {
                let index = (model.rows.firstIndex { $0.id == focus.rowID } ?? 0) + 1
                Text("\(model.exercise?.name ?? "") · Set \(index)").font(.caption).foregroundStyle(NotebookStyle.quiet)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if focus.field == .weight {
                    Button("Next") { model.selectInput(focus.rowID, field: .reps) }.frame(minWidth: 40, minHeight: 44)
                        .accessibilityIdentifier("input-next")
                }
                Button("Done") { model.finishEditing() }.font(.subheadline.weight(.medium)).frame(minWidth: 42, minHeight: 44)
                    .accessibilityIdentifier("input-done")
            }
            HStack(spacing: 16) {
                step(false)
                TextField(focus.field == .weight ? model.unit.symbol : "Reps", text: Binding(
                    get: { model.inputText(for: focus) }, set: { model.typeInput($0, focus: focus) }))
                    .font(.system(size: 31, weight: .medium).monospacedDigit()).multilineTextAlignment(.center)
                    .textFieldStyle(.plain).numericKeyboard(decimal: focus.field == .weight).focused($typing)
                    .frame(minHeight: 48)
                    .submitLabel(focus.field == .weight ? .next : .done)
                    .onSubmit {
                        if focus.field == .weight { model.selectInput(focus.rowID, field: .reps) }
                        else { model.finishEditing() }
                    }
                    .accessibilityLabel(focus.field == .weight ? "Weight in \(model.unit.symbol)" : "Reps")
                    .accessibilityIdentifier("set-input")
                step(true)
            }
            if focus.field == .weight {
                TrainingWeightRuler(value: model.focusedRow?.parsedWeight ?? model.focusedRow?.canonicalWeight ?? 0,
                                    unit: model.unit, beginInteraction: { typing = false }) {
                    model.setInputWeight($0, focus: focus)
                }
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .task { await Task.yield(); if !Task.isCancelled { typing = focus.keyboard } }
    }
    private func step(_ increasing: Bool) -> some View {
        Button { if model.stepInput(increasing: increasing, focus: focus) { typing = false } } label: {
            Image(systemName: increasing ? "plus" : "minus").font(.system(size: 22, weight: .light)).frame(width: 50, height: 48)
        }.accessibilityLabel(increasing ? "Increase value" : "Decrease value")
            .accessibilityIdentifier(increasing ? "input-increase" : "input-decrease")
    }
}

struct TrainingWeightRuler: View {
    let value: Int
    let unit: WeightUnit
    let beginInteraction: () -> Void
    var update: (Int) -> Void
    @State private var position: Int?
    @State private var start: Int?
    init(value: Int, unit: WeightUnit, beginInteraction: @escaping () -> Void, update: @escaping (Int) -> Void) {
        self.value = value; self.unit = unit; self.beginInteraction = beginInteraction; self.update = update
        _position = State(initialValue: Self.tick(value, unit))
    }
    private var step: Double { NSDecimalNumber(decimal: unit.step).doubleValue }
    private var maximum: Double { NSDecimalNumber(decimal: unit.maximumAmount).doubleValue }
    private var last: Int { Int(ceil(maximum / step)) }
    private var nearest: Int { Self.tick(value, unit) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 0) {
                        ForEach(0...last, id: \.self) { tick in
                            VStack(spacing: 4) {
                                Rectangle().fill(NotebookStyle.quiet).frame(width: 1, height: tick.isMultiple(of: 4) ? 22 : 12)
                                if tick.isMultiple(of: 4) {
                                    Text(min(maximum, Double(tick) * step), format: .number.precision(.fractionLength(0...2)))
                                        .font(.system(size: 10).monospacedDigit()).fixedSize()
                                }
                            }.frame(width: 12, height: 48, alignment: .top).id(tick)
                        }
                    }.scrollTargetLayout()
                }.contentMargins(.horizontal, max(0, (geometry.size.width - 12) / 2), for: .scrollContent)
                    .scrollIndicators(.hidden).scrollDisabled(true).scrollPosition(id: $position)
                Rectangle().fill(NotebookStyle.clay).frame(width: 2, height: 26).allowsHitTesting(false)
            }
        }
        .frame(height: 60).contentShape(Rectangle())
        .onChange(of: value) { _, _ in if position != nearest { position = nearest } }
        .gesture(DragGesture(minimumDistance: 2).onChanged { gesture in
            if start == nil { beginInteraction(); start = nearest }
            move(start ?? nearest, gesture.translation.width)
        }.onEnded { gesture in
            withAnimation(.easeOut(duration: 0.25)) { move(start ?? nearest, gesture.predictedEndTranslation.width) }
            start = nil
        })
        .accessibilityElement(children: .ignore).accessibilityLabel("Weight dial in \(unit.symbol)")
        .accessibilityValue("\(unit.text(for: value)) \(unit.symbol)")
        .accessibilityAdjustableAction { direction in
            beginInteraction()
            switch direction {
            case .increment: update(unit.stepped(value, increasing: true))
            case .decrement: update(unit.stepped(value, increasing: false))
            @unknown default: break
            }
        }.accessibilityIdentifier("weight-dial")
    }
    private func move(_ start: Int, _ translation: CGFloat) {
        let tick = Int(min(CGFloat(last), max(0, CGFloat(start) - translation / 12)).rounded())
        position = tick
        guard tick != nearest else { return }
        let amount = min(maximum, Double(tick) * step)
        if amount == maximum { update(NumericField.weight.range.upperBound) }
        else if let parsed = unit.parse(String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), amount)) { update(parsed) }
    }
    private static func tick(_ value: Int, _ unit: WeightUnit) -> Int {
        Int((NSDecimalNumber(decimal: unit.amount(for: value) / unit.step).doubleValue).rounded())
    }
}
