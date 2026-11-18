import SwiftUI
import SendaDomain
import SendaLogger

struct ExercisePickerView: View {
    @Bindable var model: LoggerModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var creating = false
    @StoredExerciseGymFilter private var gymFilter
    private var matches: [Exercise] {
        let matches = ExerciseSelectionFilter.results(in: model.availableExercises, query: search, group: nil, equipment: nil, gymFilter: gymFilter)
        if !search.isEmpty { return ExerciseSelectionFilter.rankedMatches(matches, query: search) }
        return matches.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            if model.addExercise(exercise.id) { dismiss() }
        } label: {
            HStack(spacing: 12) {
                Text(exercise.displayName).foregroundStyle(NotebookStyle.ink)
                Spacer()
                if model.workoutExerciseIDs.contains(exercise.id) {
                    Image(systemName: "checkmark").foregroundStyle(NotebookStyle.clay).accessibilityHidden(true)
                }
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(exercise.displayName + (model.workoutExerciseIDs.contains(exercise.id) ? ", in workout" : ""))
        .accessibilityIdentifier("picker-exercise-\(exercise.id)")
    }

    var body: some View {
        NavigationStack {
            List {
                let results = matches
                let recovery = ExerciseSearchRecovery.find(query: search, in: model.availableExercises, gymFilter: gymFilter,
                    includePartialMatch: results.isEmpty, excludingAlternatives: Set(results.map(\.id)))
                GymSetupSwitcher().listRowBackground(NotebookStyle.ivory)
                if let recovery {
                    ExerciseSearchRecoveryView(recovery: recovery, row: exerciseRow)
                        .buttonStyle(.plain).listRowBackground(NotebookStyle.ivory)
                }
                if results.isEmpty && gymFilter.activeCount > 0 {
                    VStack(alignment: .leading) {
                        if recovery == nil { Text("No exercises found").font(.headline) }
                        Button("Clear filters") { gymFilter = .init() }.frame(minHeight: 44)
                    }.listRowBackground(NotebookStyle.ivory)
                }
                ForEach(results) { exercise in
                    exerciseRow(exercise)
                    .listRowBackground(NotebookStyle.ivory)
                }
                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(NotebookStyle.clay).listRowBackground(NotebookStyle.ivory)
                }
            }
            .scrollContentBackground(.hidden).background(NotebookStyle.ivory)
            .searchable(text: $search, prompt: "Find an exercise")
            .accessibilityIdentifier("exercise-picker")
            .navigationTitle("Add exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("cancel-exercise-picker")
                }
                ToolbarItem(placement: .primaryAction) {
                    LibraryGymFilterButton(filter: $gymFilter, identifier: "legacy-gym-filters", resultCount: {
                        ExerciseSelectionFilter.results(in: model.availableExercises, query: search, group: nil, equipment: nil, gymFilter: $0).count
                    })
                }
            }
            .safeAreaInset(edge: .bottom) {
                RecordButton(title: "Create exercise") { model.errorMessage = nil; creating = true }
                    .accessibilityIdentifier("create-exercise")
                    .padding(.horizontal, 24).padding(.vertical, 12).background(NotebookStyle.ivory)
            }
            .navigationDestination(isPresented: $creating) {
                CustomExerciseView(model: model, initialName: search, close: { dismiss() })
            }
        }
        .tint(NotebookStyle.clay).background(NotebookStyle.ivory)
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 470, minHeight: 560, idealHeight: 640)
        #endif
        .onAppear { model.errorMessage = nil }
    }
}

private struct CustomExerciseView: View {
    @Bindable var model: LoggerModel
    var close: () -> Void
    @State private var name: String
    @State private var setup = CustomExerciseSetup()
    @FocusState private var typing: Bool

    init(model: LoggerModel, initialName: String, close: @escaping () -> Void) {
        self.model = model; self.close = close
        _name = State(initialValue: initialName.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Exercise name", text: $name)
                    .font(.system(size: 28, design: .serif)).textFieldStyle(.plain).focused($typing)
                    .accessibilityLabel("Exercise name").accessibilityIdentifier("custom-exercise-name")
                    .padding(.vertical, 16)
                    .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 1) }
                CustomExerciseSetupButton(setup: $setup, onOpen: { typing = false })
                if let error = model.errorMessage { Text(error).font(.callout).foregroundStyle(NotebookStyle.clay) }
            }
            .padding(.horizontal, 24).padding(.top, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .navigationTitle("New exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: close).accessibilityIdentifier("cancel-exercise-picker")
            }
        }
        .safeAreaInset(edge: .bottom) {
            RecordButton(title: "Add exercise") {
                if model.createAndAddExercise(named: name, customSetup: setup) { typing = false; close() }
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("add-custom-exercise")
            .padding(.horizontal, 24).padding(.vertical, 12).background(NotebookStyle.ivory)
        }
        .onAppear { typing = true }
    }
}
