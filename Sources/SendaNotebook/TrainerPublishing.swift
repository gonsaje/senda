import SwiftUI
import SendaDomain
import SendaLogger

struct LocalTrainerPublishing: View {
    let model: TrainingNotebookModel
    @State private var name: String
    @State private var certification = ""
    @State private var number = ""
    @State private var expiry = Date()
    @State private var message: String?

    init(model: TrainingNotebookModel) {
        self.model = model
        _name = State(initialValue: model.profile.details.name)
    }

    var body: some View {
        Form {
            if let application = model.profile.details.trainerApplication {
                Section("Application saved on this device") {
                    Text(application.name)
                    Text(application.credential).foregroundStyle(NotebookStyle.quiet)
                    Text(application.locallyApproved == true ? "Approved for the on-device preview." : "Awaiting local preview approval.")
                        .font(.subheadline)
                }
                Section("Local publishing preview") {
                    NavigationLink(application.preview == nil ? "Build trainer page" : "Edit trainer page") {
                        TrainerPageEditor(model: model, application: application)
                    }
                    if let page = application.preview {
                        NavigationLink("Preview draft") { TrainerReader(model: model, page: page, isDraft: true) }
                        if application.locallyApproved == true && application.expires >= model.today {
                            if application.listedOnDevice != true || page != application.published {
                                Button(application.published == nil ? "Publish to local directory" : "Publish update") {
                                    var updated = application
                                    do {
                                        try updated.publish(on: model.today, availableExercises: Set(model.activeExercises.map(\.id)))
                                        message = model.profile.saveTrainerApplication(updated) ? nil : model.profile.errorMessage
                                    } catch { message = error.localizedDescription }
                                }
                            }
                        }
                        if application.listedOnDevice == true {
                            Button("Remove from local directory") {
                                var updated = application
                                updated.listedOnDevice = false
                                message = model.profile.saveTrainerApplication(updated) ? nil : model.profile.errorMessage
                            }
                        }
                    }
                }
            } else {
                Section("Certification") {
                    TextField("Name on credential", text: $name)
                    TextField("Certification and issuer", text: $certification)
                    TextField("Credential number", text: $number)
                    DatePicker("Expiration", selection: $expiry, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                }
                Section {
                    Button("Save application locally") {
                        let form = TrainerApplication(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            credential: certification.trimmingCharacters(in: .whitespacesAndNewlines),
                            credentialID: number.trimmingCharacters(in: .whitespacesAndNewlines), expires: TrainingDay(expiry))
                        message = model.profile.saveTrainerApplication(form) ? nil : model.profile.errorMessage
                    }.disabled(name.isEmpty || certification.isEmpty || number.isEmpty)
                } footer: {
                    Text("Use sample credential details for this local version. The application stays on this device.")
                }
            }
            if let message { Text(message).foregroundStyle(NotebookStyle.clay) }
        }.formStyle(.grouped).programPageStyle()
            .navigationTitle("Local trainer preview")
    }
}

private struct TrainerPageEditor: View {
    let model: TrainingNotebookModel
    let application: TrainerApplication
    @State private var page: TrainerPage
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(model: TrainingNotebookModel, application: TrainerApplication) {
        self.model = model
        self.application = application
        _page = State(initialValue: application.preview ?? TrainerPage(name: application.name, credential: application.credential))
    }

    var body: some View {
        Form {
            Section("Trainer profile") {
                TextField("Display name", text: $page.name)
                TextField("Who do you coach?", text: $page.bio, axis: .vertical)
                TextField("Instagram URL (optional)", text: $page.instagram)
                TextField("Coaching website URL (optional)", text: $page.website)
            }
            Section("Program") {
                Toggle("Group into a program", isOn: Binding(get: { page.offersProgram }, set: { page.groupsIntoProgram = $0 }))
                if page.offersProgram {
                    TextField("Program name", text: $page.programTitle)
                    Stepper("\(page.weeks) weeks", value: $page.weeks, in: 1...12)
                }
            }
            Section("Workouts · \(page.workouts.count) of 5") {
                ForEach(Array(page.workouts.enumerated()), id: \.element.id) { index, workout in
                    HStack {
                        NavigationLink {
                            TrainerWorkoutEditor(model: model, workout: Binding(get: {
                                page.workouts.first { $0.id == workout.id } ?? workout
                            }, set: { edited in
                                if let i = page.workouts.firstIndex(where: { $0.id == workout.id }) { page.workouts[i] = edited }
                            }))
                        } label: {
                            VStack(alignment: .leading) {
                                Text("\(index + 1). \(workout.name)")
                                if workout.exercisePlans.count < workout.exerciseIDs.count {
                                    Text("Set targets needed").font(.caption).foregroundStyle(NotebookStyle.clay)
                                }
                            }
                        }
                        Spacer()
                        Button { page.workouts.removeAll { $0.id == workout.id } } label: {
                            Image(systemName: "minus.circle").frame(width: 44, height: 44)
                        }.buttonStyle(.borderless).accessibilityLabel("Remove " + workout.name)
                    }
                }
                if page.workouts.count < 5 {
                    Menu("Add workout") {
                        ForEach(available) { source in
                            Button(source.name) {
                                page.workouts.append(WorkoutTemplate(name: source.name, exerciseIDs: source.exerciseIDs,
                                    exercisePlans: source.exercisePlans, supersets: source.supersets))
                            }
                        }
                    }
                }
            }
            Section {
                Button("Save draft") {
                    var edited = model.profile.details.trainerApplication ?? application
                    edited.preview = page
                    if model.profile.saveTrainerApplication(edited) { dismiss() }
                    else { error = model.profile.errorMessage }
                }
                if let error { Text(error).foregroundStyle(NotebookStyle.clay) }
            } footer: {
                Text("Publish when three to five workouts have set and rep targets. Your draft stays private until you publish.")
            }
        }
        .formStyle(.grouped).programPageStyle().navigationTitle("Edit trainer page")
    }

    private var available: [WorkoutTemplate] {
        let names = Set(page.workouts.map { $0.name.lowercased() })
        return (model.savedWorkouts + model.starterWorkouts).filter {
            $0.trainerCredit == nil && !names.contains($0.name.lowercased()) && $0.exerciseIDs.count <= 30
        }
    }
}

private struct TrainerWorkoutEditor: View {
    let model: TrainingNotebookModel
    @Binding var workout: WorkoutTemplate
    @State private var editingExercise: Exercise?

    private var details: Binding<TrainerWorkoutDetails> {
        Binding(get: { workout.trainerDetails ?? TrainerWorkoutDetails() }, set: { workout.trainerDetails = $0 })
    }

    var body: some View {
        Form {
            Section("Workout details") {
                LabeledContent("Minutes") {
                    TextField("Optional", value: details.minutes, format: .number).multilineTextAlignment(.trailing)
                }
                TextField("Equipment", text: details.equipment)
                TextField("Coaching notes", text: details.notes, axis: .vertical)
            }
            Section("Set and rep targets") {
                ForEach(workout.exerciseIDs, id: \.self) { id in
                    Button { editingExercise = model.exercise(id) } label: {
                        TrainerNavigationRow(title: model.exercise(id).displayName, detail: workout.exercisePlans[id].map {
                            ProgramPrescriptionList.target(ProgramExercise(exerciseID: id, plan: $0))
                        } ?? "Set targets")
                    }
                }
            }
        }.formStyle(.grouped).programPageStyle().navigationTitle(workout.name)
        .sheet(item: $editingExercise) { exercise in
            WorkoutTemplatePlanEditor(exercise: exercise, plan: workout.exercisePlans[exercise.id], close: { editingExercise = nil }) {
                workout.exercisePlans[exercise.id] = $0
                editingExercise = nil
            }
        }
    }
}
