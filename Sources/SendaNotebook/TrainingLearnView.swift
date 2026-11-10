import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingLearnView: View {
    @Bindable var model: TrainingNotebookModel
    @FocusState private var searchFocused: Bool
    @State private var returnExerciseID: String?

    private var results: [Exercise] { ExerciseFormGuide.search(model.learningQuery, in: model.exercises) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let id = model.learningExerciseID {
                        ExerciseLearningDetail(exercise: model.exercise(id))
                    } else {
                        Text("Learn").font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                        search
                        if results.isEmpty { emptyState }
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            let exercises = results.filter { $0.group == group }
                            if !exercises.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(group.rawValue)
                                        .font(NotebookTypography.heading(22, relativeTo: .title2))
                                        .accessibilityAddTraits(.isHeader)
                                        .padding(.bottom, 8)
                                    ForEach(exercises) { exercise in
                                        exerciseRow(exercise)
                                            .id("learn-exercise-\(exercise.id)")
                                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(24).padding(.bottom, 8)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .id("learn-top")
            }
            .clipped()
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("learn-scroll")
            .safeAreaInset(edge: .top, spacing: 0) {
                if model.learningExerciseID != nil { navigation }
            }
            .task(id: model.learningExerciseID) {
                // Wait for the new content to lay out before restoring its position.
                await Task.yield()
                guard !Task.isCancelled else { return }
                if model.learningExerciseID != nil {
                    proxy.scrollTo("learn-top", anchor: .top)
                } else if let id = returnExerciseID {
                    proxy.scrollTo("learn-exercise-\(id)", anchor: .center)
                }
            }
        }
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            TextField("Find an exercise", text: $model.learningQuery)
                .textFieldStyle(.plain).autocorrectionDisabled()
                .focused($searchFocused).submitLabel(.search)
                .onSubmit { searchFocused = false }
                .accessibilityIdentifier("learn-search")
            if !model.learningQuery.isEmpty {
                Button { model.learningQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16)).foregroundStyle(NotebookStyle.quiet)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("learn-search-clear")
            }
        }
        .padding(.leading, 12).padding(.trailing, 4).frame(minHeight: 48)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(NotebookStyle.rule, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No exercises found")
                .font(NotebookTypography.heading(22, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
            Text("Try a different exercise name, muscle group, or equipment.")
                .foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                searchFocused = false
                model.learningQuery = ""
            } label: {
                Text("Clear search").frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("learn-empty-clear")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("learn-empty-state")
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            searchFocused = false
            model.learningExerciseID = exercise.id
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let visual = ExerciseFormVisual.guide(for: exercise.id), let frame = visual.frames.first {
                        ExerciseArtworkImage(name: frame.resourceName, maximumPixelSize: 192)
                            .scaledToFit().blendMode(.multiply)
                    } else if let muscles = ExerciseMuscleMap.map(for: exercise.id) {
                        ExerciseMuscleThumbnail(map: muscles)
                    } else {
                        Color.clear
                    }
                }.frame(width: 58, height: 58).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name).font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(exerciseSubtitle(exercise))
                        .font(.caption).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 12))
                    .foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            }.padding(.vertical, 8).frame(minHeight: 76).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("learn-exercise-\(exercise.id)")
    }

    private var navigation: some View {
        HStack {
            Button {
                searchFocused = false
                returnExerciseID = model.learningExerciseID
                model.learningExerciseID = nil
            } label: {
                Label("Learn", systemImage: "chevron.left").frame(minHeight: 44)
            }.accessibilityIdentifier("back-to-learn")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24).padding(.vertical, 4)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory)
        .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("learn-navigation")
    }

    private func exerciseSubtitle(_ exercise: Exercise) -> String {
        guard ExerciseFormGuide.guide(for: exercise.id) != nil else { return "Guide not added yet" }
        guard let muscles = ExerciseMuscleMap.map(for: exercise.id) else { return exercise.equipmentType.rawValue }
        return muscles.primary.map(\.name).joined(separator: ", ") + " · " + exercise.equipmentType.rawValue
    }
}
