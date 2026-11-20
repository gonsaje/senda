import SwiftUI
import UniformTypeIdentifiers
import SendaDomain
import SendaLogger

struct TrainingProgramLibrary: View {
    @Bindable var model: TrainingNotebookModel
    @Environment(\.dismiss) private var dismiss
    @State private var path: [String] = []
    @State private var editor: TrainingProgram?
    @State private var importing = false
    @State private var export: ProgramDocument?
    @State private var exporting = false
    @State private var filename = "Training program"
    @State private var message: String?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                let enrollments = model.workspace.activeProgramEnrollments.sorted { $0.start > $1.start }
                if !enrollments.isEmpty {
                    Section("On Week") {
                        ForEach(Array(enrollments.enumerated()), id: \.offset) { _, enrollment in
                            Button {
                                let days = model.workspace.days.compactMap { date, workout -> TrainingDay? in
                                    guard let session = workout.programSession, session.programID == enrollment.programID,
                                          session.start == enrollment.start else { return nil }
                                    return TrainingDay(rawValue: date)
                                }.sorted()
                                let next = days.first { $0 >= model.today } ?? days.last ?? enrollment.start
                                if model.showWeek(containing: next), model.selectSection(.log) { dismiss() }
                                else { message = model.errorMessage }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(enrollment.program.title).font(.body.weight(.semibold))
                                        Text("Start · " + TrainingText.date(enrollment.start, format: "MMM d, yyyy"))
                                            .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                                    }
                                    Spacer()
                                    Image(systemName: "calendar").foregroundStyle(NotebookStyle.clay)
                                }.frame(minHeight: 44)
                            }.accessibilityHint("Open the scheduled workout week")
                        }
                    }
                }
                Section("Curated programs") {
                    ForEach(model.programs.filter { program in TrainingProgram.catalog.contains { $0.id == program.id } }) { program in programLink(program) }
                }
                Section("My programs") {
                    ForEach(model.customPrograms) { program in programLink(program) }
                    Button { editor = TrainingProgram(title: "", blocks: []) } label: {
                        Label("Create program", systemImage: "plus")
                    }.accessibilityIdentifier("create-training-program")
                    Button { importing = true } label: {
                        Label("Import program", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .programPageStyle()
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .navigationDestination(for: String.self) { id in
                if let program = model.programs.first(where: { $0.id == id }) {
                    ProgramDetail(model: model, program: program, edit: { editor = $0 },
                        share: share, deleted: { path = [] }, openWeek: { dismiss() })
                }
            }
        }
        .tint(NotebookStyle.clay)
        .sheet(item: $editor) { original in
            TrainingProgramEditor(model: model, original: original) { saved in
                editor = nil
                if let saved { path = [saved.id] }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let limit = TrainingProgram.maximumImportBytes
                let data = try handle.read(upToCount: limit + 1) ?? Data()
                guard data.count <= limit else { throw ProgramError.fileTooLarge }
                path = [try model.importProgram(data).id]
            } catch where (error as NSError).code == NSUserCancelledError {
            } catch { message = error.localizedDescription }
        }
        .fileExporter(isPresented: $exporting, document: export, contentType: .json, defaultFilename: filename) { result in
            if case let .failure(error) = result { message = error.localizedDescription }
            export = nil
        }
        .alert("Program file", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func programLink(_ program: TrainingProgram) -> some View {
        NavigationLink(value: program.id) {
            VStack(alignment: .leading, spacing: 4) {
                Text(program.title).font(.body.weight(.semibold))
                Text("\(program.weeks) weeks · \(program.blocks.count == 1 ? "Standalone block" : "\(program.blocks.count) blocks")")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                HStack(spacing: 4) {
                    ForEach(program.blocks.indices, id: \.self) { index in
                        HStack(spacing: 1) {
                            ForEach(0..<program.blocks[index].weeks, id: \.self) { _ in
                                Capsule().fill(NotebookStyle.clay.opacity(index.isMultiple(of: 2) ? 0.75 : 0.35))
                                    .frame(maxWidth: 8, minHeight: 3, maxHeight: 3)
                            }
                        }
                    }
                }.frame(maxWidth: 180, alignment: .leading).accessibilityHidden(true)
            }.padding(.vertical, 4)
        }.accessibilityIdentifier("program-\(program.id)")
    }

    private func share(_ program: TrainingProgram) {
        do {
            export = ProgramDocument(data: try model.exportProgram(program))
            filename = program.title
            exporting = true
        } catch { message = error.localizedDescription }
    }
}

private struct ProgramDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

extension View {
    func programPageStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(NotebookStyle.ivory)
            .foregroundStyle(NotebookStyle.ink)
            .tint(NotebookStyle.clay)
            .buttonStyle(.automatic)
    }
}

private struct ProgramDetail: View {
    @Bindable var model: TrainingNotebookModel
    let program: TrainingProgram
    let edit: (TrainingProgram) -> Void
    let share: (TrainingProgram) -> Void
    let deleted: () -> Void
    let openWeek: () -> Void
    @State private var start: Date
    @State private var week = 1
    @State private var confirmDelete = false
    @State private var problem: String?
    @State private var hasPendingWrite = false

    init(model: TrainingNotebookModel, program: TrainingProgram, edit: @escaping (TrainingProgram) -> Void,
         share: @escaping (TrainingProgram) -> Void, deleted: @escaping () -> Void, openWeek: @escaping () -> Void) {
        self.model = model
        self.program = program
        self.edit = edit
        self.share = share
        self.deleted = deleted
        self.openWeek = openWeek
        _start = State(initialValue: model.today.date(in: model.calendar))
    }

    private var startDay: TrainingDay { TrainingDay(start, calendar: model.calendar) }
    private var personal: Bool { model.customPrograms.contains { $0.id == program.id } }
    private var displayed: TrainingProgram { model.scheduledProgram(program, starting: startDay) ?? program }
    private var blockIndex: Int {
        var endWeek = 0
        return displayed.blocks.firstIndex { block in endWeek += block.weeks; return week <= endWeek } ?? 0
    }

    var body: some View {
        let preview = Result { try model.previewProgram(program, starting: startDay) }
        let slots = (try? preview.get()) ?? []
        let free = slots.filter { !$0.isOccupied && !$0.isScheduled }.count
        let busy = slots.filter { $0.isOccupied && !$0.isScheduled }.count
        let scheduled = model.isProgramScheduled(program, starting: startDay)
        let unavailable = model.unavailableProgramExercises(program)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(displayed.title).font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                Text("\(displayed.weeks) weeks · \(displayed.blocks.count) \(displayed.blocks.count == 1 ? "block" : "blocks")")
                    .foregroundStyle(NotebookStyle.quiet)
                if !displayed.summary.isEmpty { Text(displayed.summary) }
                if scheduled && displayed != program {
                    Text("Showing the version scheduled for this start date.").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }
                DatePicker("Start date", selection: $start, displayedComponents: .date)
                    .accessibilityIdentifier("program-start-date")
                Text(displayed.blocks.count > 1 ? "Training blocks" : "Weekly schedule")
                    .font(NotebookTypography.heading(21, relativeTo: .headline))
                    .accessibilityAddTraits(.isHeader)
                if displayed.blocks.count > 1 {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(displayed.blocks.indices, id: \.self) { i in
                                Button {
                                    week = 1 + displayed.blocks.prefix(i).reduce(0) { $0 + $1.weeks }
                                } label: {
                                    Text(displayed.blocks[i].title).font(.subheadline.weight(i == blockIndex ? .bold : .regular))
                                        .padding(.horizontal, 12).frame(minHeight: 44)
                                        .background(i == blockIndex ? NotebookStyle.todayFill : .clear, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(i == blockIndex ? .isSelected : [])
                            }
                        }
                    }.scrollIndicators(.hidden)
                }
                Picker("Week preview", selection: $week) {
                    ForEach(1...max(1, displayed.weeks), id: \.self) { n in Text("Week \(n)").tag(n) }
                }.pickerStyle(.menu).accessibilityIdentifier("program-week-preview")
                if displayed.blocks.indices.contains(blockIndex), !displayed.blocks[blockIndex].progression.isEmpty {
                    Text(displayed.blocks[blockIndex].progression).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }
                ForEach(slots.filter { $0.week == week }, id: \.day) { slot in
                    WorkoutLibraryRule()
                    DisclosureGroup {
                        ProgramPrescriptionList(exercises: slot.session.exercises, pairs: slot.session.supersets, model: model)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(spacing: 0) {
                                Text(TrainingText.date(slot.day, format: "EEE")).font(.caption)
                                Text(TrainingText.date(slot.day, format: "d")).font(NotebookTypography.heading(23))
                            }.frame(minWidth: 38).foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot.session.title).font(.body.weight(.semibold)).foregroundStyle(NotebookStyle.ink)
                                Text(TrainingText.date(slot.day, format: "MMM d") +
                                     (slot.isScheduled ? " · Scheduled" : slot.isOccupied ? " · Already occupied" : ""))
                                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                            }
                        }.frame(minHeight: 44, alignment: .leading)
                    }
                }
                ProgramAttribution(program: displayed)
                if case let .failure(error) = preview { Text(error.localizedDescription).font(.callout) }
                if busy > 0 && !scheduled {
                    Text(free == 0 ? "Every date already has a workout. Choose a different start date."
                         : "\(busy) occupied \(busy == 1 ? "date will" : "dates will") be skipped.").font(.subheadline)
                }
                if !unavailable.isEmpty && !scheduled {
                    Text("Replace these removed exercises before scheduling. " + unavailable.map(\.displayName).joined(separator: ", "))
                        .font(.callout)
                }
                if let problem { Text(problem).font(.callout) }
                Button {
                    if !scheduled && !model.scheduleProgram(program, starting: startDay) { showError(); return }
                    if model.showWeek(containing: startDay), model.selectSection(.log) { openWeek() }
                    else { showError() }
                } label: {
                    Text(scheduled ? "View on Week" : "Schedule \(free) \(free == 1 ? "workout" : "workouts")")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent).tint(NotebookStyle.primaryFill).foregroundStyle(NotebookStyle.onPrimary)
                .disabled(!scheduled && (free == 0 || !unavailable.isEmpty))
                .accessibilityIdentifier("schedule-program")
            }
            .frame(maxWidth: 520, alignment: .leading).padding(20).frame(maxWidth: .infinity)
        }
        .programPageStyle()
        .environment(\.calendar, model.calendar)
        .environment(\.timeZone, model.calendar.timeZone)
        .onChange(of: start) { _, _ in cancelPending() }
        .onChange(of: displayed) { _, updated in week = min(week, max(1, updated.weeks)) }
        .onDisappear { cancelPending() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if personal {
                        Button("Edit program") { edit(program) }
                    }
                    Button("Save a copy") { edit(program.copyForEditing()) }
                    Button("Export program") { share(program) }
                    if personal {
                        Button("Delete program", role: .destructive) { confirmDelete = true }
                    }
                } label: { Label("Program options", systemImage: "ellipsis.circle") }
                .accessibilityIdentifier("program-options")
            }
        }
        .confirmationDialog("Delete this program?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete program", role: .destructive) {
                if model.deleteProgram(id: program.id) { deleted() } else { showError() }
            }
        } message: { Text("Workouts already on Week will stay there.") }
    }

    private func showError() {
        hasPendingWrite = model.canRetrySave
        problem = model.errorMessage ?? "The change couldn’t be saved. Try again."
    }
    private func cancelPending() {
        if hasPendingWrite && model.canRetrySave { _ = model.cancelPendingAction() }
        hasPendingWrite = false
        problem = nil
    }
}

private struct ProgramAttribution: View {
    let program: TrainingProgram
    var body: some View {
        if program.author != nil || program.credential != nil || program.sourceURL != nil || program.coachingNotes != nil {
            DisclosureGroup("Coaching notes and sources") {
                VStack(alignment: .leading, spacing: 6) {
                    if let author = program.author { Text("Author · \(author)") }
                    if let credential = program.credential { Text("Author-provided credentials · \(credential)") }
                    if let notes = program.coachingNotes { Text(notes) }
                    ProgramSourceLink(source: program.sourceURL)
                }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
            }
        }
    }
}

private struct ProgramSourceLink: View {
    let source: String?
    var body: some View {
        if let source, let url = URL(string: source), let host = url.host,
           ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            Link("Programming reference · " + host, destination: url)
        }
    }
}

struct ScheduledProgramContext: View {
    let session: ScheduledProgramSession
    let model: TrainingNotebookModel
    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(session.sessionTitle) · \(session.blockTitle)")
                if !session.progression.isEmpty { Text(session.progression) }
                if let author = session.author { Text("Author · " + author) }
                if let credential = session.credential { Text("Author-provided credentials · " + credential) }
                if let notes = session.coachingNotes { Text(notes) }
                ProgramSourceLink(source: session.sourceURL)
                ForEach(session.exercises, id: \.exerciseID) { entry in
                    Text("\(model.exercise(entry.exerciseID).displayName) · \(ProgramPrescriptionList.target(entry))")
                }
            }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("\(session.programTitle) · Week \(session.week)")
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }.accessibilityIdentifier("scheduled-program-context")
    }
}

struct ProgramPrescriptionList: View {
    let exercises: [ProgramExercise]
    let pairs: [SupersetPlan]
    let model: TrainingNotebookModel

    static func target(_ item: ProgramExercise) -> String {
        let p = item.plan
        let reps = p.minimumReps == p.maximumReps ? String(p.minimumReps) : "\(p.minimumReps)–\(p.maximumReps)"
        var result = "\(p.workingSets) × \(reps)"
        if let rir = item.targetRIR { result += " · \(rir) RIR" }
        if let rest = item.restSeconds { result += " · \(rest)s rest" }
        return result
    }

    var body: some View {
        let pairsByFirst = Dictionary(uniqueKeysWithValues: pairs.map { ($0.first, $0) })
        let orderedPairs = exercises.compactMap { pairsByFirst[$0.exerciseID] }
        VStack(alignment: .leading, spacing: 8) {
            ForEach(exercises, id: \.exerciseID) { item in
                let pair = orderedPairs.firstIndex { $0.first == item.exerciseID || $0.second == item.exerciseID }
                VStack(alignment: .leading, spacing: 2) {
                    let prefix = pair.map { SupersetMembership.letter(at: $0) + (orderedPairs[$0].first == item.exerciseID ? "1" : "2") + " · " } ?? ""
                    Text(prefix + model.exercise(item.exerciseID).displayName)
                        .fontWeight(.medium)
                    Text(Self.target(item)).foregroundStyle(NotebookStyle.quiet)
                    if let pair, orderedPairs[pair].first == item.exerciseID {
                        Text("\(orderedPairs[pair].rounds) rounds · \(orderedPairs[pair].restSeconds)s between rounds")
                            .foregroundStyle(NotebookStyle.quiet)
                    }
                }
            }
        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
    }
}
