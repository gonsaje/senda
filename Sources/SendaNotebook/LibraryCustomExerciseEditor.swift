import SwiftUI
import SendaDomain
import SendaLogger

struct LibraryCustomExerciseEditor: View {
    @Bindable var model: TrainingNotebookModel
    let exercise: Exercise?
    let saved: (Exercise) -> Void
    @State private var draft: Draft
    @State private var attemptedSave = false
    @FocusState private var typing: Bool
    @Environment(\.dismiss) private var dismiss

    private struct Draft: Equatable {
        var name: String
        var group: MuscleGroup
        var equipment: ExerciseEquipment
        var setup: CustomExerciseSetup
    }

    init(model: TrainingNotebookModel, exercise: Exercise?, saved: @escaping (Exercise) -> Void) {
        self.model = model
        self.exercise = exercise
        self.saved = saved
        _draft = State(initialValue: Draft(name: exercise?.name ?? "", group: exercise?.group ?? .fullBody,
                                         equipment: exercise?.equipmentType ?? .other, setup: exercise?.customSetup ?? .init()))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(exercise == nil ? "Add exercise" : "Edit exercise")
                    .font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Exercise name").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    TextField("Exercise name", text: $draft.name)
                        .textFieldStyle(.plain).font(.body).focused($typing)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("library-exercise-name")
                    WorkoutLibraryRule()
                }
                Picker("Muscle group", selection: $draft.group) {
                    ForEach(MuscleGroup.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu).frame(minHeight: 44)
                .accessibilityIdentifier("library-exercise-group")
                Picker("Main equipment", selection: $draft.equipment) {
                    ForEach(ExerciseEquipment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu).frame(minHeight: 44)
                .accessibilityIdentifier("library-exercise-equipment")
                CustomExerciseSetupButton(setup: $draft.setup, onOpen: { typing = false })
                if attemptedSave, let error = model.errorMessage {
                    TrainingSaveError(model: model, message: error, retrySucceeded: finishSave)
                }
            }
            .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("library-exercise-editor")
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { clearAttempt(); dismiss() } label: {
                    Text("Cancel").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("library-cancel-exercise")
                Spacer()
                Button(action: save) {
                    Text("Save").fontWeight(.semibold).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          (attemptedSave && model.canRetrySave))
                .accessibilityIdentifier("library-save-exercise")
            }
            .padding(.horizontal, 24).padding(.vertical, 4)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .foregroundStyle(NotebookStyle.clay).background(NotebookStyle.ivory)
            .overlay(alignment: .bottom) { WorkoutLibraryRule() }
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .onChange(of: draft) { _, _ in clearAttempt() }
        .onChange(of: model.canRetrySave) { _, _ in finishSave() }
        .onChange(of: model.errorMessage) { _, _ in finishSave() }
        .onDisappear { clearAttempt() }
    }

    private func save() {
        typing = false
        attemptedSave = true
        let succeeded: Bool
        if let exercise {
            succeeded = model.updateCustomExercise(exercise.id, named: draft.name, group: draft.group,
                                                  equipment: draft.equipment, customSetup: draft.setup)
        } else {
            succeeded = model.createLibraryExercise(named: draft.name, group: draft.group,
                                                    equipment: draft.equipment, customSetup: draft.setup)
        }
        if succeeded { finishSave() }
    }

    private func finishSave() {
        guard attemptedSave, !model.canRetrySave, model.errorMessage == nil else { return }
        let key = ExerciseLibrary.matchingKey(draft.name)
        guard let stored = (model.snapshot.customExercises ?? []).first(where: {
            (exercise == nil || $0.id == exercise?.id) && model.canManageCustomExercise($0.id)
                && ExerciseLibrary.matchingKey($0.name) == key && $0.group == draft.group
                && $0.equipmentType == draft.equipment && $0.customSetup == draft.setup
        }) else { return }
        attemptedSave = false
        saved(stored)
    }

    private func clearAttempt() {
        guard attemptedSave else { return }
        attemptedSave = false
        if model.canRetrySave { _ = model.cancelPendingAction() }
        else { model.dismissError() }
    }
}
