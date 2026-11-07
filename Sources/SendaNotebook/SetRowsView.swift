import SwiftUI
import SendaDomain
import SendaLogger

struct SetRowsView: View {
    @Bindable var model: LoggerModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Set").frame(width: 20, alignment: .leading)
                Text("Weight").frame(maxWidth: .infinity, alignment: .leading)
                Text("Reps").frame(width: 50)
                Color.clear.frame(width: 44, height: 1)
            }.font(.caption).foregroundStyle(NotebookStyle.quiet).padding(.bottom, 5)
            ForEach(Array(model.values.indices), id: \.self) { index in
                HStack(spacing: 8) {
                    Text("\(index + 1)").font(.system(.caption, design: .monospaced))
                        .foregroundStyle(NotebookStyle.quiet).frame(width: 20, alignment: .leading)
                    weight(index, unit: .pounds)
                    weight(index, unit: .kilograms)
                    Button { model.selectSet(index, field: .reps) } label: {
                        Text(String(model.values[index].reps)).font(.system(size: 25).monospacedDigit())
                            .frame(width: 50, height: 56)
                            .overlay(alignment: .bottom) { rule(active: active(index, field: .reps)) }
                    }
                    .foregroundStyle(active(index, field: .reps) ? NotebookStyle.clay : NotebookStyle.ink)
                    .accessibilityLabel("Set \(index + 1), \(model.values[index].reps) reps")
                    .accessibilityIdentifier("row-\(index + 1)-reps")
                    Button { model.removeSet(at: index) } label: {
                        Image(systemName: "minus.circle").font(.system(size: 17, weight: .light)).frame(width: 44, height: 44)
                    }.foregroundStyle(NotebookStyle.quiet)
                        .disabled(model.values.count == 1).opacity(model.values.count == 1 ? 0.25 : 0.7)
                        .accessibilityLabel("Remove set \(index + 1)").accessibilityIdentifier("remove-set-\(index + 1)")
                }.id("set-row-\(index)")
                Rectangle().fill(NotebookStyle.rule.opacity(0.7)).frame(height: 1)
            }
            HStack {
                Button { model.addSet() } label: {
                    Label("Add set", systemImage: "plus").font(.subheadline).frame(minHeight: 44)
                }.disabled(model.values.count >= 30).accessibilityIdentifier("add-set")
                Spacer()
            }.foregroundStyle(NotebookStyle.clay).padding(.top, 5)
        }
    }
    private func weight(_ index: Int, unit: WeightUnit) -> some View {
        let text = unit.text(for: model.values[index].weight)
        let selected = active(index, field: .weight) && model.selectedWeightUnit == unit
        return Button { model.selectSet(index, field: .weight, unit: unit) } label: {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(text).font(.system(size: 24).monospacedDigit())
                    Text(unit.symbol).font(.system(size: 11))
                }.fixedSize()
                VStack(alignment: .leading, spacing: 1) {
                    Text(text).font(.system(size: 22).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.5)
                    Text(unit.symbol).font(.system(size: 11))
                }
            }
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .overlay(alignment: .bottom) { rule(active: selected) }
        }
        .foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.ink)
        .accessibilityLabel("Set \(index + 1), \(text) \(unit.symbol)")
        .accessibilityIdentifier("row-\(index + 1)-\(unit.symbol)")
    }
    private func active(_ index: Int, field: NumericField) -> Bool {
        model.showsNumberEditor && model.selectedSetIndex == index && model.selectedField == field
    }
    private func rule(active: Bool) -> some View {
        Rectangle().fill(active ? NotebookStyle.clay : .clear).frame(height: 2)
    }
}
