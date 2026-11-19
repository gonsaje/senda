import Charts
import SwiftUI
import SendaDomain
import SendaLogger

struct BodyMeasurementsView: View {
    let model: BodyMeasurementsModel
    let unit: WeightUnit
    let close: () -> Void

    @AppStorage("senda.bodyMeasurements.readAppleHealth") private var readsAppleHealth = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var metric: BodyMetric = .weight
    @State private var editor: MeasurementEditorDestination?

    var body: some View {
        let readings = model.readings(for: metric)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                actions
                if model.manualLoadFailed {
                    Text("Manual measurements couldn’t be opened.").font(.callout)
                    Button("Try again", action: model.reloadManual)
                        .foregroundStyle(NotebookStyle.clay)
                        .frame(minHeight: 44)
                }
                metricPicker
                healthStatus(hasImportedReadings: readings.contains { $0.source != .manual })
                if readings.isEmpty {
                    Text("No \(metric.title.lowercased()) readings")
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    if readings.count > 1 {
                        chart(readings)
                    }
                    Text("History")
                        .font(NotebookTypography.heading(22, relativeTo: .title2))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(readings) { reading in
                        rule
                        readingRow(reading)
                    }
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Button(action: close) {
                    Label("Trends", systemImage: "chevron.left")
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityIdentifier("close-body-measurements")
                Text("Body measurements")
                    .font(NotebookTypography.heading(31))
                    .accessibilityAddTraits(.isHeader)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 512, alignment: .leading)
            .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(NotebookStyle.ivory)
            .overlay(alignment: .bottom) { rule }
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .task { model.reloadManual() }
        .task(id: readsAppleHealth && scenePhase == .active) {
            if readsAppleHealth && scenePhase == .active {
                await model.refreshHealth()
            }
        }
        .sheet(item: $editor) { destination in
            BodyMeasurementEditor(model: model, unit: unit,
                reading: destination.reading, close: { editor = nil }) { savedMetrics in
                if !savedMetrics.contains(metric), let saved = savedMetrics.first { metric = saved }
                editor = nil
            }
        }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 440, minHeight: 540, idealHeight: 720)
        #endif
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                logButton
                Spacer(minLength: 0)
                healthAction
            }
            VStack(alignment: .leading, spacing: 0) {
                logButton
                healthAction
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var logButton: some View {
        Button { editor = .add } label: {
            Label("Log a reading", systemImage: "plus")
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.clay)
        .accessibilityIdentifier("body-measurements-add")
    }

    @ViewBuilder private var healthAction: some View {
        if model.supportsAppleHealth {
            if readsAppleHealth {
                Menu {
                    Button("Refresh readings") { Task { await model.refreshHealth() } }
                        .disabled(model.isRefreshingHealth)
                    Button("Disconnect Apple Health", role: .destructive) {
                        readsAppleHealth = false
                        model.disconnectHealth()
                    }
                } label: {
                    healthActionLabel("Apple Health", showsMenu: true)
                }
                .accessibilityIdentifier("body-measurements-apple-health")
            } else {
                Button {
                    Task {
                        if await model.requestHealthAccess() { readsAppleHealth = true }
                    }
                } label: {
                    healthActionLabel("Connect Apple Health")
                }
                .disabled(model.isRequestingHealthAccess)
                .accessibilityIdentifier("body-measurements-connect-health")
            }
        }
    }

    @ViewBuilder private func healthStatus(hasImportedReadings: Bool) -> some View {
        if let error = model.healthError {
            Text(error)
                .font(.callout).foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
        } else if model.isRefreshingHealth {
            ProgressView("Reading Apple Health…")
                .font(.callout)
        } else if readsAppleHealth && model.supportsAppleHealth && !hasImportedReadings {
            Text("No Apple Health readings for this metric. Check Senda’s access in the Health app.")
                .font(.callout).foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func healthActionLabel(_ title: String, showsMenu: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title).fixedSize(horizontal: false, vertical: true)
            if showsMenu {
                Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(NotebookStyle.clay)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }

    private var metricPicker: some View {
        Menu {
            ForEach(BodyMetric.allCases) { choice in
                Button { metric = choice } label: {
                    if metric == choice {
                        Label(choice.title, systemImage: "checkmark")
                    } else {
                        Text(choice.title)
                    }
                }
                .accessibilityAddTraits(metric == choice ? .isSelected : [])
                .accessibilityIdentifier("body-measurements-metric-\(choice.rawValue)")
            }
        } label: {
            HStack(spacing: 8) {
                Text(metric.title).font(.body.weight(.semibold))
                Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(NotebookStyle.clay)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Measurement")
        .accessibilityValue(metric.title)
        .accessibilityIdentifier("body-measurements-metric")
    }

    private func chart(_ readings: [BodyMeasurement]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if readings.count > 30 {
                Text("Latest 30 readings")
                    .font(.caption).foregroundStyle(NotebookStyle.quiet)
            }
            Chart(Array(readings.prefix(30).reversed())) { reading in
                let amount = metric.displayValue(reading.value, unit: unit)
                LineMark(x: .value("Date", reading.displayDate()), y: .value(metric.title, amount))
                PointMark(x: .value("Date", reading.displayDate()), y: .value(metric.title, amount))
            }
            .foregroundStyle(NotebookStyle.clay)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel(metric.symbol(unit: unit))
            .frame(height: 145)
            .accessibilityLabel("Recent \(metric.title.lowercased())")
        }
    }

    @ViewBuilder private func readingRow(_ reading: BodyMeasurement) -> some View {
        if reading.source == .manual {
            Button { editor = .edit(reading) } label: {
                readingLabel(reading)
                    .contentShape(Rectangle())
            }
            .accessibilityHint("Edit measurement")
            .accessibilityIdentifier("body-measurement-manual-row")
        } else {
            readingLabel(reading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("body-measurement-health-row")
        }
    }

    private func readingLabel(_ reading: BodyMeasurement) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                readingDetails(reading).fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                readingValue(reading).fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                readingDetails(reading)
                readingValue(reading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func readingDetails(_ reading: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(reading.displayDate(), format: .dateTime.month(.abbreviated).day().year())
            Text(reading.source.label)
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func readingValue(_ reading: BodyMeasurement) -> some View {
        Text(metric.formattedValue(reading.value, unit: unit))
            .font(.body.weight(.semibold).monospacedDigit())
            .fixedSize(horizontal: false, vertical: true)
    }

    private var rule: some View { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
}

private enum MeasurementEditorDestination: Identifiable {
    case add, edit(BodyMeasurement)
    var reading: BodyMeasurement? {
        if case let .edit(reading) = self { reading } else { nil }
    }
    var id: String { reading?.id.uuidString ?? "add" }
}

extension BodyMetric {
    var title: String {
        switch self {
        case .weight: "Body weight"
        case .waist: "Waist circumference"
        case .bodyFat: "Body fat"
        }
    }

    func formattedValue(_ value: Double, unit: WeightUnit) -> String {
        if self == .bodyFat {
            return (value / 100).formatted(.percent.precision(.fractionLength(0...2)))
        }
        let amount = displayValue(value, unit: unit).formatted(.number.precision(.fractionLength(0...2)))
        return "\(amount) \(symbol(unit: unit))"
    }
}

private extension BodyMeasurement.Source {
    var label: String {
        switch self {
        case .manual: "Manual"
        case .appleHealth(let name): name.isEmpty ? "Apple Health" : name
        }
    }
}
