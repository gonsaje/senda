import SwiftUI
import SendaDomain
import SendaLogger

private struct ProgressHistoryEntry: Identifiable {
    let id: UUID
    var stages: [ExerciseProgressSet]
    var isDropSet: Bool { stages.first?.dropGroupID != nil }
}

/// A read-only view of performed exercise history. Browsing never opens a workout.
public struct TrainingProgressView: View {
    @Bindable private var model: TrainingNotebookModel
    private let close: () -> Void
    @State private var query = ""
    @State private var selectedSessionDay: TrainingDay?

    public init(model: TrainingNotebookModel, initialSessionDay: TrainingDay? = nil, close: @escaping () -> Void) {
        self.model = model
        self.close = close
        _selectedSessionDay = State(initialValue: initialSessionDay ?? model.progressSessionDay)
    }

    public var body: some View {
        ScrollViewReader { scroll in
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if let id = model.progressExerciseID {
                    let exercise = model.exercise(id)
                    let progress = model.snapshot.progress(for: exercise, range: model.progressRange,
                        through: model.today, calendar: model.calendar)
                    let recorded = model.snapshot.recordedSessions(for: exercise, calendar: model.calendar)
                    if let day = selectedSessionDay,
                       let session = recorded.first(where: { $0.day == day }) {
                        sessionDetail(session, exercise: exercise)
                    } else {
                        exerciseDetail(exercise, progress: progress, recorded: recorded)
                    }
                } else {
                    exerciseCatalog
                }
                returnToWorkout
            }
            .padding(24)
            .padding(.bottom, 12)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("progress-scroll")
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.never)
        .safeAreaInset(edge: .top, spacing: 0) {
            navigation
                .padding(.horizontal, 24).padding(.vertical, 4)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
                .background(NotebookStyle.ivory)
                .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let message = model.errorMessage {
                TrainingSaveError(model: model, message: message)
                    .padding(.horizontal, 24).padding(.vertical, 8)
                    .background(NotebookStyle.ivory)
            }
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .id("\(model.progressExerciseID ?? "catalog")/\(selectedSessionDay?.rawValue ?? "exercise")")
        .task(id: selectedSessionDay) {
            guard selectedSessionDay != nil, let id = model.progressSetID else { return }
            await Task.yield()
            scroll.scrollTo("history-set-\(id.uuidString)", anchor: .center)
        }
        }
    }

    private var navigation: some View {
        HStack(alignment: .center, spacing: 16) {
            if model.progressExerciseID != nil {
                Button {
                    model.cancelProgressNavigation()
                    if selectedSessionDay != nil { selectedSessionDay = nil }
                    else { model.progressExerciseID = nil }
                } label: {
                    Label(selectedSessionDay == nil ? "Exercises" : "Exercise history", systemImage: "chevron.left")
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("progress-back")
            } else {
                Text("History")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(action: close) {
                Text("Done").font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
                .accessibilityLabel("Close progress")
                .accessibilityIdentifier("progress-close")
        }
    }

    private var catalogExercises: [Exercise] {
        var ids = Set(model.journal.batches.map(\.exerciseID))
        if let id = model.progressExerciseID { ids.insert(id) }
        return ids.map { model.exercise($0) }.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    private var exerciseCatalog: some View {
        let exercises = catalogExercises
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let results = search.isEmpty ? exercises : exercises.filter { $0.name.localizedStandardContains(search) }
        return VStack(alignment: .leading, spacing: 20) {
            Text("Exercise history").font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            if exercises.isEmpty {
                emptyState(title: "No recorded sets",
                    message: "Record your first set in a workout. Your exercise history will appear here, with daily top sets and weekly training days.")
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
                    TextField("Find an exercise", text: $query)
                        .textFieldStyle(.plain).autocorrectionDisabled().submitLabel(.search)
                        .accessibilityIdentifier("progress-search")
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                        }
                        .foregroundStyle(NotebookStyle.quiet)
                        .accessibilityLabel("Clear exercise search")
                    }
                }
                .padding(.leading, 14).padding(.trailing, query.isEmpty ? 14 : 2)
                .frame(minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(NotebookStyle.rule, lineWidth: 1))
                if results.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No matching exercise").font(NotebookTypography.heading(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                        Text("Try another name. Only exercises with recorded sets appear in this list.")
                            .foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
                        Button("Clear search") { query = "" }.frame(minHeight: 44)
                    }.padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(results) { exercise in
                            Button {
                                model.cancelProgressNavigation()
                                selectedSessionDay = nil
                                model.progressExerciseID = exercise.id
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(exercise.name).font(.body.weight(.semibold))
                                        Text("\(exercise.group.rawValue) · \(exercise.equipmentType.rawValue)")
                                            .font(.caption).foregroundStyle(NotebookStyle.quiet)
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                        .foregroundStyle(NotebookStyle.clay).accessibilityHidden(true)
                                }
                                .frame(minHeight: 68).padding(.vertical, 5).contentShape(Rectangle())
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityHint("Show exercise progress")
                            .accessibilityIdentifier("progress-exercise-\(exercise.id)")
                            progressRule
                        }
                    }
                }
            }
        }
    }

    private func exerciseDetail(_ exercise: Exercise, progress: ExerciseProgress, recorded: [ExerciseProgressSession]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                Text(exercise.name).font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(exercise.group.rawValue) · \(exercise.equipmentType.rawValue)")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                ProgressRangeControl(selection: Binding(get: { model.progressRange }, set: {
                    model.cancelProgressNavigation(); model.progressRange = $0
                }), identifierPrefix: "progress-range")
                Text(ProgressFormatting.dateRange(from: progress.startDay, through: progress.endDay, calendar: model.calendar))
                    .font(.caption).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let latest = progress.latestSession, let best = progress.bestSet {
                ProgressSummary(latest: latest, best: best, progress: progress,
                    exercise: exercise, unit: model.workspace.preferredUnit, calendar: model.calendar)
                Text("\(progress.trainingDayCount) training \(progress.trainingDayCount == 1 ? "day" : "days") · \(progress.setCount) \(progress.setCount == 1 ? "set" : "sets")")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
                ExerciseProgressChart(progress: progress, exercise: exercise,
                    unit: model.workspace.preferredUnit, calendar: model.calendar)
                ExerciseProgressFrequencyChart(progress: progress, calendar: model.calendar)
            } else {
                emptyState(title: "No sets in this window.",
                    message: recorded.isEmpty ? "Record a set for \(exercise.name) to see it here." : "Recorded days below include all saved dates.")
            }
            if !recorded.isEmpty { sessions(recorded, exercise: exercise) }
        }
    }

    private func sessions(_ recorded: [ExerciseProgressSession], exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recorded days").font(NotebookTypography.heading(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            Text("All saved dates · newest first")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
            LazyVStack(spacing: 0) {
                progressRule
                ForEach(recorded.reversed()) { session in
                    Button { model.cancelProgressNavigation(); selectedSessionDay = session.day } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 12) {
                                Text(date(session.day, format: "EEE, MMM d, yyyy")).font(.body.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                    .foregroundStyle(NotebookStyle.clay).accessibilityHidden(true)
                            }
                            Text("Top set · \(ProgressFormatting.set(session.bestSet.values, exercise: exercise, unit: model.workspace.preferredUnit))")
                                .font(.body.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
                            Text(sessionCountText(session))
                                .font(.caption).foregroundStyle(NotebookStyle.quiet)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .padding(.vertical, 14).contentShape(Rectangle())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Show all sets recorded on this day")
                    .accessibilityIdentifier("progress-session-\(session.day.rawValue)")
                    progressRule
                }
            }
        }
    }

    private func sessionDetail(_ session: ExerciseProgressSession, exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(exercise.name).font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                Text(date(session.day, format: "EEEE, MMMM d, yyyy")).font(.title3)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(sessionCountText(session)) · Read-only history")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                let selected = session.sets.first { $0.id == model.progressSetID }?.id
                model.editRecordedSession(for: exercise.id, on: session.day, setID: selected)
            } label: {
                Text("Edit this workout").font(.body.weight(.medium))
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityHint("Open this saved workout for editing, with a way back to your current workout")
            .accessibilityIdentifier("progress-edit-workout")
            VStack(alignment: .leading, spacing: 0) {
                progressRule
                ForEach(Array(historyEntries(session).enumerated()), id: \.element.id) { index, entry in
                    VStack(alignment: .leading, spacing: 12) {
                        if entry.isDropSet {
                            Text("Set \(index + 1) · Drop set · \(entry.stages.count) \(entry.stages.count == 1 ? "stage" : "stages")")
                                .font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        }
                        ForEach(entry.stages) { stage in
                            historyStage(stage, isDropSet: entry.isDropSet, setIndex: index + 1, day: session.day, exercise: exercise)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16)
                    progressRule
                }
            }
            Text("These are the saved values for this day. Your current workout stays where you left it.")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func historyStage(_ set: ExerciseProgressSet, isDropSet: Bool, setIndex: Int, day: TrainingDay, exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.progressSetID == set.id {
                Label("Selected set", systemImage: "checkmark")
                    .font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.clay)
            }
            if isDropSet {
                Text(dropStageLabel(set.id, day: day, exerciseID: exercise.id))
                    .font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.quiet)
            }
            Text(ProgressFormatting.set(set.values, exercise: exercise, unit: model.workspace.preferredUnit))
                .font(.title3.weight(.medium).monospacedDigit()).fixedSize(horizontal: false, vertical: true)
            Text("\(isDropSet ? "" : "Set \(setIndex) · ")Saved \(time(set.recordedAt))")
                .font(.caption).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
            Text(recordedDetails(setID: set.id, day: day, exerciseID: exercise.id))
                .font(.caption).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("progress-set-details-\(set.id.uuidString)")
        }.accessibilityElement(children: .combine)
            .accessibilityAddTraits(model.progressSetID == set.id ? .isSelected : [])
            .id("history-set-\(set.id.uuidString)")
            .accessibilityIdentifier("progress-recorded-set-\(set.id.uuidString)")
    }

    private func historyEntries(_ session: ExerciseProgressSession) -> [ProgressHistoryEntry] {
        var entries: [ProgressHistoryEntry] = []
        for stage in session.sets {
            let id = stage.dropGroupID ?? stage.id
            if let index = entries.firstIndex(where: { $0.id == id }) { entries[index].stages.append(stage) }
            else { entries.append(ProgressHistoryEntry(id: id, stages: [stage])) }
        }
        return entries
    }

    private func sessionCountText(_ session: ExerciseProgressSession) -> String {
        let stages = session.sets.filter { $0.dropGroupID != nil }.count
        let sets = "\(session.setCount) \(session.setCount == 1 ? "set" : "sets")"
        return stages > 0 ? "\(sets) · \(stages) drop \(stages == 1 ? "stage" : "stages")" : sets
    }

    private func dropStageLabel(_ setID: UUID, day: TrainingDay, exerciseID: String) -> String {
        let rows = model.workspace.days[day.rawValue]?.rows[exerciseID] ?? []
        guard let row = rows.first(where: { $0.performedSetID == setID }), let group = row.dropGroupID else { return "Stage" }
        let stages = rows.filter { $0.dropGroupID == group }
        guard let index = stages.firstIndex(where: { $0.id == row.id }) else { return "Stage" }
        return index == 0 ? "Start" : "Drop \(index)"
    }

    private var returnToWorkout: some View {
        VStack(alignment: .leading, spacing: 12) {
            progressRule
            Button { model.returnFromProgressToWorkout() } label: {
                Label("Return to workout", systemImage: "arrow.uturn.backward")
                    .font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).contentShape(Rectangle())
            }
            .accessibilityIdentifier("progress-return-workout")
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(NotebookTypography.heading(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            Text(message).font(.body).foregroundStyle(NotebookStyle.ink.opacity(0.75)).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private var progressRule: some View { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true) }
    private func recordedDetails(setID: UUID, day: TrainingDay, exerciseID: String) -> String {
        let row = model.workspace.days[day.rawValue]?.rows[exerciseID]?.first { $0.performedSetID == setID }
        let reserve = row?.repsInReserve.map { TrainingSetDetailsText.reserve($0) } ?? "Reps left not set"
        let kind = row?.kind.map { TrainingSetDetailsText.kind($0) } ?? "Set type not set"
        return "\(kind) · \(reserve)"
    }
    private func date(_ day: TrainingDay, format: String) -> String {
        ProgressFormatting.date(day, format: format, calendar: model.calendar)
    }
    private func time(_ recordedAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = model.calendar
        formatter.timeZone = model.calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: recordedAt)
    }
}

private struct ProgressSummary: View {
    let latest: ExerciseProgressSession
    let best: ExerciseProgressSet
    let progress: ExerciseProgress
    let exercise: Exercise
    let unit: WeightUnit
    let calendar: Calendar
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Group {
            if textSize >= .xxxLarge {
                VStack(alignment: .leading, spacing: 14) { latestResult; bestResult }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        latestResult.fixedSize(horizontal: true, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        bestResult.fixedSize(horizontal: true, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 14) { latestResult; bestResult }
                }
            }
        }
    }
    private var latestResult: some View {
        result("Latest top set", set: latest.bestSet,
            caption: ProgressFormatting.date(latest.day, format: "MMM d, yyyy", calendar: calendar))
    }
    private var bestResult: some View {
        let day = progress.sessions.first { $0.sets.contains { $0.id == best.id } }?.day
        return result("Period best", set: best,
            caption: day.map { ProgressFormatting.date($0, format: "MMM d, yyyy", calendar: calendar) } ?? "In this window")
    }
    private func result(_ title: String, set: ExerciseProgressSet, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(NotebookStyle.ink.opacity(0.75))
            Text(ProgressFormatting.set(set.values, exercise: exercise, unit: unit))
                .font(.title3.weight(.semibold).monospacedDigit()).fixedSize(horizontal: false, vertical: true)
            Text(caption).font(.caption).foregroundStyle(NotebookStyle.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

enum ProgressFormatting {
    static func dateRange(from startDay: TrainingDay, through endDay: TrainingDay, calendar: Calendar) -> String {
        let startYear = calendar.component(.year, from: startDay.date(in: calendar))
        let endYear = calendar.component(.year, from: endDay.date(in: calendar))
        let startFormat = startYear == endYear ? "MMM d" : "MMM d, yyyy"
        return "\(date(startDay, format: startFormat, calendar: calendar)) – \(date(endDay, format: "MMM d, yyyy", calendar: calendar))"
    }

    static func date(_ day: TrainingDay, format: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: day.date(in: calendar))
    }
    static func set(_ values: SetValues, exercise: Exercise, unit: WeightUnit) -> String {
        if !exercise.requiresWeight {
            return values.weight == 0 ? "BW × \(values.reps)" : "BW + \(unit.text(for: values.weight)) \(unit.symbol) × \(values.reps)"
        }
        return "\(unit.text(for: values.weight)) \(unit.symbol) × \(values.reps)"
    }
}
