import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingLearnView: View {
    @Bindable var model: TrainingNotebookModel
    private var results: [Exercise] { ExerciseFormGuide.search(model.learningQuery, in: model.exercises) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let id = model.learningExerciseID {
                    Button { model.learningExerciseID = nil } label: { Label("Learn", systemImage: "chevron.left").frame(minHeight: 44) }
                        .accessibilityIdentifier("back-to-learn")
                    let exercise = model.exercise(id)
                    Text(exercise.name).font(NotebookTypography.heading(37)).accessibilityIdentifier("form-guide-\(id)")
                    Text("\(exercise.group.rawValue) · \(exercise.equipmentType.rawValue)").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    if let guide = ExerciseFormGuide.guide(for: id) {
                        guideSection("Set up", guide.setup)
                        guideSection("Move", guide.movement)
                        guideSection("Keep in mind", guide.cue)
                        Link(destination: guide.sourceURL) {
                            Label(guide.sourceTitle, systemImage: "arrow.up.right").font(.callout).frame(minHeight: 44)
                        }.accessibilityIdentifier("form-source")
                    } else {
                        Text("A form guide hasn’t been added for this custom exercise yet.").foregroundStyle(NotebookStyle.quiet)
                    }
                } else {
                    Text("Learn").font(NotebookTypography.heading(37))
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet)
                        TextField("Find an exercise", text: $model.learningQuery).textFieldStyle(.plain).autocorrectionDisabled()
                            .submitLabel(.search)
                            .accessibilityIdentifier("learn-search")
                    }.padding(.horizontal, 12).frame(minHeight: 48)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(NotebookStyle.rule, lineWidth: 1))
                    if results.isEmpty { Text("No exercises found.").foregroundStyle(NotebookStyle.quiet) }
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        let exercises = results.filter { $0.group == group }
                        if !exercises.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(group.rawValue).font(NotebookTypography.heading(25)).padding(.bottom, 8)
                                ForEach(exercises) { exercise in
                                    Button { model.learningExerciseID = exercise.id } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(exercise.name).font(.body.weight(.medium))
                                                Text(ExerciseFormGuide.guide(for: exercise.id) == nil ? "Guide not added yet" : exercise.equipmentType.rawValue)
                                                    .font(.caption).foregroundStyle(NotebookStyle.quiet)
                                            }.frame(maxWidth: .infinity, alignment: .leading)
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(NotebookStyle.quiet)
                                        }.frame(minHeight: 64).contentShape(Rectangle())
                                    }.accessibilityIdentifier("learn-exercise-\(exercise.id)")
                                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                                }
                            }
                        }
                    }
                }
            }.padding(24).padding(.bottom, 8).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("learn-scroll")
    }
    private func guideSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.weight(.semibold))
            Text(text).font(.body).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }
}
