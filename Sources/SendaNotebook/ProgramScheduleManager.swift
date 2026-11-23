import SwiftUI
import SendaDomain
import SendaLogger

struct ProgramScheduleManager: View {
    @Bindable var model: TrainingNotebookModel
    let enrollment: ProgramEnrollment
    let openWeek: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var review: Review?
    @State private var firstDate: Date
    @State private var applied: ProgramScheduleChange?
    @State private var problem: String?
    @State private var hasPendingWrite = false

    private enum Review { case move, end }

    init(model: TrainingNotebookModel, enrollment: ProgramEnrollment, openWeek: @escaping () -> Void) {
        self.model = model
        self.enrollment = enrollment
        self.openWeek = openWeek
        _firstDate = State(initialValue: model.today.date(in: model.calendar))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let applied { receipt(applied) }
                else if let review {
                    let day = TrainingDay(firstDate, calendar: model.calendar)
                    let action: ProgramScheduleAction = review == .move ? .move(firstDay: day) : .end
                    let preview = Result { try model.previewScheduleChange(enrollment, action: action) }
                    reviewPage(review, preview: preview)
                } else { overview }
            }
            .programPageStyle()
            .navigationTitle(review == .move ? "Move workouts" : review == .end ? "End program" : "Manage schedule")
            .toolbar {
                if review != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") { cancelPending(); review = nil }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .environment(\.calendar, model.calendar)
        .environment(\.timeZone, model.calendar.timeZone)
        .tint(NotebookStyle.clay)
        .onDisappear { cancelPending() }
    }

    private var overview: some View {
        let dates = model.scheduledWorkoutDates(enrollment)
        let remaining = try? model.previewScheduleChange(enrollment, action: .end).changes
        return List {
            Section {
                Button {
                    let day = dates.first { $0 >= model.today } ?? dates.last ?? enrollment.start
                    if model.showWeek(containing: day), model.selectSection(.log) { openWeek() } else { showError() }
                } label: { Label("View in Train", systemImage: "calendar") }
                .accessibilityIdentifier("managed-view-week")
                Button {
                    guard let first = remaining?.first?.day else { return }
                    firstDate = first.date(in: model.calendar)
                    review = .move
                } label: { Label("Move remaining workouts", systemImage: "calendar.day.timeline.left") }
                .disabled(remaining?.isEmpty != false)
                .accessibilityIdentifier("managed-move")
                Button(role: .destructive) { review = .end } label: { Label("End program", systemImage: "calendar.badge.minus") }
                    .accessibilityIdentifier("managed-end")
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(enrollment.program.title).font(NotebookTypography.heading(22)).foregroundStyle(NotebookStyle.ink)
                    Text("Started " + date(enrollment.start)).font(.subheadline)
                }.textCase(nil).padding(.bottom, 6)
            } footer: { Text("Schedule changes apply to untouched workouts from today onward.") }
            errorRow
        }
    }

    private func reviewPage(_ review: Review, preview: Result<ProgramScheduleChange, any Error>) -> some View {
        List {
            if review == .move {
                Section {
                    DatePicker("First remaining workout", selection: $firstDate,
                               in: model.calendar.startOfDay(for: model.today.date(in: model.calendar))..., displayedComponents: .date)
                        .accessibilityIdentifier("managed-first-date")
                        .onChange(of: firstDate) { _, _ in cancelPending() }
                } footer: { Text("The other workouts move by the same number of days.") }
            }
            switch preview {
            case let .failure(error):
                Text(error.localizedDescription)
            case let .success(change):
                if !change.conflicts.isEmpty {
                    Section {
                        ForEach(change.conflicts, id: \.self) { Text(date($0)) }
                    } header: { Text("Dates already in use") } footer: { Text("Choose a different first date to keep both workouts.") }
                }
                Section {
                    if change.changes.isEmpty { Text("No untouched workouts remain.") }
                    ForEach(change.changes) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title).font(.body.weight(.medium))
                            Text(entry.destination.map { "\(date(entry.day)) → \(date($0))" } ?? date(entry.day))
                                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        }.accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("\(change.changes.count) \(change.changes.count == 1 ? "workout" : "workouts") to \(review == .move ? "move" : "remove")")
                }
                if !change.preserved.isEmpty {
                    Section {
                        DisclosureGroup("Staying on Week (\(change.preserved.count))") {
                            ForEach(change.preserved) { entry in
                                VStack(alignment: .leading) {
                                    Text(entry.title)
                                    Text(date(entry.day)).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                                }.accessibilityElement(children: .combine)
                            }
                        }
                    } footer: { Text("Past, edited and logged workouts keep their dates.") }
                }
            }
            errorRow
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if case let .success(change) = preview {
                Button(role: review == .end ? .destructive : nil) {
                    if model.applyScheduleChange(change) {
                        cancelPending()
                        self.review = nil
                        applied = change
                    } else { showError() }
                } label: {
                    Text(review == .end ? "End program" : "Move \(change.changes.count) \(change.changes.count == 1 ? "workout" : "workouts")")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(review == .end ? .red : NotebookStyle.primaryFill)
                .disabled(!change.canApply)
                .accessibilityIdentifier("managed-apply")
                .padding(.horizontal).padding(.vertical, 8)
                .background(NotebookStyle.ivory)
            }
        }
    }

    private func receipt(_ change: ProgramScheduleChange) -> some View {
        List {
            Section {
                Text(change.action == .end ? "Schedule ended" : "Workouts moved").font(.headline)
                if change.action == .end {
                    Text("\(change.changes.count) \(change.changes.count == 1 ? "workout removed" : "workouts removed") from Week.")
                } else if let day = change.changes.first?.destination {
                    Text("First moved workout · \(date(day))")
                }
                Button("Undo") {
                    if model.undoScheduleChange(change) { cancelPending(); applied = nil } else { showError() }
                }.accessibilityIdentifier("managed-undo")
            }
            errorRow
        }
    }

    @ViewBuilder private var errorRow: some View {
        if let problem { Section { Text(problem).font(.callout) } }
    }

    private func date(_ day: TrainingDay) -> String { TrainingText.date(day, format: "EEE, MMM d, yyyy") }

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
