import SwiftUI
import SendaDomain
import SendaLogger

struct TrainerNavigationRow: View {
    let title: String
    var detail: String? = nil
    var value: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(NotebookStyle.ink)
                if let detail { Text(detail).font(.subheadline).foregroundStyle(NotebookStyle.quiet) }
            }
            Spacer(minLength: 8)
            if let value { Text(value).monospacedDigit().foregroundStyle(NotebookStyle.quiet) }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(NotebookStyle.quiet)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44).padding(.vertical, 5).contentShape(Rectangle())
    }
}

struct TrainerDirectory: View {
    let model: TrainingNotebookModel
    let close: () -> Void
    @State private var review = false
    @State private var selectedPage: TrainerPage?
    @State private var selectedWorkout: WorkoutTemplate?

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if selectedWorkout != nil { selectedWorkout = nil }
                else if selectedPage != nil { selectedPage = nil }
                else { close() }
            } label: {
                Label(selectedWorkout != nil ? selectedPage?.name ?? "Trainer" : (selectedPage != nil ? "Trainers" : "Workouts"),
                      systemImage: "chevron.left")
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: 560, alignment: .leading).padding(.horizontal, 24)
            .frame(maxWidth: .infinity).foregroundStyle(NotebookStyle.clay)
            if let page = selectedPage {
                if let workout = selectedWorkout, let index = page.workouts.firstIndex(where: { $0.id == workout.id }) {
                    TrainerWorkoutPreview(model: model, page: page, workout: workout, index: index)
                } else {
                    TrainerReader(model: model, page: page, openWorkout: { selectedWorkout = $0 })
                }
            } else {
                directory
            }
        }.buttonStyle(.plain).tint(NotebookStyle.clay).background(NotebookStyle.ivory)
    }

    private var directory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Trainers").font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                let page = model.sampleTrainer
                Button { selectedPage = page } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        TrainerPortrait()
                        TrainerNavigationRow(title: page.name, detail: page.bio)
                        Text("Sample trainer · 3 workouts").font(.caption).foregroundStyle(NotebookStyle.quiet)
                    }
                }
                .accessibilityIdentifier("trainer-maya")
                if let local = model.profile.details.trainerApplication?.listing(on: model.today) {
                    WorkoutLibraryRule()
                    Button { selectedPage = local } label: {
                        TrainerNavigationRow(title: local.name, detail: local.offersProgram ? local.programTitle : "\(local.workouts.count) workouts", value: "Local")
                    }
                }
                #if DEBUG
                if let application = model.profile.details.trainerApplication, application.locallyApproved != true {
                    Button("Review local application") { review = true }
                        .foregroundStyle(NotebookStyle.clay).frame(minHeight: 44)
                        .alert("Approve this local demo application?", isPresented: $review) {
                            Button("Approve on this device") {
                                var reviewed = application
                                reviewed.locallyApproved = true
                                model.profile.saveTrainerApplication(reviewed)
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This simulates a reviewer’s approval. It applies only on this device and does not verify a real certification.")
                        }
                    if let error = model.profile.errorMessage { Text(error).font(.footnote) }
                }
                #endif
            }.trainerMargins()
        }

    }
}

private struct TrainerPortrait: View {
    var body: some View {
        if let portrait = ExerciseArtwork.image(named: "maya-ellis-sample") {
            Image(decorative: portrait, scale: 1).resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
        }
    }
}

struct TrainerReader: View {
    let model: TrainingNotebookModel
    let page: TrainerPage
    var isDraft = false
    var openWorkout: ((WorkoutTemplate) -> Void)? = nil
    @State private var info: String?
    private var sample: Bool { page.id == TrainerPage.sample.id }
    @State private var scheduling = false
    private var programID: String { (page.publicationID ?? page.id).uuidString.lowercased() }
    private var saved: Bool { model.customPrograms.contains { $0.id == programID } }
    private var hasEarlierProgram: Bool {
        model.customPrograms.contains { $0.trainerPageID == page.id || $0.id == page.id.uuidString.lowercased() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if sample { TrainerPortrait() }
                VStack(alignment: .leading, spacing: 3) {
                    Text(page.name).font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                    Button {
                        info = sample ? "Maya Ellis is a fictional trainer. The credential and workouts illustrate a trainer page."
                                      : "This page is a local preview. Senda has not verified this credential."
                    } label: {
                        Label(page.credential, systemImage: "info.circle").font(.subheadline.weight(.medium))
                            .frame(minHeight: 44, alignment: .leading)
                    }.accessibilityHint("Credential information")
                    Text(page.bio)
                }
                WorkoutLibraryRule()
                VStack(alignment: .leading, spacing: 5) {
                    Text(page.offersProgram ? page.programTitle : "Workouts").font(NotebookTypography.heading(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                    if page.offersProgram {
                        Text("\(page.weeks) weeks · \(page.workouts.count) days a week")
                            .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    }
                    if let version = page.version, version > 1 {
                        Text("Version \(version)").font(.caption).foregroundStyle(NotebookStyle.quiet)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(Array(page.workouts.enumerated()), id: \.element.id) { index, workout in
                        let row = TrainerNavigationRow(title: workout.name,
                            value: workout.trainerDetails?.minutes.map { "\($0) min" } ?? "\(workout.exerciseIDs.count) exercises")
                        Group {
                            if let openWorkout { Button { openWorkout(workout) } label: { row } }
                            else {
                                NavigationLink { TrainerWorkoutPreview(model: model, page: page, workout: workout, index: index, isDraft: isDraft) }
                                    label: { row }
                            }
                        }.accessibilityIdentifier("trainer-workout-\(index)")
                        WorkoutLibraryRule()
                    }
                }
                if !isDraft && page.offersProgram {
                    if saved {
                        RecordButton(title: "Choose start date") { scheduling = true }
                            .accessibilityIdentifier("schedule-trainer-program")
                    } else {
                        RecordButton(title: hasEarlierProgram ? "Save new version" : "Save program") {
                            model.saveTrainerProgram(page)
                        }.accessibilityIdentifier("save-trainer-program")
                    }
                }
                if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
                if sample || !page.instagram.isEmpty || !page.website.isEmpty {
                    HStack(spacing: 22) {
                        externalLink("Instagram", address: page.instagram)
                        externalLink("Coaching website", address: page.website)
                    }
                    Text("You arrange coaching and payment directly with the trainer.")
                        .font(.footnote).foregroundStyle(NotebookStyle.quiet)
                }
                TrainerGuidance()
            }.trainerMargins()
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .buttonStyle(.plain).tint(NotebookStyle.clay)
        .sheet(isPresented: $scheduling) {
            TrainingProgramLibrary(model: model, savedOnly: true, initialProgramID: programID)
        }
        .alert("Trainer information", isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) {
            Button("Done") { info = nil }
        } message: { Text(info ?? "") }
    }

    @ViewBuilder private func externalLink(_ title: String, address: String) -> some View {
        let label = Label(title, systemImage: "arrow.up.right").font(.subheadline.weight(.medium))
            .foregroundStyle(NotebookStyle.clay).frame(minHeight: 44)
        if let url = URL(string: address), !address.isEmpty { Link(destination: url) { label } }
        else if sample { Button { info = "This sample trainer has no external account. Trainers can add their own links to their page." } label: { label } }
    }
}

private struct TrainerWorkoutPreview: View {
    let model: TrainingNotebookModel
    let page: TrainerPage
    let workout: WorkoutTemplate
    let index: Int
    var isDraft = false
    @State private var viewingSaved = false
    private var saved: WorkoutTemplate? { model.savedWorkouts.first { $0.id == workout.id } }
    private var hasEarlierWorkout: Bool {
        guard let origin = workout.trainerOriginID else { return false }
        return model.savedWorkouts.contains { $0.id == origin || $0.trainerOriginID == origin }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(workout.name).font(NotebookTypography.heading(34)).accessibilityAddTraits(.isHeader)
                if page.offersProgram { Text("\(page.programTitle) · Day \(index + 1)").font(.headline) }
                TrainerWorkoutNotes(details: workout.trainerDetails)
                WorkoutLibraryRule()
                Text("Exercises").font(NotebookTypography.heading(24, relativeTo: .title2))
                VStack(spacing: 0) {
                    ForEach(workout.exerciseIDs, id: \.self) { id in
                        let plan = workout.exercisePlans[id]
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(model.exercise(id).displayName).font(.body.weight(.medium))
                            Spacer(minLength: 0)
                            if let plan {
                                Text(ProgramPrescriptionList.target(ProgramExercise(exerciseID: id, plan: plan)))
                                    .monospacedDigit().fixedSize(horizontal: true, vertical: false)
                            }
                        }.frame(minHeight: 48)
                        WorkoutLibraryRule()
                    }
                }
                TrainerGuidance()
            }.trainerMargins()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 7) {
                if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
                if !isDraft {
                    if let saved {
                        RecordButton(title: "Use today") {
                            if model.applyWorkout(saved, on: model.today) { model.selectSection(.log) }
                        }.accessibilityIdentifier("use-trainer-workout-today")
                        Button("View saved workout") { viewingSaved = true }.frame(minHeight: 44)
                    } else {
                        RecordButton(title: hasEarlierWorkout ? "Save new version" : "Save workout") {
                            model.saveTrainerWorkout(workout, from: page)
                        }.accessibilityIdentifier("save-trainer-workout")
                    }
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 10).frame(maxWidth: 560)
            .frame(maxWidth: .infinity).background(NotebookStyle.ivory)
        }
        .sheet(isPresented: $viewingSaved) {
            if let saved {
                TrainingWorkoutLibrary(model: model, destinationDay: model.today, initialTab: .personal,
                    initialWorkout: saved, close: { viewingSaved = false })
            }
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
    }
}

struct TrainerWorkoutNotes: View {
    let details: TrainerWorkoutDetails?

    var body: some View {
        if let details {
            let summary = [details.minutes.map { "\($0) min" }, details.equipment].compactMap { $0 }
                .filter { !$0.isEmpty }.joined(separator: " · ")
            if !summary.isEmpty { Text(summary).font(.subheadline).foregroundStyle(NotebookStyle.quiet) }
            if !details.notes.isEmpty { Text(details.notes).font(.body.italic()) }
        }
    }
}

private struct TrainerGuidance: View {
    var body: some View {
        DisclosureGroup("Training guidance") {
            Text("These workouts offer general fitness guidance. The trainer hasn’t assessed your individual needs. If you have an injury or medical condition, ask a qualified healthcare professional whether this program is appropriate for you.")
                .font(.footnote).padding(.vertical, 5)
        }.font(.subheadline).foregroundStyle(NotebookStyle.quiet).frame(minHeight: 44)
    }
}

extension View {
    fileprivate func trainerMargins() -> some View {
        padding(.horizontal, 24).padding(.vertical, 12)
            .frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
    }
}
