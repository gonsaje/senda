import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingInputDock: View {
    @Bindable var model: TrainingNotebookModel
    let focus: TrainingFocus
    var beginInteraction: () -> Void = {}
    let selectExercise: (String) -> Void
    @FocusState private var typing: Bool
    @AccessibilityFocusState(for: .voiceOver) private var editorFocused: Bool
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .largeTitle) private var numeralSize: CGFloat = 31
    private var index: Int { model.setPosition(for: focus.rowID)?.setIndex ?? 1 }
    private var setContext: String {
        let base = "Set \(index)"
        guard let position = model.setPosition(for: focus.rowID), position.isDropSet else { return base }
        return "\(base) · \(position.stageIndex == 1 ? "Start" : "Drop \(position.stageIndex - 1)")"
    }
    private var fieldLabel: String { focus.field == .weight ? "Weight (\(model.unit.symbol))" : "Reps" }
    private var headerLayout: AnyLayout {
        textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 8))
    }
    private var isLastRow: Bool { model.rows.last?.id == focus.rowID }
    private var canStartNextSet: Bool {
        guard let row = model.focusedRow else { return false }
        return model.rowStatus(for: row) == .recorded && model.errorMessage == nil && !model.canRetrySave
    }
    private var inputAccessibilityValue: String {
        let text = model.inputText(for: focus)
        guard !text.isEmpty else { return "Not entered" }
        let unit: String
        if focus.field == .weight {
            unit = model.unit == .pounds ? (text == "1" ? "pound" : "pounds") : (text == "1" ? "kilogram" : "kilograms")
        } else {
            unit = text == "1" ? "rep" : "reps"
        }
        return "\(text) \(unit)"
    }
    var body: some View {
        VStack(spacing: 8) {
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
            adjacentExercises
            headerLayout {
                Text(textSize.isAccessibilitySize ? setContext : "\(model.exercise?.displayName ?? "") · \(setContext)")
                    .font(textSize.isAccessibilitySize ? .caption2 : .caption).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("input-set-context")
                HStack(spacing: 8) {
                    if !textSize.isAccessibilitySize { Spacer(minLength: 0) }
                    if focus.field == .weight {
                        if typing && !textSize.isAccessibilitySize {
                            Button { typing = false } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }
                            .accessibilityLabel("Use weight dial")
                            .accessibilityHint("Close the keyboard without changing the value")
                            .accessibilityIdentifier("input-use-dial")
                        }
                        Button { beginInteraction(); model.selectInput(focus.rowID, field: .reps) } label: {
                            Text("Reps →").font(.subheadline.weight(.medium)).foregroundStyle(NotebookStyle.clay)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                        }
                        .accessibilityLabel("Edit reps")
                        .accessibilityHint("Edit reps for \(setContext.lowercased())")
                        .accessibilityIdentifier("input-next")
                    } else if isLastRow {
                        Button {
                            beginInteraction()
                            if model.newSet(keyboard: typing) {
                                TrainingAccessibility.announce("New set. Enter \(model.exercise?.requiresWeight == false ? "reps" : "weight").")
                            }
                        } label: {
                            Text("Next set").font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                        }
                        .disabled(!canStartNextSet)
                        .foregroundStyle(canStartNextSet ? NotebookStyle.clay : NotebookStyle.quiet)
                        .accessibilityHint("Start another working set with blank values")
                        .accessibilityIdentifier("input-next-set")
                    }
                    if textSize.isAccessibilitySize { Spacer(minLength: 8) }
                    Button(action: finishEditing) {
                        Text("Done").font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityHint("Close the number editor")
                    .accessibilityIdentifier("input-done")
                }
            }
            Text(fieldLabel).font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.quiet)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("input-field-label")
            if textSize.isAccessibilitySize {
                valueInput
                HStack {
                    step(false)
                    Spacer(minLength: 8)
                    step(true)
                }
            } else {
                HStack(spacing: 16) {
                    step(false)
                    valueInput
                    step(true)
                }
            }
            // Typing and the large step controls retain the same adjustments at
            // accessibility sizes without taking another line of entry space.
            if focus.field == .weight && !typing && !textSize.isAccessibilitySize {
                WeightDialSurface(
                    value: model.focusedRow?.parsedWeight ?? model.focusedRow?.canonicalWeight ?? 0,
                    unit: model.unit,
                    beginInteraction: beginInteraction,
                    update: { model.setInputWeight($0, focus: focus) }
                )
                .id(model.unit)
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .task {
            await Task.yield()
            if !Task.isCancelled { typing = focus.keyboard; editorFocused = true }
        }
    }

    @ViewBuilder private var adjacentExercises: some View {
        let exercises = model.tabs
        if exercises.count > 1, let index = exercises.firstIndex(where: { $0.id == focus.exerciseID }) {
            HStack(spacing: 8) {
                if index > 0 { exerciseButton(exercises[index - 1], previous: true) }
                Spacer(minLength: 4)
                if index + 1 < exercises.count { exerciseButton(exercises[index + 1], previous: false) }
            }
        }
    }

    private func exerciseButton(_ exercise: Exercise, previous: Bool) -> some View {
        Button { selectExercise(exercise.id) } label: {
            HStack(spacing: 6) {
                if previous { Image(systemName: "chevron.backward") }
                Text(exercise.displayName).fixedSize(horizontal: false, vertical: true)
                if !previous { Image(systemName: "chevron.forward") }
            }
            .font(.footnote.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.clay)
        .accessibilityLabel(previous ? "Previous exercise, \(exercise.displayName)" : "Next exercise, \(exercise.displayName)")
        .accessibilityIdentifier(previous ? "input-previous-exercise" : "input-next-exercise")
    }

    private var valueInput: some View {
                TextField("", text: Binding(
                    get: { model.inputText(for: focus) }, set: { beginInteraction(); model.typeInput($0, focus: focus) }))
                    .font(.system(size: numeralSize, weight: .medium).monospacedDigit()).multilineTextAlignment(.center)
                    .textFieldStyle(.plain).numericKeyboard(decimal: focus.field == .weight).focused($typing)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .submitLabel(focus.field == .weight ? .next : .done)
                    .onSubmit {
                        if focus.field == .weight { beginInteraction(); model.selectInput(focus.rowID, field: .reps) }
                        else { finishEditing() }
                    }
                    .accessibilityLabel("\(setContext), \(focus.field == .weight ? "weight in \(model.unit.symbol)" : "reps")")
                    .accessibilityHint("Type a value or use the increase and decrease buttons")
                    .accessibilityFocused($editorFocused)
                    .accessibilityIdentifier("set-input")
                    .simultaneousGesture(TapGesture().onEnded { beginInteraction() })
    }
    private func finishEditing() {
        beginInteraction()
        guard model.finishEditing(), let row = model.rows.first(where: { $0.id == focus.rowID }) else { return }
        let message: String
        switch model.rowStatus(for: row) {
        case .empty: message = "\(setContext) needs values."
        case .unfinished: message = "Input saved. Enter valid values to complete the set."
        case .recorded: message = "\(setContext) saved."
        case .pendingCorrection: message = "Input saved. Last saved values are unchanged."
        }
        TrainingAccessibility.announce(message)
    }
    private func step(_ increasing: Bool) -> some View {
        Button {
            beginInteraction()
            if model.stepInput(increasing: increasing, focus: focus) {
                if focus.field == .weight { typing = false }
                if model.errorMessage == nil { TrainingAccessibility.announce(inputAccessibilityValue) }
            }
        } label: {
            Image(systemName: increasing ? "plus" : "minus").font(.system(size: 22, weight: .light)).frame(width: 50, height: 48)
                .contentShape(Rectangle())
        }.accessibilityLabel("\(increasing ? "Increase" : "Decrease") \(focus.field == .weight ? "weight in \(model.unit.symbol)" : "reps")")
            .accessibilityValue(inputAccessibilityValue)
            .accessibilityIdentifier(increasing ? "input-increase" : "input-decrease")
    }
}
