import SwiftUI
import SendaDomain
import SendaLogger

struct BodyChartSelection: Codable, Equatable {
    static let preferenceKey = "senda.bodyMeasurements.chartSelection"

    @MainActor static func restored(for model: TrainingNotebookModel, from data: Data) -> Self {
        var selection = (try? JSONDecoder().decode(Self.self, from: data)) ?? Self(range: model.progressRange)
        if let id = selection.exerciseID, !model.exercises.contains(where: { $0.id == id }) { selection.exerciseID = nil }
        if let dates = selection.customDays, dates.upperBound > model.today {
            selection.customDays = dates.lowerBound <= model.today ? dates.lowerBound...model.today : nil
        }
        return selection
    }

    var metric: BodyMetric = .weight
    var range: ExerciseProgressRange
    var customDays: ClosedRange<TrainingDay>?
    var exerciseID: String?
}

struct BodyMeasurementsView: View {
    let model: BodyMeasurementsModel
    let notebook: TrainingNotebookModel
    @AppStorage(BodyChartSelection.preferenceKey) private var storedBodyChart = Data()
    @State private var confirmsSharing = false

    @AppStorage("senda.bodyMeasurements.readAppleHealth") private var readsAppleHealth = false
    @AppStorage("senda.bodyMeasurements.requestedActivityAccess") private var requestedActivityAccess = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var metric: BodyMetric = .weight
    @State private var destination: BodyMeasurementsDestination?
    @State private var range: ExerciseProgressRange
    @State private var customDays: ClosedRange<TrainingDay>?
    @State private var comparisonID: String?
    @State private var saveNotice: String?

    init(model: BodyMeasurementsModel, notebook: TrainingNotebookModel, selection: BodyChartSelection) {
        self.model = model
        self.notebook = notebook
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
        LazyVStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { measurementsHeading; Spacer(minLength: 0); logButton }
                VStack(alignment: .leading, spacing: 0) { measurementsHeading; logButton }
            }
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
            if model.supportsAppleHealth {
                rule.padding(.top, 8)
                activitySection
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
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .onChange(of: BodyChartSelection(metric: metric, range: range, customDays: customDays, exerciseID: comparisonID)) { _, selection in
            if let data = try? JSONEncoder().encode(selection) { storedBodyChart = data }
        }
        .onChange(of: days) { _, _ in saveNotice = nil }
        .task { model.reloadManual() }
        .task(id: readsAppleHealth && scenePhase == .active) {
            if readsAppleHealth && scenePhase == .active {
                await model.refreshHealth()
            }
        }
        .task(id: readsAppleHealth && requestedActivityAccess && scenePhase == .active) {
            guard readsAppleHealth, requestedActivityAccess, scenePhase == .active else { return }
            while !Task.isCancelled {
                await model.refreshActivity()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .onDisappear { model.disconnectHealth() }
        .alert("Sync measurements to Apple Health?", isPresented: $confirmsSharing) {
            Button("Cancel", role: .cancel) {}
            Button("Choose measurements") { Task { await model.enableMeasurementSharing() } }
        } message: {
            Text("Senda will share saved readings for the types you allow. New readings, edits and deletions will sync too.")
        }
        .sheet(item: $destination) { sheet in
            switch sheet {
            case .activity:
                HealthActivityEditor(model: model, close: { destination = nil })
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
    }

    private var measurementsHeading: some View {
        Text("Body measurements")
            .font(NotebookTypography.heading(22, relativeTo: .title2))
            .accessibilityAddTraits(.isHeader)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { activityHeading; Spacer(minLength: 0); healthAction }
                VStack(alignment: .leading, spacing: 0) { activityHeading; healthAction }
            }
            if readsAppleHealth && requestedActivityAccess {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 32) { activityValues }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 8) { activityValues }
                }
                Button("Add activity") { destination = .activity }
                    .foregroundStyle(NotebookStyle.clay).frame(minHeight: 44)
                    .accessibilityIdentifier("body-add-activity")
                if let error = model.activityError { Text(error).font(.callout) }
            } else if readsAppleHealth {
                Button("Connect steps and active calories") { Task { await connectHealth() } }
                    .foregroundStyle(NotebookStyle.clay)
                    .frame(minHeight: 44).disabled(model.isRequestingHealthAccess)
            } else {
                Text("Connect Apple Health to see your steps and active calories.")
                    .font(.callout).foregroundStyle(NotebookStyle.quiet)
            }
        }
    }

    private var activityHeading: some View {
        Text("Today’s activity")
            .font(NotebookTypography.heading(22, relativeTo: .title2))
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var activityValues: some View {
        activityValue("Steps", model.activity.steps, suffix: "")
        activityValue("Active calories", model.activity.activeCalories, suffix: " kcal")
    }

    private func activityValue(_ title: String, _ value: Double?, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            if let value {
                Text(value.formatted(.number.precision(.fractionLength(0))) + suffix)
                    .font(.title3.weight(.semibold).monospacedDigit())
            } else {
                Text("No data").font(.body)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var logButton: some View {
        Button { saveNotice = nil; destination = .add } label: {
            Text("Log a reading")
                .font(.subheadline.weight(.semibold))
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
                    Button("Refresh") { Task {
                        await model.refreshHealth()
                        if requestedActivityAccess { await model.refreshActivity() }
                        await model.syncPendingMeasurements()
                    } }
                        .disabled(model.isRefreshingHealth)
                    Button("Review read access") { Task {
                        await connectHealth()
                    } }
                    if model.sharesMeasurements {
                        Button("Stop sharing measurements") { model.stopMeasurementSharing() }
                    } else {
                        Button("Sync measurements to Health") { confirmsSharing = true }
                    }
                    Button("Disconnect Apple Health", role: .destructive) {
                        guard model.stopMeasurementSharing() else { return }
                        readsAppleHealth = false
                        requestedActivityAccess = false
                        model.disconnectHealth()
                    }
                } label: {
                    healthActionLabel("Apple Health", showsMenu: true)
                }
                .accessibilityIdentifier("body-measurements-apple-health")
            } else {
                Button {
                    Task { await connectHealth() }
                } label: {
                    healthActionLabel("Connect Apple Health")
                }
                .disabled(model.isRequestingHealthAccess)
                .accessibilityIdentifier("body-measurements-connect-health")
            }
        }
    }

    private func connectHealth() async {
        guard await model.requestHealthAccess() else { return }
        let refreshExisting = readsAppleHealth
        let refreshActivity = requestedActivityAccess
        readsAppleHealth = true
        requestedActivityAccess = true
        if refreshExisting { await model.refreshHealth() }
        if refreshActivity { await model.refreshActivity() }
    }

    @ViewBuilder private func healthStatus(hasImportedReadings: Bool) -> some View {
        if let message = model.sharingError {
            Text(message).font(.callout).foregroundStyle(NotebookStyle.clay)
        }
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
    case add, edit(BodyMeasurement), dates, strength, activity
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
        case .activity: "activity"
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
