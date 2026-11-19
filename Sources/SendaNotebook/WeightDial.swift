import SwiftUI
import SendaLogger

struct WeightDial: View {
    @Bindable var model: LoggerModel

    var body: some View {
        WeightDialSurface(
            value: model.weightForDial,
            unit: model.selectedWeightUnit,
            accessibilityValue: "\(model.numberInputText) \(model.selectedWeightUnit.symbol)",
            adjustAccessibility: { model.stepNumber(increasing: $0) },
            beginInteraction: {},
            update: { model.setValue($0, for: .weight) }
        )
    }
}
