import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingWorkoutReusePicker: View {
    @Bindable private var model: TrainingNotebookModel
    private let close: () -> Void
    private let back: (() -> Void)?
    @State private var pendingReuse: PendingReuse?

    private struct PendingReuse {
        let source: TrainingDay
        let destination: TrainingDay
        let ids: [String]
        let selectedID: String?
    }

    public init(model: TrainingNotebookModel, close: @escaping () -> Void) {
        self.model = model; self.close = close; self.back = nil
    }
    init(model: TrainingNotebookModel, close: @escaping () -> Void, back: @escaping () -> Void) {
        self.model = model; self.close = close; self.back = back
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Use a previous workout").font(NotebookTypography.heading(31))
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Add missing exercises to \(model.selectedDay.map { TrainingText.date($0, format: "EEEE, MMM d") } ?? "this day") in the same order. Your current sets and unfinished entries stay in place. Recorded sets aren’t copied.")
                    .font(.callout).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("workout-reuse-explanation")
                if model.reusableWorkouts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No earlier workouts yet").font(.body.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        Text("Earlier days with recorded sets will appear here.").font(.callout).foregroundStyle(NotebookStyle.quiet)
                    }.padding(.vertical, 20).accessibilityIdentifier("workout-reuse-empty")
                } else {
                    VStack(spacing: 0) {
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                        ForEach(model.reusableWorkouts) { workout in
                            workoutRow(workout)
                            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                        }
                    }
                }
            }.padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            navigation.padding(.horizontal, 24).padding(.vertical, 4)
                .frame(maxWidth: 560).frame(maxWidth: .infinity).background(NotebookStyle.ivory)
                .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
        }
        .safeAreaInset(edge: .bottom) {
            if let error = model.errorMessage {
                TrainingSaveError(model: model, message: error, retrySucceeded: completePendingReuse)
                    .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory)
            }
        }
        .scrollIndicators(.never).accessibilityIdentifier("workout-reuse-scroll")
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
        .onChange(of: model.canRetrySave) { _, _ in completePendingReuse() }
        .onChange(of: model.errorMessage) { _, _ in completePendingReuse() }
        .onChange(of: model.selectedDay) { _, _ in pendingReuse = nil }
        .onDisappear { cancelPendingReuse() }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 470, minHeight: 568, idealHeight: 740)
        #endif
    }

    private var navigation: some View {
        HStack {
            Button {
                cancelPendingReuse(); model.dismissError()
                if let back { back() } else { close() }
            } label: {
                Label(back == nil ? "Day" : "Exercises", systemImage: "chevron.left").frame(minHeight: 44)
            }.accessibilityIdentifier("close-workout-reuse")
            Spacer()
            Button { cancelPendingReuse(); close() } label: { Text("Cancel").frame(minWidth: 44, minHeight: 44) }
                .accessibilityIdentifier("cancel-workout-reuse")
        }
    }

    private func workoutRow(_ workout: TrainingWorkoutStructure) -> some View {
        let names = workout.exerciseIDs.map { model.exercise($0).name }.joined(separator: ", ")
        let date = TrainingText.date(workout.day, format: "EEEE, MMM d, yyyy")
        return Button {
            if pendingReuse?.source == workout.day { retryPendingReuse() }
            else { reuse(workout) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(date).font(.body.weight(.semibold))
                    Text("\(workout.exerciseIDs.count) \(workout.exerciseIDs.count == 1 ? "exercise" : "exercises")")
                        .font(.caption.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    Text(names).font(.callout).foregroundStyle(NotebookStyle.quiet).fixedSize(horizontal: false, vertical: true)
                    if pendingReuse?.source == workout.day {
                        Text("Not saved yet").font(.caption).foregroundStyle(NotebookStyle.clay)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "plus").foregroundStyle(NotebookStyle.clay).padding(.top, 3)
            }.padding(.vertical, 16).frame(minHeight: 70).contentShape(Rectangle())
        }
        .accessibilityLabel("\(date), \(workout.exerciseIDs.count) exercises, \(names)")
        .accessibilityHint("Add missing exercise tabs with blank rows")
        .accessibilityIdentifier("reuse-workout-day-\(workout.day.rawValue)")
    }

    private func reuse(_ workout: TrainingWorkoutStructure) {
        cancelPendingReuse()
        guard let day = model.selectedDay else { return }
        let visible = model.workout?.exerciseIDs ?? []
        let selected = workout.exerciseIDs.first(where: { !visible.contains($0) }) ?? model.exercise?.id
        pendingReuse = PendingReuse(source: workout.day, destination: day, ids: workout.exerciseIDs, selectedID: selected)
        if model.reuseWorkout(from: workout.day) { completePendingReuse() }
        else if !model.canRetrySave { pendingReuse = nil }
    }
    private func retryPendingReuse() {
        if model.canRetrySave, model.retrySave() { completePendingReuse() }
    }
    private func completePendingReuse() {
        guard let request = pendingReuse, model.selectedDay == request.destination, model.errorMessage == nil, !model.canRetrySave,
              request.ids.allSatisfy({ model.workout?.exerciseIDs.contains($0) == true }),
              model.exercise?.id == request.selectedID else { return }
        pendingReuse = nil; close()
    }
    private func cancelPendingReuse() {
        guard pendingReuse != nil else { return }
        pendingReuse = nil; _ = model.cancelPendingAction()
    }
}
