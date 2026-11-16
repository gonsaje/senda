import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingLearnView: View {
    @Bindable var model: TrainingNotebookModel
    @FocusState private var searchFocused: Bool
    @State private var presentedGuideID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    init(model: TrainingNotebookModel) {
        self.model = model
        _presentedGuideID = State(initialValue: model.learningExerciseID)
    }

    private var results: [Exercise] { ExerciseFormGuide.search(model.learningQuery, in: model.exercises) }
    private var motion: TrainingPageMotion { TrainingPageMotion(reduceMotion: reduceMotion) }
    private var guideOffset: CGFloat {
        layoutDirection == .rightToLeft ? -TrainingPageMotion.detailOffset : TrainingPageMotion.detailOffset
    }

    var body: some View {
        let showingGuide = presentedGuideID != nil
        let listIsActive = !showingGuide && model.learningExerciseID == nil
        ZStack {
            // Keep the list mounted so returning keeps its exact scroll offset.
            exerciseList
                .id(model.landingResetID)
                .animation(motion.opacityAnimation(appearing: !showingGuide)) { view in
                    view.opacity(showingGuide ? 0 : 1)
                }
                .offset(x: showingGuide && !reduceMotion ? -guideOffset : 0)
                .allowsHitTesting(listIsActive)
                .accessibilityHidden(!listIsActive)
            if let id = presentedGuideID {
                guide(id)
                    .allowsHitTesting(model.learningExerciseID == id)
                    .accessibilityHidden(model.learningExerciseID != id)
                    .id(id)
                    .transition(motion.transition(entryOffset: guideOffset))
                    .zIndex(1)
            }
        }
        .clipped()
        .onChange(of: model.learningExerciseID) { _, next in
            withAnimation(motion.animation) { presentedGuideID = next }
        }
        .onChange(of: model.landingResetID) { _, _ in searchFocused = false }
    }

    private var exerciseList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding(24).padding(.bottom, 8)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .clipped()
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("learn-scroll")
            .task { [presentedGuideID] in
                // When Learn remounts from another tab, return near the open guide's row.
                guard let id = presentedGuideID, id == model.learningExerciseID else { return }
                await Task.yield()
                guard !Task.isCancelled, id == model.learningExerciseID else { return }
                proxy.scrollTo("learn-exercise-\(id)", anchor: .center)
            }
        }
    }

    private func guide(_ id: String) -> some View {
        ScrollView {
            ExerciseLearningDetail(exercise: model.exercise(id))
                .padding(24).padding(.bottom, 8)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .clipped()
        .accessibilityIdentifier("learn-guide-scroll")
        .safeAreaInset(edge: .top, spacing: 0) { navigation }
        .background(NotebookStyle.ivory)
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
