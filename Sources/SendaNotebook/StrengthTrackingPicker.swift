import SwiftUI
import SendaDomain
import SendaLogger

struct StrengthTrackingPicker: View {
    let model: TrainingNotebookModel
    let close: () -> Void

    private enum Tab: String, CaseIterable {
        case exercises = "Exercises", workouts = "Workouts"
    }

    private struct WorkoutChoice: Identifiable {
        enum Source: String, CaseIterable {
            case saved = "My templates", starters = "Starters", recent = "Logged workouts"
        }

        let id: String
        let title: String
        let ids: [String]
        let source: Source
    }

    @Environment(\.dynamicTypeSize) private var textSize
    @State private var tab = Tab.exercises
    @State private var query = ""
    @State private var selection: [String]
    @State private var saveFailed = false

    private let exercises: [Exercise]
    private let names: [String: String]
    private let logged: Set<String>
    private let templates: [WorkoutChoice]
    @State private var recentWorkouts: [WorkoutChoice]?

    init(model: TrainingNotebookModel, close: @escaping () -> Void) {
        self.model = model
        self.close = close
        let tracked = model.trackedStrengthExerciseIDs
        _selection = State(initialValue: tracked)
        let logged = Set(model.journal.batches.map(\.exerciseID))
        self.logged = logged
        let starters = model.starterWorkouts
        let saved = model.savedWorkouts
        let referenced = logged.union(tracked).union((starters + saved).flatMap(\.exerciseIDs))
        let catalog = model.exercises
        let catalogIDs = Set(catalog.map(\.id))
        let choices = catalog.filter { (!$0.isArchived && $0.isLibraryChoice) || referenced.contains($0.id) }
            + referenced.subtracting(catalogIDs).map { model.exercise($0) }
        exercises = choices.sorted {
            let order = $0.displayName.localizedStandardCompare($1.displayName)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
        names = Dictionary(uniqueKeysWithValues: choices.map { ($0.id, $0.displayName) })

        templates = saved.map { WorkoutChoice(id: $0.id, title: $0.name, ids: $0.exerciseIDs, source: .saved) }
            + starters.map { WorkoutChoice(id: $0.id, title: $0.name, ids: $0.exerciseIDs, source: .starters) }
    }

    private func loadRecentWorkouts() -> [WorkoutChoice] {
        guard let tomorrow = try? model.today.adding(days: 1) else { return [] }
        let formatter = DateFormatter()
        formatter.calendar = model.calendar
        formatter.timeZone = model.calendar.timeZone
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return model.reusableWorkouts(before: tomorrow).map { workout in
            WorkoutChoice(id: workout.day.rawValue, title: formatter.string(from: workout.day.date(in: model.calendar)),
                ids: workout.exerciseIDs, source: .recent)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    if saveFailed && model.canRetrySave && !model.cancelPendingAction() { return }
                    close()
                }
                .accessibilityIdentifier("trends-track-cancel")
                Spacer()
                Button(saveFailed ? "Retry" : "Done") {
                    let saved = saveFailed && model.canRetrySave
                        ? model.retrySave() : model.setTrackedStrengthExercises(selection)
                    if saved { close() }
                    else { saveFailed = true }
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("trends-track-done")
            }
            .buttonStyle(TrackingActionStyle())
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text("Track strength")
                        .font(NotebookTypography.heading(28))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 12)
                    LibrarySegments(stacked: textSize.isAccessibilitySize) {
                        ForEach(Tab.allCases, id: \.self) { item in
                            Button {
                                if item == .workouts, recentWorkouts == nil { recentWorkouts = loadRecentWorkouts() }
                                tab = item
                                query = ""
                            } label: {
                                LibrarySegmentLabel(title: item.rawValue, selected: tab == item, expands: true)
                            }
                            .accessibilityAddTraits(tab == item ? .isSelected : [])
                            .accessibilityIdentifier("trends-track-\(item.rawValue.lowercased())-tab")
                        }
                    }
                    .padding(.bottom, 8)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
                        TextField(tab == .exercises ? "Find an exercise" : "Find a workout", text: $query)
                            .textFieldStyle(.plain).autocorrectionDisabled().submitLabel(.search)
                            .accessibilityIdentifier("trends-track-search")
                    }
                    .frame(minHeight: 44)
                    Divider()
                    choices
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(saveFailed && model.canRetrySave)
            if saveFailed, let error = model.errorMessage {
                Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                    .padding(.horizontal, 24).padding(.vertical, 8)
            }
        }
        .frame(maxWidth: 608)
        .frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        .interactiveDismissDisabled(selection != model.trackedStrengthExerciseIDs || saveFailed)
    }

    @ViewBuilder
    private var choices: some View {
        let key = ExerciseLibrary.matchingKey(query)
        let selected = Set(selection)
        if tab == .exercises {
            if key.isEmpty {
                let recorded = exercises.filter { logged.contains($0.id) }
                let library = exercises.filter { !logged.contains($0.id) }
                bulkActions(ids: (recorded + library).map(\.id), selected: selected)
                exerciseRows("Logged exercises", recorded, selected: selected)
                exerciseRows("Exercise library", library, selected: selected)
            } else {
                let matches = ExerciseSelectionFilter.rankedMatches(exercises.filter { $0.matchesExerciseName(key: key) }, query: query)
                bulkActions(ids: matches.map(\.id), selected: selected)
                if matches.isEmpty { emptyResults }
                exerciseRows("Search results", matches, selected: selected)
            }
        } else {
            let workouts = templates + (recentWorkouts ?? [])
            let matches = key.isEmpty ? workouts : workouts.filter { choice in
                ExerciseLibrary.matchingKey(choice.title).contains(key) || choice.ids.contains {
                    ExerciseLibrary.matchingKey(names[$0] ?? $0).contains(key)
                }
            }
            bulkActions(ids: matches.flatMap(\.ids), selected: selected)
            if matches.isEmpty { emptyResults }
            ForEach(WorkoutChoice.Source.allCases, id: \.self) { source in
                let group = matches.filter { $0.source == source }
                if !group.isEmpty {
                    sectionTitle(source.rawValue)
                    ForEach(group) { workout in
                        let included = workout.ids.allSatisfy(selected.contains)
                        Button { add(workout.ids) } label: {
                            choiceLabel(workout.title, detail: workout.ids.map { names[$0] ?? $0 }.joined(separator: ", "),
                                symbol: included ? "checkmark.circle.fill" : "plus.circle", selected: included)
                        }
                        .disabled(included)
                        .accessibilityValue(included ? "All exercises selected" : "Add exercises")
                        .accessibilityIdentifier("trends-track-workout-\(workout.id)")
                        Divider()
                    }
                }
            }
        }
    }

    private var emptyResults: some View {
        Text(tab == .exercises ? "No matching exercises" : "No matching workouts")
            .foregroundStyle(NotebookStyle.quiet).padding(.vertical, 16)
    }

    private func bulkActions(ids: [String], selected: Set<String>) -> some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            Text("\(selection.count) \(selection.count == 1 ? "exercise" : "exercises") selected")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                .accessibilityIdentifier("trends-track-count")
            if !textSize.isAccessibilitySize { Spacer(minLength: 0) }
            if !selection.isEmpty {
                Button("Clear all") { selection.removeAll() }
                    .accessibilityLabel("Clear all selected exercises")
                    .accessibilityIdentifier("trends-track-clear")
            }
            Button(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add all" : "Add matches") { add(ids) }
                .disabled(ids.allSatisfy(selected.contains))
                .accessibilityIdentifier("trends-track-add-all")
        }
        .buttonStyle(TrackingActionStyle())
    }

    @ViewBuilder private func exerciseRows(_ title: String, _ rows: [Exercise], selected: Set<String>) -> some View {
        if !rows.isEmpty {
            sectionTitle(title)
            ForEach(rows) { exercise in
                let included = selected.contains(exercise.id)
                Button {
                    if included { selection.removeAll { $0 == exercise.id } }
                    else { selection.append(exercise.id) }
                } label: {
                    choiceLabel(exercise.displayName, detail: nil, symbol: included ? "checkmark.circle.fill" : "circle", selected: included)
                }
                .accessibilityAddTraits(included ? .isSelected : [])
                .accessibilityIdentifier("trends-track-exercise-\(exercise.id)")
                Divider()
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(NotebookTypography.heading(18, relativeTo: .headline))
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 16).padding(.bottom, 4)
    }

    private func choiceLabel(_ title: String, detail: String?, symbol: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(selected ? .semibold : .regular))
                if let detail { Text(detail).font(.subheadline).foregroundStyle(NotebookStyle.quiet) }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: symbol).foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.quiet)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8).frame(minHeight: 48).contentShape(Rectangle())
    }

    private func add(_ ids: [String]) {
        var seen = Set(selection)
        selection.append(contentsOf: ids.filter { seen.insert($0).inserted })
    }
}

private struct TrackingActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(enabled ? NotebookStyle.clay : NotebookStyle.quiet)
            .opacity(!enabled || configuration.isPressed ? 0.55 : 1)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct TrackedExerciseChooser: View {
    let model: TrainingNotebookModel
    let current: String?
    let inRange: Set<String>
    let choose: (String?) -> Void
    @State private var search = ""

    var body: some View {
        let catalog = Dictionary(uniqueKeysWithValues: model.exercises.map { ($0.id, $0) })
        let key = ExerciseLibrary.matchingKey(search)
        let choices = model.trackedStrengthExerciseIDs.map { catalog[$0] ?? model.exercise($0) }
            .filter { key.isEmpty || $0.matchesExerciseName(key: key) }
        NavigationStack {
            List {
                if key.isEmpty {
                    rows("Sets in this period", choices.filter { inRange.contains($0.id) })
                    rows("No sets in this period", choices.filter { !inRange.contains($0.id) })
                } else {
                    rows("Search results", ExerciseSelectionFilter.rankedMatches(choices, query: search))
                }
                if choices.isEmpty { Text("No matching exercises").foregroundStyle(NotebookStyle.quiet) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NotebookStyle.ivory)
            .navigationTitle("Tracked exercises")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $search, prompt: "Find an exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { choose(nil) }
                }
            }
        }
        .tint(NotebookStyle.clay)
    }

    @ViewBuilder private func rows(_ title: String, _ choices: [Exercise]) -> some View {
        if !choices.isEmpty {
            Section(title) {
                ForEach(choices) { exercise in
                    Button { choose(exercise.id) } label: {
                        HStack {
                            Text(exercise.displayName).foregroundStyle(NotebookStyle.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            if current == exercise.id {
                                Image(systemName: "checkmark").foregroundStyle(NotebookStyle.clay).accessibilityHidden(true)
                            }
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(current == exercise.id ? .isSelected : [])
                    .accessibilityIdentifier("trends-strength-exercise-\(exercise.id)")
                    .listRowBackground(NotebookStyle.ivory)
                }
            }
        }
    }
}
