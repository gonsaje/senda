import SwiftUI
import SendaDomain
import SendaLogger

struct BodyMeasurementEditor: View {
    let model: BodyMeasurementsModel
    let unit: WeightUnit
    let reading: BodyMeasurement?
    let close: () -> Void
    let saved: ([BodyMetric]) -> Void

    @Environment(\.dynamicTypeSize) private var textSize
    @State private var date: Date
    @State private var inputs: [BodyMetric: String]
    @State private var error: String?
    @State private var confirmsDelete = false

    private let originalValueText: String?

    init(model: BodyMeasurementsModel, unit: WeightUnit, reading: BodyMeasurement?, close: @escaping () -> Void,
         saved: @escaping ([BodyMetric]) -> Void) {
        self.model = model
        self.unit = unit
        self.reading = reading
        self.close = close
        self.saved = saved
        let initial = reading.map {
            $0.metric.displayValue($0.value, unit: unit)
                .formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
        }
        originalValueText = initial
        _date = State(initialValue: reading?.displayDate() ?? .now)
        _inputs = State(initialValue: reading.flatMap { reading in initial.map { [reading.metric: $0] } } ?? [:])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(reading == nil ? "New reading" : "Edit reading")
                    .font(NotebookTypography.heading(31))
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                dateField
                ForEach(reading.map { [$0.metric] } ?? BodyMetric.allCases) { metric in
                    field(metric)
                }
                if let error {
                    Text(error)
                        .font(.callout).foregroundStyle(NotebookStyle.clay)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("body-measurements-save-error")
                }
                if reading != nil {
                    Button("Delete measurement", role: .destructive) { confirmsDelete = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("body-measurement-delete")
                }
            }
            .padding(24)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 16) {
                Button("Cancel", action: close)
                    .frame(minWidth: 44, minHeight: 44)
                Spacer()
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("body-measurements-save")
            }
            .foregroundStyle(NotebookStyle.clay)
            .padding(.horizontal, 24).padding(.vertical, 6)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(NotebookStyle.ivory)
            .overlay(alignment: .bottom) { rule }
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .confirmationDialog("Delete this measurement?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete measurement", role: .destructive, action: remove)
        }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 440, minHeight: 520)
        #endif
    }

    @ViewBuilder private var dateField: some View {
        let picker = DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
            .frame(minHeight: 44)
            .accessibilityIdentifier("body-measurement-date")
        if textSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text("Date").font(.body.weight(.medium)).accessibilityHidden(true)
                picker.labelsHidden().dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
        } else {
            picker
        }
    }

    private func field(_ metric: BodyMetric) -> some View {
        let label = "\(metric.title) (\(metric.symbol(unit: unit)))"
        return VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            TextField(metric.symbol(unit: unit), text: Binding(
                get: { inputs[metric] ?? "" },
                set: { inputs[metric] = $0; error = nil }
            ))
            .textFieldStyle(.plain)
            .numericKeyboard(decimal: true)
            .font(.title3.monospacedDigit())
            .frame(minHeight: 44)
            .accessibilityLabel(label)
            .accessibilityIdentifier("body-measurement-input-\(metric.rawValue)")
            rule
        }
    }

    private var rule: some View { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }

    private func save() {
        do {
            if let reading {
                let text = inputs[reading.metric] ?? ""
                let value = text == originalValueText ? reading.value : try parse(text, for: reading.metric)
                let savedDate = TrainingDay(date) == TrainingDay(reading.date) ? reading.date : date
                try model.update(reading, value: value, on: savedDate)
                saved([reading.metric])
            } else {
                var values: [BodyMetric: Double] = [:]
                for metric in BodyMetric.allCases {
                    let text = inputs[metric, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { values[metric] = try parse(text, for: metric) }
                }
                try model.add(values, on: date)
                saved(BodyMetric.allCases.filter { values[$0] != nil })
            }
        } catch { showError(error) }
    }

    private func parse(_ text: String, for metric: BodyMetric) throws -> Double {
        if let value = metric.canonicalValue(from: text, unit: unit) { return value }
        throw InputError.invalid(metric.title.lowercased())
    }

    private func remove() {
        guard let reading else { return }
        do {
            try model.remove(reading)
            saved([reading.metric])
        } catch { showError(error) }
    }

    private func showError(_ error: any Error) {
        self.error = (error as? any LocalizedError)?.errorDescription ?? "Couldn’t save your measurement. Try again."
    }

    private enum InputError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let metric): "Enter a valid value for \(metric)." }
        }
    }
}
