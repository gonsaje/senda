import SwiftUI
import SendaDomain
import SendaLogger

struct BodyChartSelection: Codable, Equatable {
    var metric: BodyMetric = .weight
    var range: ExerciseProgressRange
    var customDays: ClosedRange<TrainingDay>?
    var exerciseID: String?
}

struct BodyMeasurementsView: View {
    let model: BodyMeasurementsModel
    let notebook: TrainingNotebookModel
    let close: () -> Void
    let remember: (BodyChartSelection) -> Void

    @AppStorage("senda.bodyMeasurements.readAppleHealth") private var readsAppleHealth = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var metric: BodyMetric = .weight
    @State private var destination: BodyMeasurementsDestination?
    @State private var range: ExerciseProgressRange
    @State private var customDays: ClosedRange<TrainingDay>?
    @State private var comparisonID: String?
    @State private var saveNotice: String?

    init(model: BodyMeasurementsModel, notebook: TrainingNotebookModel, selection: BodyChartSelection,
         remember: @escaping (BodyChartSelection) -> Void, close: @escaping () -> Void) {
        self.model = model
        self.notebook = notebook
        self.close = close
        self.remember = remember
        _range = State(initialValue: selection.range)
        _metric = State(initialValue: selection.metric)
        _customDays = State(initialValue: selection.customDays)
        _comparisonID = State(initialValue: selection.exerciseID)
    }

    private var unit: WeightUnit { notebook.workspace.preferredUnit }
    private var days: ClosedRange<TrainingDay> { customDays ?? range.days(through: notebook.today) }
    private var calendar: Calendar { notebook.calendar }

    var body: some View {
        let period = model.period(for: metric, in: days, calendar: calendar)
        let readings = period.readings
        let exercise = comparisonID.map { notebook.exercise($0) }
        let progress = exercise.map { notebook.snapshot.progress(for: $0, in: days, calendar: calendar) }
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
                intervalPicker
                if let saveNotice {
                    Text(saveNotice).font(.callout).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
                comparisonButton(exercise)
                healthStatus(hasImportedReadings: model.hasHealthReadings(for: metric))
                if readings.isEmpty && period.precedingWeight == nil {
                    Text(model.hasReadings(for: metric)
                         ? "No \(metric.title.lowercased()) readings in this period."
                         : "No \(metric.title.lowercased()) readings")
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !readings.isEmpty || period.precedingWeight != nil || progress?.sessions.isEmpty == false {
                    BodyMeasurementTrendChart(metric: metric, readings: readings, precedingWeight: period.precedingWeight, days: days,
                        comparison: progress, exercise: exercise, unit: unit, calendar: calendar)
                }
                if let exercise, progress?.sessions.isEmpty == true {
                    Text("No recorded sets for \(exercise.displayName) in this period.")
                        .font(.callout).foregroundStyle(NotebookStyle.quiet)
                }
                if !readings.isEmpty {
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
        .onChange(of: BodyChartSelection(metric: metric, range: range, customDays: customDays, exerciseID: comparisonID)) { _, selection in
            remember(selection)
        }
        .onChange(of: days) { _, _ in saveNotice = nil }
        .task { model.reloadManual() }
        .task(id: readsAppleHealth && scenePhase == .active) {
            if readsAppleHealth && scenePhase == .active {
                await model.refreshHealth()
            }
        }
        .sheet(item: $destination) { sheet in
            switch sheet {
            case .add, .edit:
                BodyMeasurementEditor(model: model, unit: unit,
                    reading: sheet.reading, close: { destination = nil }) { savedMetrics, date in
                    if !savedMetrics.contains(metric), let saved = savedMetrics.first { metric = saved }
                    let day = TrainingDay(date, calendar: calendar)
                    if days.contains(day) {
                        saveNotice = nil
                    } else {
                        let label = ProgressFormatting.date(day, format: "MMM d, yyyy", calendar: calendar)
                        let message = "Saved for \(label), outside this date range."
                        saveNotice = message
                        TrainingAccessibility.announce(message)
                    }
                    destination = nil
                }
            case .dates:
                MeasurementDatePicker(days: days, today: notebook.today, calendar: calendar,
                    cancel: { destination = nil },
                    apply: { customDays = $0; destination = nil })
            case .strength:
                ExerciseChoiceSheet(title: "Compare strength", groups: [.init(title: "", exercises: comparisonChoices)],
                    selectedID: comparisonID, identifierPrefix: "body-compare-", emptyMessage: "Log a set or track an exercise to compare strength.",
                    clearTitle: "No comparison", select: { comparisonID = $0; destination = nil }, close: { destination = nil })
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
        Button { saveNotice = nil; destination = .add } label: {
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
                Button { metric = choice; saveNotice = nil } label: {
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

    private var intervalPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProgressRangeControl(selection: Binding(get: { range }, set: { range = $0; customDays = nil }),
                identifierPrefix: "body-measurements-range", showsSelection: customDays == nil)
            Button { destination = .dates } label: {
                ViewThatFits(in: .horizontal) {
                    HStack { dateSpan; Spacer(minLength: 8); customLabel }
                    VStack(alignment: .leading, spacing: 4) { dateSpan; customLabel }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Custom dates")
            .accessibilityValue(formattedDateSpan)
            .accessibilityAddTraits(customDays == nil ? [] : .isSelected)
            .accessibilityIdentifier("body-measurements-custom-range")
        }
    }

    private var formattedDateSpan: String {
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: days.lowerBound.date(in: calendar), to: days.upperBound.date(in: calendar))
    }

    private var dateSpan: some View {
        Text(formattedDateSpan).font(.caption).foregroundStyle(NotebookStyle.quiet)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var customLabel: some View {
        Label("Custom dates", systemImage: "calendar").font(.subheadline.weight(.medium))
            .foregroundStyle(NotebookStyle.clay).fixedSize(horizontal: true, vertical: false)
    }

    private var comparisonChoices: [Exercise] {
        var eligible = Set(notebook.journal.batches.map(\.exerciseID))
        eligible.formUnion(notebook.trackedStrengthExerciseIDs)
        if let comparisonID { eligible.insert(comparisonID) }
        return notebook.exercises.filter { eligible.contains($0.id) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private func comparisonButton(_ exercise: Exercise?) -> some View {
        Button { destination = .strength } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                Text(exercise.map { "Compare with \($0.displayName)" } ?? "Compare strength")
                    .font(.body.weight(.medium)).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption)
            }
            .foregroundStyle(NotebookStyle.clay)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Compare strength")
        .accessibilityValue(exercise?.displayName ?? "Off")
        .accessibilityIdentifier("body-compare-strength")
    }

    @ViewBuilder private func readingRow(_ reading: BodyMeasurement) -> some View {
        if reading.source == .manual {
            Button { saveNotice = nil; destination = .edit(reading) } label: {
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
            Text(reading.displayDate(in: calendar), format: .dateTime.month(.abbreviated).day().year())
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

private enum BodyMeasurementsDestination: Identifiable {
    case add, edit(BodyMeasurement), dates, strength
    var reading: BodyMeasurement? {
        if case .edit(let reading) = self { return reading }
        return nil
    }
    var id: String {
        switch self {
        case .add: "add"
        case .edit(let reading): reading.id.uuidString
        case .dates: "dates"
        case .strength: "strength"
        }
    }
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
