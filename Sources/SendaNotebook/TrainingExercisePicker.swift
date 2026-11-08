import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingExercisePicker: View {
    @Bindable private var model: TrainingNotebookModel
    private let close: () -> Void
    @State private var search = ""
    @State private var group = MuscleGroup.chest
    @State private var equipment: ExerciseEquipment?
    @State private var creating = false
    public init(model: TrainingNotebookModel, close: @escaping () -> Void) { self.model = model; self.close = close; _group = State(initialValue: model.exercise?.group ?? .chest) }
    private var matches: [Exercise] {
        let query = ExerciseLibrary.searchKey(search)
        return model.exercises.filter { exercise in
            (query.isEmpty ? exercise.group == group : ExerciseLibrary.searchKey(exercise.name).contains(query) || ExerciseLibrary.searchKey(exercise.shortName).contains(query))
                && (equipment == nil || exercise.equipmentType == equipment)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    public var body: some View {
        Group {
            if creating {
                CreateTrainingExercise(model: model, name: search, group: group, equipment: equipment ?? .other,
                    back: { model.dismissError(); creating = false }, close: close)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Button { model.dismissError(); close() } label: { Label("Day", systemImage: "chevron.left").frame(minHeight: 44) }
                            .accessibilityIdentifier("close-exercise-picker")
                        Text("Add exercise").font(NotebookTypography.heading(34))
                        HStack(spacing: 9) {
                            Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet)
                            TextField("Find an exercise", text: $search).textFieldStyle(.plain).autocorrectionDisabled()
                                .accessibilityIdentifier("exercise-search")
                        }.padding(12).overlay { RoundedRectangle(cornerRadius: 7).stroke(NotebookStyle.rule, lineWidth: 1) }
                        TrainingFlowLayout(spacing: 8) {
                            ForEach(MuscleGroup.allCases, id: \.self) { item in
                                chip(item.rawValue, selected: item == group) { group = item }
                                    .accessibilityIdentifier("group-\(item.rawValue)")
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Equipment").font(.subheadline.weight(.semibold))
                            TrainingFlowLayout(spacing: 8) {
                                chip("All", selected: equipment == nil) { equipment = nil }.accessibilityIdentifier("equipment-All")
                                ForEach(ExerciseEquipment.allCases, id: \.self) { item in
                                    chip(item.rawValue, selected: item == equipment) { equipment = item }
                                        .accessibilityIdentifier("equipment-\(item.rawValue)")
                                }
                            }
                        }
                        Text(search.isEmpty ? group.rawValue : "Exercises").font(NotebookTypography.heading(26))
                        VStack(spacing: 0) {
                            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                            ForEach(matches) { exercise in
                                let added = model.workout?.exerciseIDs.contains(exercise.id) == true
                                Button { if model.addExercise(exercise.id) { close() } } label: {
                                    HStack(spacing: 12) {
                                        Text(exercise.name).frame(maxWidth: .infinity, alignment: .leading)
                                        if added { Text("Added").font(.caption).foregroundStyle(NotebookStyle.clay) }
                                        else { Image(systemName: "plus").foregroundStyle(NotebookStyle.clay) }
                                    }.frame(minHeight: 48).contentShape(Rectangle())
                                }.accessibilityLabel(exercise.name + (added ? ", added" : ""))
                                    .accessibilityIdentifier("picker-\(exercise.id)")
                                Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                            }
                            if matches.isEmpty { Text("No exercises found").font(.callout).foregroundStyle(NotebookStyle.quiet).padding(.vertical, 20) }
                        }
                        Button { model.dismissError(); creating = true } label: { Label("Create exercise", systemImage: "plus").frame(minHeight: 48) }
                            .foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("create-exercise")
                        if let error = model.errorMessage { Text(error).font(.callout).foregroundStyle(NotebookStyle.clay) }
                    }.padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("exercise-picker-scroll")
            }
        }
        .scrollIndicators(.never)
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 470, minHeight: 620, idealHeight: 740)
        #endif
    }
    private func chip(_ name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name).font(.system(size: 14)).padding(.horizontal, 12).frame(minHeight: 36)
                .foregroundStyle(selected ? NotebookStyle.ivory : NotebookStyle.ink)
                .background(selected ? NotebookStyle.clay : .clear, in: Capsule())
                .overlay { Capsule().stroke(selected ? .clear : NotebookStyle.rule, lineWidth: 0.7) }
        }.accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct CreateTrainingExercise: View {
    @Bindable var model: TrainingNotebookModel
    @State var name: String
    @State var group: MuscleGroup
    @State var equipment: ExerciseEquipment
    let back: () -> Void
    let close: () -> Void
    @FocusState private var typing: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button(action: back) { Label("Exercises", systemImage: "chevron.left").frame(minHeight: 44) }
                Text("Create exercise").font(NotebookTypography.heading(32))
                TextField("Exercise name", text: $name).textFieldStyle(.plain).font(NotebookTypography.heading(26, relativeTo: .title2)).focused($typing)
                    .padding(.vertical, 12).overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
                    .accessibilityIdentifier("custom-name")
                Picker("Muscle group", selection: $group) { ForEach(MuscleGroup.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                    .accessibilityIdentifier("custom-group")
                Picker("Equipment", selection: $equipment) { ForEach(ExerciseEquipment.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                    .accessibilityIdentifier("custom-equipment")
                if let error = model.errorMessage { Text(error).font(.callout).foregroundStyle(NotebookStyle.clay) }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("custom-exercise-scroll")
        .safeAreaInset(edge: .bottom) {
            RecordButton(title: "Add exercise") {
                if model.createExercise(named: name, group: group, equipment: equipment) { close() }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("save-custom-exercise")
                .padding(.horizontal, 24).padding(.vertical, 12).background(NotebookStyle.ivory)
        }
        .background(NotebookStyle.ivory).task { typing = true }
    }
}

private struct TrainingFlowLayout: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(proposal.width ?? 393, subviews).0
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrangement(bounds.width, subviews).1
        for (index, position) in positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    private func arrangement(_ width: CGFloat, _ subviews: Subviews) -> (CGSize, [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, height: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += height + spacing; height = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; height = max(height, size.height)
        }
        return (CGSize(width: width, height: y + height), points)
    }
}
