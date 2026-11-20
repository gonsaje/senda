import SwiftUI
import SendaDomain
import SendaLogger

/// The whole draft is saved in one operation. Navigating between blocks and sessions edits only this copy.
struct TrainingProgramEditor: View {
    let model: TrainingNotebookModel
    let original: TrainingProgram
    let close: (TrainingProgram?) -> Void
    @State private var draft: TrainingProgram
    @State private var discard = false
    @State private var problem: String?
    @State private var failedWrite = false
    @State private var path: [ProgramEditorPage] = []

    init(model: TrainingNotebookModel, original: TrainingProgram, close: @escaping (TrainingProgram?) -> Void) {
        self.model = model
        self.original = original
        self.close = close
        _draft = State(initialValue: original)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section("Program") {
                    TextField("Program name", text: $draft.title)
                        .accessibilityIdentifier("program-editor-name")
                    TextField("Who it’s for and what it trains", text: $draft.summary, axis: .vertical)
                    NavigationLink("Coach and sources", value: ProgramEditorPage.author)
                }
                Section("Training blocks") {
                    ForEach(draft.blocks.indices, id: \.self) { i in
                        HStack {
                            NavigationLink(value: ProgramEditorPage.block(i)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(draft.blocks[i].title)
                                    Text("\(draft.blocks[i].weeks) weeks · \(draft.blocks[i].sessions.count) workouts per week")
                                        .font(.caption).foregroundStyle(NotebookStyle.quiet)
                                }
                            }
                            Menu {
                                if i > 0 { Button("Move earlier") { draft.blocks.swapAt(i, i - 1) } }
                                if i + 1 < draft.blocks.count { Button("Move later") { draft.blocks.swapAt(i, i + 1) } }
                                Button("Duplicate block") { draft.blocks.insert(draft.blocks[i], at: i + 1) }
                                    .disabled(draft.weeks + draft.blocks[i].weeks > 52)
                                Button("Delete block", role: .destructive) { draft.blocks.remove(at: i) }
                            } label: { Label("Block options", systemImage: "ellipsis.circle") }.labelStyle(.iconOnly).buttonStyle(.borderless)
                        }
                    }
                    if draft.weeks < 52 {
                        Button {
                            let i = draft.blocks.count
                            draft.blocks.append(ProgramBlock(title: "Block \(i + 1)", weeks: min(4, 52 - draft.weeks)))
                            path.append(.block(i))
                        } label: { Label("Add block", systemImage: "plus") }
                        .accessibilityIdentifier("program-add-block")
                    }
                }
                if let problem { Text(problem).foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("program-save-error") }
            }
            .navigationTitle(model.customPrograms.contains { $0.id == draft.id } ? "Edit program" : "New program")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if draft == original { close(nil) } else { discard = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).accessibilityIdentifier("save-training-program")
                }
            }
            .programPageStyle()
            .navigationDestination(for: ProgramEditorPage.self) { page in
                switch page {
                case .author:
                    Form {
                        Section("Coach") {
                            TextField("Coach’s name", text: $draft.author.programText)
                            TextField("Credentials, e.g. CSCS", text: $draft.credential.programText)
                        }
                        Section("Programming reference") {
                            TextField("Source URL", text: $draft.sourceURL.programText)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .keyboardType(.URL).textInputAutocapitalization(.never)
                                #endif
                        }
                        Section("Coaching notes") {
                            TextField("Progression, loading, and recovery guidance", text: $draft.coachingNotes.programText, axis: .vertical)
                        }
                    }.navigationTitle("Coach and sources").programPageStyle()
                case .block(let b):
                    if draft.blocks.indices.contains(b) {
                        ProgramBlockEditor(block: $draft.blocks[b], index: b,
                            maxWeeks: max(1, 52 - draft.weeks + draft.blocks[b].weeks), path: $path)
                    }
                case let .libraryWorkout(b):
                    if draft.blocks.indices.contains(b) {
                        ProgramWorkoutPicker(model: model) { workout in
                            guard path.last == .libraryWorkout(b), draft.blocks.indices.contains(b),
                                  let day = draft.blocks[b].firstAvailableDay else { return }
                            let i = draft.blocks[b].sessions.count
                            draft.blocks[b].sessions.append(ProgramSession(template: workout, dayOffset: day))
                            path[path.count - 1] = .session(b, i)
                        }
                    }
                case let .session(b, i):
                    if hasSession(b, i) {
                        ProgramSessionEditor(model: model, session: $draft.blocks[b].sessions[i], block: b, index: i,
                            otherDays: Set(draft.blocks[b].sessions.indices.filter { $0 != i }.map { draft.blocks[b].sessions[$0].dayOffset }),
                            path: $path)
                    }
                case let .exercises(b, i):
                    if hasSession(b, i) { ProgramExercisePicker(model: model, session: $draft.blocks[b].sessions[i]) }
                case let .target(b, i, id):
                    if hasSession(b, i), let j = draft.blocks[b].sessions[i].exercises.firstIndex(where: { $0.exerciseID == id }) {
                        ProgramTargetEditor(target: $draft.blocks[b].sessions[i].exercises[j], name: model.exercise(id).displayName)
                    }
                case let .pair(b, i, member):
                    if hasSession(b, i) { ProgramPairEditor(model: model, session: $draft.blocks[b].sessions[i], member: member) }
                }
            }
        }
        .interactiveDismissDisabled(draft != original)
        .confirmationDialog("Discard your changes?", isPresented: $discard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { close(nil) }
            Button("Keep editing", role: .cancel) {}
        }
        .onChange(of: draft) { _, _ in problem = nil; cancelFailedWrite() }
        .onDisappear { cancelFailedWrite() }
    }

    private func hasSession(_ block: Int, _ session: Int) -> Bool {
        draft.blocks.indices.contains(block) && draft.blocks[block].sessions.indices.contains(session)
    }

    private func save() {
        if model.saveProgram(draft) { close(draft) }
        else {
            failedWrite = model.canRetrySave
            problem = model.errorMessage ?? "Check the program details and try again."
            if let problem { TrainingAccessibility.announce(problem) }
        }
    }

    private func cancelFailedWrite() {
        if failedWrite && model.canRetrySave { _ = model.cancelPendingAction() }
        failedWrite = false
    }
}

private extension Binding where Value == String? {
    var programText: Binding<String> {
        Binding<String>(get: { wrappedValue ?? "" }, set: { wrappedValue = $0.isEmpty ? nil : $0 })
    }
}

private enum ProgramEditorPage: Hashable {
    case author, block(Int), libraryWorkout(Int), session(Int, Int), exercises(Int, Int), target(Int, Int, String), pair(Int, Int, String?)
}

private struct ProgramBlockEditor: View {
    @Binding var block: ProgramBlock
    let index: Int
    let maxWeeks: Int
    @Binding var path: [ProgramEditorPage]
    private var freeDay: Int? { block.firstAvailableDay }

    var body: some View {
        Form {
            Section("Block") {
                TextField("Block name", text: $block.title)
                Stepper("Duration · \(block.weeks) \(block.weeks == 1 ? "week" : "weeks")", value: $block.weeks, in: 1...maxWeeks)
                TextField("How to progress through this block", text: $block.progression, axis: .vertical)
            }
            Section {
                ForEach(block.sessions.indices.sorted { block.sessions[$0].dayOffset < block.sessions[$1].dayOffset }, id: \.self) { i in
                    HStack {
                        NavigationLink(value: ProgramEditorPage.session(index, i)) {
                            VStack(alignment: .leading) {
                                Text(block.sessions[i].title)
                                Text("Day \(block.sessions[i].dayOffset + 1)").font(.caption).foregroundStyle(NotebookStyle.quiet)
                            }
                        }
                        Menu {
                            if let freeDay {
                                Button("Duplicate workout") {
                                    var copy = block.sessions[i]
                                    copy.dayOffset = freeDay
                                    block.sessions.append(copy)
                                }
                            }
                            Button("Delete workout", role: .destructive) { block.sessions.remove(at: i) }
                        } label: { Label("Workout options", systemImage: "ellipsis.circle") }.labelStyle(.iconOnly).buttonStyle(.borderless)
                    }
                }
                if let freeDay {
                    Button {
                        let i = block.sessions.count
                        block.sessions.append(ProgramSession(title: "Workout \(i + 1)", dayOffset: freeDay))
                        path.append(.session(index, i))
                    } label: { Label("Add blank workout", systemImage: "plus") }
                    .accessibilityIdentifier("program-add-session")
                    NavigationLink(value: ProgramEditorPage.libraryWorkout(index)) {
                        Label("Use library workout", systemImage: "books.vertical")
                    }.accessibilityIdentifier("program-use-library-workout")
                }
            } header: { Text("Weekly schedule") } footer: {
                Text("Day 1 is the program’s start day. This schedule repeats each week of the block.")
            }
        }.navigationTitle("Edit block").programPageStyle()
    }
}

private extension ProgramBlock {
    var firstAvailableDay: Int? { (0...6).first { day in !sessions.contains { $0.dayOffset == day } } }
}

private struct ProgramWorkoutPicker: View {
    let model: TrainingNotebookModel
    let choose: (WorkoutTemplate) -> Void
    @State private var search = ""

    var body: some View {
        let personal = model.matchingWorkouts(model.savedWorkouts, query: search)
        let starters = model.matchingWorkouts(model.starterWorkouts, query: search)
        List {
            if !personal.isEmpty { Section("My workouts") { rows(personal) } }
            if !starters.isEmpty { Section("Starter workouts") { rows(starters) } }
            if personal.isEmpty && starters.isEmpty { Text("No matching workouts").foregroundStyle(NotebookStyle.quiet) }
        }
        .searchable(text: $search, prompt: "Workout or exercise")
        .navigationTitle("Use library workout")
        .programPageStyle()
    }

    private func rows(_ workouts: [WorkoutTemplate]) -> some View {
        ForEach(workouts) { workout in
            Button { choose(workout) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name).font(.body.weight(.semibold))
                    let count = workout.exerciseIDs.count
                    Text("\(count) \(count == 1 ? "exercise" : "exercises")")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.accessibilityIdentifier("program-use-\(workout.id)")
        }
    }
}

private struct ProgramSessionEditor: View {
    let model: TrainingNotebookModel
    @Binding var session: ProgramSession
    let block: Int
    let index: Int
    let otherDays: Set<Int>
    @Binding var path: [ProgramEditorPage]

    private var units: [[String]] {
        SupersetOrder.groups(session.exercises.map(\.exerciseID), plans: session.supersets)
    }

    var body: some View {
        Form {
            Section("Workout") {
                TextField("Workout name", text: $session.title).accessibilityIdentifier("program-session-name")
                Picker("Schedule on", selection: $session.dayOffset) {
                    ForEach((0..<7).filter { !otherDays.contains($0) }, id: \.self) { n in
                        Text("Day \(n + 1)").tag(n)
                    }
                }
            }
            Section("Exercises") {
                if session.exercises.count > 30 {
                    Text("A program workout can hold 30 exercises. Remove \(session.exercises.count - 30) to save.")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }
                ForEach(session.exercises, id: \.exerciseID) { exercise in
                    let id = exercise.exerciseID
                    HStack {
                        NavigationLink(value: ProgramEditorPage.target(block, index, id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.exercise(id).displayName)
                                if model.exercise(id).isArchived {
                                    Text("Removed from library").font(.caption).foregroundStyle(NotebookStyle.quiet)
                                }
                                Text(ProgramPrescriptionList.target(exercise)).font(.caption).foregroundStyle(NotebookStyle.quiet)
                            }
                        }.accessibilityIdentifier("program-session-exercise-\(id)")
                        Menu {
                            if let n = units.firstIndex(where: { $0.contains(id) }) {
                                if n > 0 { Button("Move earlier") { moveUnit(n, to: n - 1) } }
                                if n + 1 < units.count { Button("Move later") { moveUnit(n, to: n + 1) } }
                            }
                            Button("Remove exercise", role: .destructive) {
                                session.supersets.removeAll { $0.exerciseIDs.contains(id) }
                                session.exercises.removeAll { $0.exerciseID == id }
                            }
                        } label: { Label("Exercise options", systemImage: "ellipsis.circle") }.labelStyle(.iconOnly).buttonStyle(.borderless)
                    }
                }
                if session.exercises.count < 30 {
                    NavigationLink(value: ProgramEditorPage.exercises(block, index)) {
                        Label("Add exercises", systemImage: "plus")
                    }.accessibilityIdentifier("program-add-exercises")
                }
            }
            if session.exercises.count >= 2 {
                Section("Supersets") {
                    ForEach(session.supersets, id: \.first) { pair in
                        NavigationLink(value: ProgramEditorPage.pair(block, index, pair.first)) {
                            VStack(alignment: .leading) {
                                Text("\(model.exercise(pair.first).displayName) + \(model.exercise(pair.second).displayName)")
                                Text("\(pair.rounds) rounds · \(pair.restSeconds)s rest").font(.caption).foregroundStyle(NotebookStyle.quiet)
                            }
                        }
                    }
                    if session.exercises.count - 2 * session.supersets.count >= 2 {
                        NavigationLink(value: ProgramEditorPage.pair(block, index, nil)) { Label("Create superset", systemImage: "link") }
                    }
                }
            }
        }.navigationTitle("Edit workout").programPageStyle()
    }

    private func moveUnit(_ from: Int, to: Int) {
        var ordered = units
        ordered.swapAt(from, to)
        let entries = Dictionary(uniqueKeysWithValues: session.exercises.map { ($0.exerciseID, $0) })
        session.exercises = ordered.flatMap { $0 }.compactMap { entries[$0] }
        session.supersets.sort { (ordered.firstIndex(of: $0.exerciseIDs) ?? 0) < (ordered.firstIndex(of: $1.exerciseIDs) ?? 0) }
    }
}

private struct ProgramExercisePicker: View {
    let model: TrainingNotebookModel
    @Binding var session: ProgramSession
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let matches = ExerciseFormGuide.search(query, in: model.exercises.filter { !$0.isArchived })
        List {
            TextField("Find exercises", text: $query)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("program-exercise-search")
            if matches.isEmpty { Text("No matching exercises").foregroundStyle(NotebookStyle.quiet) }
            ForEach(matches) { exercise in
                let exists = session.exercises.contains { $0.exerciseID == exercise.id }
                Button {
                    session.exercises.append(ProgramExercise(exerciseID: exercise.id))
                } label: {
                    HStack {
                        Text(exercise.displayName)
                        Spacer()
                        Image(systemName: exists ? "checkmark" : "plus")
                    }
                }
                .disabled(exists || session.exercises.count >= 30)
                .accessibilityLabel(exercise.displayName)
                .accessibilityValue(exists ? "Added" : "")
                .accessibilityIdentifier("program-pick-\(exercise.id)")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Add exercises")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("program-exercises-done") } }
        .programPageStyle()
    }
}

private struct ProgramTargetEditor: View {
    @Binding var target: ProgramExercise
    let name: String

    var body: some View {
        Form {
            Section("Exercise") { Text(name) }
            Section("Working sets") {
                Stepper("\(target.plan.workingSets) sets", value: $target.plan.workingSets, in: 1...30)
                Stepper("Minimum reps · \(target.plan.minimumReps)", value: $target.plan.minimumReps, in: 1...999)
                Stepper("Maximum reps · \(target.plan.maximumReps)", value: $target.plan.maximumReps, in: 1...999)
                if target.plan.minimumReps > target.plan.maximumReps {
                    Text("Maximum reps must be at least the minimum.").font(.subheadline)
                }
            }
            Section {
                Toggle("Set effort target", isOn: Binding(get: { target.targetRIR != nil }, set: { target.targetRIR = $0 ? 2 : nil }))
                if let rir = target.targetRIR {
                    Stepper("Reps in reserve · \(rir)", value: Binding(get: { target.targetRIR ?? 2 }, set: { target.targetRIR = $0 }), in: 0...5)
                }
                Toggle("Set exercise rest", isOn: Binding(get: { target.restSeconds != nil }, set: { target.restSeconds = $0 ? 60 : nil }))
                if let rest = target.restSeconds {
                    Stepper("Rest · \(rest)s", value: Binding(get: { target.restSeconds ?? 60 }, set: { target.restSeconds = $0 }), in: 0...3600, step: 15)
                }
            } header: { Text("Effort and recovery") } footer: { Text("Reps in reserve are the repetitions you could still perform at the end of a set.") }
        }.navigationTitle("Set targets").programPageStyle()
    }
}

private struct ProgramPairEditor: View {
    let model: TrainingNotebookModel
    @Binding var session: ProgramSession
    let original: SupersetPlan?
    @State private var selected: [String]
    @State private var rounds: Int
    @State private var rest: Int
    @Environment(\.dismiss) private var dismiss

    init(model: TrainingNotebookModel, session: Binding<ProgramSession>, member: String?) {
        self.model = model
        _session = session
        let pair = session.wrappedValue.supersets.first { $0.first == member }
        original = pair
        _selected = State(initialValue: pair?.exerciseIDs ?? [])
        _rounds = State(initialValue: pair?.rounds ?? 2)
        _rest = State(initialValue: pair?.restSeconds ?? 60)
    }

    var body: some View {
        let unavailable = Set(session.supersets.filter { $0 != original }.flatMap(\.exerciseIDs))
        Form {
            Section {
                ForEach(session.exercises.filter { !unavailable.contains($0.exerciseID) }, id: \.exerciseID) { exercise in
                    let id = exercise.exerciseID
                    Button {
                        if selected.contains(id) { selected.removeAll { $0 == id } } else { selected.append(id) }
                    } label: {
                        HStack {
                            Text(model.exercise(id).displayName)
                            Spacer()
                            if let i = selected.firstIndex(of: id) { Text(i == 0 ? "First" : "Second").fontWeight(.semibold) }
                        }
                    }.disabled(!selected.contains(id) && selected.count == 2)
                }
            } header: { Text("Exercises in order") } footer: { Text("Choose the first lift, then the second. They’ll sit together in the workout.") }
            Section("Rounds") {
                Stepper("\(rounds) rounds", value: $rounds, in: 1...20)
                Stepper("Rest between rounds · \(rest)s", value: $rest, in: 0...3600, step: 15)
            }
            if original != nil {
                Button("Unpair exercises", role: .destructive) { session.supersets.removeAll { $0 == original }; dismiss() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    guard selected.count == 2,
                          let second = session.exercises.first(where: { $0.exerciseID == selected[1] }) else { return }
                    var exercises = session.exercises
                    exercises.removeAll { $0.exerciseID == second.exerciseID }
                    guard let first = exercises.firstIndex(where: { $0.exerciseID == selected[0] }) else { return }
                    exercises.insert(second, at: first + 1)
                    session.exercises = exercises
                    var pairs = session.supersets.filter { $0 != original }
                    pairs.append(SupersetPlan(first: selected[0], second: selected[1], rounds: rounds, restSeconds: rest))
                    let order = exercises.map(\.exerciseID)
                    session.supersets = pairs.sorted { (order.firstIndex(of: $0.first) ?? 0) < (order.firstIndex(of: $1.first) ?? 0) }
                    dismiss()
                }.disabled(selected.count != 2)
            }
        }
        .navigationTitle("Edit superset").programPageStyle()
    }
}
