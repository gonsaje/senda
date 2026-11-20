import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingDayExerciseList: View {
    @Bindable private var model: TrainingNotebookModel
    private let day: TrainingDay
    private let close: () -> Void
    private let add: () -> Void
    @State private var reordering = false
    @State private var pairing = false
    @State private var selectedPair: [String] = []
    @State private var rounds = 2
    @State private var restSeconds = 60
    @State private var pendingPair: SupersetPlan?
    @State private var pendingExerciseID: String?
    @State private var removalRequest: TrainingWorkoutRemovalRequest?

    public init(model: TrainingNotebookModel, day: TrainingDay, close: @escaping () -> Void, add: @escaping () -> Void) {
        self.model = model; self.day = day; self.close = close; self.add = add
    }

    private var exercises: [Exercise] { model.indexedExercises(on: day) }
    private var visibleIDs: [String] { model.workspace.days[day.rawValue]?.exerciseIDs ?? [] }

    public var body: some View {
        Group {
            if pairing { pairPicker }
            else if reordering { reorderList }
            else { exerciseList }
        }
        .safeAreaInset(edge: .bottom) {
            if let error = model.errorMessage {
                TrainingSaveError(model: model, message: error, retrySucceeded: completePendingSelection)
                    .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory)
            }
        }
        .modifier(TrainingWorkoutRemovalConfirmation(model: model, request: $removalRequest))
        .onChange(of: exercises.isEmpty) { _, empty in
            if empty && model.selectedDay == day { close() }
        }
        .scrollIndicators(.never)
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
        .onChange(of: model.canRetrySave) { _, _ in completePendingSelection(); finishPairingIfSaved() }
        .onChange(of: model.errorMessage) { _, _ in completePendingSelection() }
        .onChange(of: model.selectedDay) { _, _ in pendingExerciseID = nil }
        .onDisappear { cancelPendingListAction() }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 393, minHeight: 568, idealHeight: 740)
        #endif
    }

    private var exerciseList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                navigation
                VStack(alignment: .leading, spacing: 8) {
                    Text("All exercises").font(NotebookTypography.heading(32))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("day-exercises-title")
                    Text("\(TrainingText.date(day, format: "EEEE, MMM d")) · \(exercises.count) exercises")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    if exercises.contains(where: { !visibleIDs.contains($0.id) }) {
                        Text("Hidden tabs keep their sets and input. Choose one to show its tab again.")
                            .font(.callout).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(exercises) { exercise in
                        let member = memberships[exercise.id]
                        if let member, member.group.plan.first == exercise.id {
                            groupHeader(member)
                        }
                        exerciseRow(exercise, member: member)
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    }
                    if exercises.isEmpty {
                        Text("No exercises yet").font(.callout).foregroundStyle(NotebookStyle.quiet).padding(.vertical, 20)
                    }
                }
                if availableToPair.count >= 2 {
                    Button {
                        cancelPendingSelection()
                        selectedPair = []
                        rounds = 2
                        restSeconds = 60
                        pairing = true
                    } label: {
                        Label("Create superset", systemImage: "link")
                            .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 46)
                    }.buttonStyle(SupersetPrimaryStyle())
                        .accessibilityIdentifier("create-superset")
                }
                Button {
                    if model.selectedDay == day { cancelPendingSelection(); add() }
                } label: {
                    Label("Add exercise", systemImage: "plus").frame(minHeight: 48)
                }.foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("day-list-add-exercise")
            }
            .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("day-exercises-scroll")
    }

    private var memberships: [String: SupersetMembership] { model.supersetMemberships }
    private var availableToPair: [Exercise] {
        let paired = Set(model.supersets.flatMap { $0.plan.exerciseIDs })
        return model.tabs.filter { !paired.contains($0.id) }
    }

    private func exerciseRow(_ exercise: Exercise, member: SupersetMembership?) -> some View {
        let count = model.loggedSetCount(for: exercise.id, on: day)
        let selected = model.exercise?.id == exercise.id
        let hidden = !visibleIDs.contains(exercise.id)
        return HStack(spacing: 2) {
            Button {
                cancelPendingSelection()
                guard model.selectedDay == day else { return }
                pendingExerciseID = exercise.id
                let saved = hidden ? model.addExercise(exercise.id) : model.selectExercise(exercise.id)
                if saved { completePendingSelection() }
                else if !model.canRetrySave { pendingExerciseID = nil }
            } label: {
                HStack(spacing: 12) {
                    if let member {
                        Text(member.code(for: exercise.id)).font(.caption.bold())
                            .foregroundStyle(NotebookStyle.clay)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.displayName).font(.body.weight(selected ? .bold : .regular))
                            .foregroundStyle(NotebookStyle.ink).fixedSize(horizontal: false, vertical: true)
                        Text(countLabel(count)).font(.caption.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                        if hidden {
                            Text(count == 0 ? "Hidden tab · Input retained" : "Hidden tab · Sets retained")
                                .font(.caption).foregroundStyle(NotebookStyle.clay).fixedSize(horizontal: false, vertical: true)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: hidden ? "eye" : "chevron.right")
                        .font(.body).foregroundStyle(NotebookStyle.quiet)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 10).padding(.vertical, 14).frame(minHeight: 70)
                .background(selected ? NotebookStyle.clay.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .accessibilityLabel("\(member.map { $0.code(for: exercise.id) + ", " } ?? "")\(exercise.displayName), \(countLabel(count))\(hidden ? ", Hidden tab, retained work" : "")")
            .accessibilityHint(hidden ? "Restore its tab and open retained sets and input" : "Open exercise")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("day-exercise-\(exercise.id)")
            Button(role: .destructive) {
                cancelPendingSelection()
                removalRequest = TrainingWorkoutRemovalRequest(target: .exercise(exercise.id), day: day)
            } label: {
                Image(systemName: "trash")
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .foregroundStyle(NotebookStyle.quiet)
            .accessibilityLabel("Delete \(exercise.displayName) from this workout")
            .accessibilityIdentifier("day-delete-\(exercise.id)")
        }
    }

    private func groupHeader(_ member: SupersetMembership) -> some View {
        let group = member.group
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Label(member.title, systemImage: "link").font(.headline)
                Spacer()
                Button("Unpair") { cancelPendingSelection(); _ = model.unlinkSuperset(group.id) }
                    .font(.subheadline).foregroundStyle(NotebookStyle.clay)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Unpair \(member.title)")
                    .accessibilityHint("Keep both exercises and their sets")
            }
            HStack {
                Text(member.status).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                Spacer()
                Button {
                    cancelPendingSelection()
                    pendingExerciseID = group.phase == .finished ? group.plan.first : group.currentExerciseID
                    let saved = group.phase == .finished ? model.selectExercise(group.plan.first) : model.startSuperset(group.id)
                    if saved { completePendingSelection() } else if !model.canRetrySave { pendingExerciseID = nil }
                } label: {
                    Text(group.phase == .ready ? "Start superset" : group.phase == .finished ? "Review superset" : "Resume superset")
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }.foregroundStyle(NotebookStyle.clay)
                    .accessibilityIdentifier("start-superset-\(group.plan.first)")
            }
        }.padding(.top, 6)
    }

    private var pairPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button("Cancel", action: cancelPairing).foregroundStyle(NotebookStyle.clay)
                    .frame(minHeight: 44).accessibilityIdentifier("superset-cancel")
                Text("Create superset").font(NotebookTypography.heading(32)).accessibilityAddTraits(.isHeader)
                Text("Tap two exercises in the order you’ll do them.")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                VStack(spacing: 0) {
                    ForEach(availableToPair) { exercise in
                        let index = selectedPair.firstIndex(of: exercise.id)
                        Button {
                            if let index { selectedPair.remove(at: index) }
                            else if selectedPair.count < 2 { selectedPair.append(exercise.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Text(index.map { "\(nextGroupLetter)\($0 + 1)" } ?? "")
                                    .font(.caption.weight(.bold)).foregroundStyle(NotebookStyle.clay)
                                    .frame(minWidth: 30, minHeight: 30)
                                    .background(index != nil ? NotebookStyle.todayFill : .clear, in: Capsule())
                                    .overlay { Capsule().strokeBorder(index == nil ? NotebookStyle.quiet : .clear, lineWidth: 0.8) }
                                Text(exercise.displayName).font(.body.weight(.medium))
                                Spacer()
                            }.frame(minHeight: 58).contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(index == nil ? [] : .isSelected)
                        .accessibilityValue(index.map { "Exercise \($0 + 1)" } ?? "")
                        .accessibilityIdentifier("superset-pick-\(exercise.id)")
                        .disabled((index == nil && selectedPair.count == 2) || model.canRetrySave)
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    }
                }
                options
                Button(action: createPair) {
                    Text(selectedPair.count == 2 ? "Pair exercises" : "Select two exercises")
                        .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(SupersetPrimaryStyle())
                .disabled(selectedPair.count != 2 || model.canRetrySave)
                .accessibilityIdentifier("pair-superset")
            }
            .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("day-exercises-scroll")
    }

    private var nextGroupLetter: String {
        // The final letter depends on where the pair is inserted in the workout.
        let first = selectedPair.compactMap { visibleIDs.firstIndex(of: $0) }.min() ?? visibleIDs.count
        let preceding = model.supersets.filter { (visibleIDs.firstIndex(of: $0.plan.first) ?? Int.max) < first }.count
        return SupersetMembership.letter(at: preceding)
    }

    private var options: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { roundPicker; Spacer(); restPicker }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 0) { roundPicker; restPicker }
        }.disabled(model.canRetrySave)
    }

    private var roundPicker: some View {
        HStack {
            Text("Rounds").font(.subheadline)
            Picker("Rounds", selection: $rounds) {
                ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
            }.labelsHidden().pickerStyle(.menu).frame(minHeight: 44)
                .accessibilityIdentifier("superset-rounds")
        }
    }

    private var restPicker: some View {
        HStack {
            Text("Rest after round").font(.subheadline)
            Picker("Rest after round", selection: $restSeconds) {
                ForEach([0, 15, 30, 60, 90, 120], id: \.self) { seconds in
                    Text(seconds == 0 ? "Off" : Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))).tag(seconds)
                }
            }.labelsHidden().pickerStyle(.menu).frame(minHeight: 44)
                .accessibilityIdentifier("superset-rest")
        }
    }

    private func createPair() {
        guard model.selectedDay == day, selectedPair.count == 2 else { return }
        let plan = SupersetPlan(first: selectedPair[0], second: selectedPair[1], rounds: rounds, restSeconds: restSeconds)
        pendingPair = plan
        if model.createSuperset(plan) { finishPairingIfSaved() }
        else if !model.canRetrySave { pendingPair = nil }
    }

    private func finishPairingIfSaved() {
        guard let pendingPair, !model.canRetrySave, model.supersets.contains(where: { $0.plan == pendingPair }) else { return }
        self.pendingPair = nil
        pairing = false
    }

    private func cancelPairing() {
        if pendingPair != nil && model.canRetrySave { _ = model.cancelPendingAction() }
        pendingPair = nil
        pairing = false
    }

    private var navigation: some View {
        HStack {
            Button { cancelPendingListAction(); close() } label: {
                Label("Day", systemImage: "chevron.left").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityIdentifier("close-day-exercises")
            Spacer()
            if reorderGroups.count > 1 || reordering {
                Button {
                    cancelPendingSelection()
                    reordering.toggle()
                } label: {
                    Text(reordering ? "Done" : "Reorder").font(.body.weight(.medium))
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .disabled(model.canRetrySave)
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityIdentifier("day-exercises-reorder")
            }
        }
    }

    private var reorderList: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                navigation
                Text("Reorder exercises").font(NotebookTypography.heading(32))
                    .accessibilityAddTraits(.isHeader)
                Text(TrainingText.date(day, format: "EEEE, MMM d"))
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            }
            .padding(.horizontal, 24).padding(.top, 12)
            List {
                ForEach(reorderGroups, id: \.self) { group in
                    let id = group[0]
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(group, id: \.self) { exerciseID in
                            HStack(spacing: 8) {
                                if let member = memberships[exerciseID] {
                                    Text(member.code(for: exerciseID)).font(.caption.weight(.bold))
                                        .foregroundStyle(NotebookStyle.clay)
                                }
                                Text(model.exercise(exerciseID).displayName)
                                    .accessibilityIdentifier("reorder-exercise-\(exerciseID)")
                            }
                        }
                    }
                        .font(.body.weight(model.exercise?.id == id ? .semibold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .contextMenu { moveActions(for: id) }
                        .accessibilityActions { moveActions(for: id) }
                        .listRowBackground(NotebookStyle.ivory)
                }
                .onMove(perform: moveExercises)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
        }
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
    }

    @ViewBuilder private func moveActions(for id: String) -> some View {
        if let index = reorderGroups.firstIndex(where: { $0.contains(id) }) {
            if index > 0 {
                Button("Move up") { moveExercises(from: IndexSet(integer: index), to: index - 1) }
            }
            if index < reorderGroups.count - 1 {
                Button("Move down") { moveExercises(from: IndexSet(integer: index), to: index + 2) }
            }
        }
    }

    private var reorderGroups: [[String]] {
        SupersetOrder.groups(visibleIDs, plans: model.supersets.map(\.plan))
    }

    private func moveExercises(from offsets: IndexSet, to destination: Int) {
        var order = reorderGroups
        guard !model.canRetrySave, !offsets.isEmpty, offsets.allSatisfy(order.indices.contains),
              (0...order.count).contains(destination) else { return }
        order.move(fromOffsets: offsets, toOffset: destination)
        if order != reorderGroups { model.setExerciseOrder(order.flatMap { $0 }, on: day) }
    }

    private func cancelPendingListAction() {
        if pairing { cancelPairing() }
        if reordering && model.canRetrySave { _ = model.cancelPendingAction() }
        cancelPendingSelection()
    }

    private func completePendingSelection() {
        guard let id = pendingExerciseID, model.selectedDay == day, model.errorMessage == nil, !model.canRetrySave,
              visibleIDs.contains(id), model.exercise?.id == id else { return }
        pendingExerciseID = nil; close()
    }
    private func cancelPendingSelection() {
        guard pendingExerciseID != nil else { return }
        pendingExerciseID = nil; _ = model.cancelPendingAction()
    }

    private func countLabel(_ count: Int) -> String {
        count == 0 ? "No sets yet" : "\(count) \(count == 1 ? "set" : "sets")"
    }
}
