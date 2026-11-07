import SwiftUI
import SendaDomain
import SendaLogger

struct ExercisePickerView: View {
    @Bindable var model: LoggerModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var creating = false
    private var matches: [Exercise] {
        let query = ExerciseLibrary.searchKey(search)
        return model.availableExercises.filter {
            query.isEmpty || ExerciseLibrary.searchKey($0.name).contains(query) || ExerciseLibrary.searchKey($0.shortName).contains(query)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(matches) { exercise in
                    Button {
                        if model.addExercise(exercise.id) { dismiss() }
                    } label: {
                        HStack(spacing: 12) {
                            Text(exercise.name).foregroundStyle(NotebookStyle.ink)
                            Spacer()
                            if model.workoutExerciseIDs.contains(exercise.id) {
                                Image(systemName: "checkmark").foregroundStyle(NotebookStyle.clay).accessibilityHidden(true)
                            }
                        }.frame(minHeight: 38).contentShape(Rectangle())
                    }
                    .accessibilityLabel(exercise.name + (model.workoutExerciseIDs.contains(exercise.id) ? ", in workout" : ""))
                    .accessibilityIdentifier("picker-exercise-\(exercise.id)")
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
    @FocusState private var typing: Bool

    init(model: LoggerModel, initialName: String, close: @escaping () -> Void) {
        self.model = model; self.close = close
        _name = State(initialValue: initialName.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TextField("Exercise name", text: $name)
                .font(.system(size: 28, design: .serif)).textFieldStyle(.plain).focused($typing)
                .accessibilityLabel("Exercise name").accessibilityIdentifier("custom-exercise-name")
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 1) }
            if let error = model.errorMessage { Text(error).font(.callout).foregroundStyle(NotebookStyle.clay) }
            Spacer()
        }
        .padding(.horizontal, 24).padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .navigationTitle("New exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: close).accessibilityIdentifier("cancel-exercise-picker")
            }
        }
        .safeAreaInset(edge: .bottom) {
            RecordButton(title: "Add exercise") {
                if model.createAndAddExercise(named: name) { typing = false; close() }
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("add-custom-exercise")
            .padding(.horizontal, 24).padding(.vertical, 12).background(NotebookStyle.ivory)
        }
        .onAppear { typing = true }
    }
}
