import SendaDomain
import SwiftUI

enum TrainingExerciseGuideTab: Hashable {
    case form, muscles
}

private struct WorkoutGuideContent {
    let exercise: Exercise

    var form: ExerciseFormGuide? { exercise.presetID.flatMap(ExerciseFormGuide.guide(for:)) }
    var targets: [MuscleRegion] {
        exercise.presetID == nil ? exercise.primaryTrackedMuscles : exercise.muscleMap?.primary ?? exercise.taggedMuscles
    }
    var supporting: [MuscleRegion] {
        let primary = Set(targets)
        return exercise.trackedMuscles.filter { !primary.contains($0) }
    }
    var hasMuscles: Bool { !targets.isEmpty || !supporting.isEmpty }

    var emphasizesUpperChest: Bool {
        switch exercise.presetID {
        case "incline-barbell-bench", "incline-dumbbell-bench", "incline-smith-machine-bench-press",
             "plate-loaded-incline-chest-press": true
        default: false
        }
    }

    var emphasis: (name: String, anatomy: String)? {
        // Bench inclination and regional pec activity: https://pubmed.ncbi.nlm.nih.gov/33049982/
        if emphasizesUpperChest {
            return ("Upper chest", "Clavicular fibers of the pectoralis major")
        }
        switch exercise.presetID {
        case "bench":
            return ("Upper, middle and lower chest", "Clavicular, sternal and costal fibers of the pectoralis major")
        // Overhead elbow extension and the triceps long head: https://pubmed.ncbi.nlm.nih.gov/35819335/
        case "cable-overhead-triceps-extension", "overhead-dumbbell-triceps-extension",
             "single-arm-overhead-dumbbell-triceps-extension", "band-overhead-triceps-extension":
            return ("Triceps long head", "Long head of the triceps brachii")
        // Knee position in calf raises: https://pubmed.ncbi.nlm.nih.gov/38156065/
        case "seated-calf-raise", "seated-dumbbell-calf-raise":
            return ("Soleus", "Soleus, the deeper calf muscle")
        case "standing-calf-raise", "standing-dumbbell-calf-raise", "machine-standing-calf-raise",
             "smith-machine-standing-calf-raise", "single-leg-calf-raise":
            return ("Gastrocnemius", "Gastrocnemius, the superficial calf muscle")
        default:
            return nil
        }
    }

    var targetNames: String? {
        if let emphasis { return emphasis.name }
        guard !targets.isEmpty else { return nil }
        return targets.map(\.name).joined(separator: " · ")
    }
}

struct TrainingExerciseTargets: View {
    let exercise: Exercise
    let open: (TrainingExerciseGuideTab) -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let content = WorkoutGuideContent(exercise: exercise)
        let primary = content.targetNames
        let secondaryNames = content.supporting.map(\.name)
        let secondary = secondaryNames.isEmpty ? nil : secondaryNames.joined(separator: " · ")
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        layout {
            if content.hasMuscles {
                Button { open(.muscles) } label: {
                    HStack(spacing: 8) {
                        ExerciseMuscleThumbnail(primary: content.targets, supporting: content.supporting,
                            emphasizesUpperChest: content.emphasizesUpperChest, height: 88)
                        VStack(alignment: .leading, spacing: 4) {
                            if let primary { targetLabel(Text("**Primary** \(primary)")) }
                            if let secondary { targetLabel(Text("**Secondary** \(secondary)")) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(NotebookStyle.clay)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel([
                    "Muscles worked",
                    primary.map { "Primary \($0)" },
                    secondary.map { "Secondary \($0)" }
                ].compactMap { $0 }.joined(separator: ". "))
                .accessibilityHint("Opens the muscle diagram and details")
                .accessibilityIdentifier("exercise-target-muscles")
            } else {
                targetLabel(Text(exercise.muscleGroup?.rawValue ?? "Muscles unspecified"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("exercise-target-muscles")
            }
            if content.form != nil {
                Button { open(.form) } label: {
                    Text("Form")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityHint("Opens the exercise form guide")
                    .accessibilityIdentifier("open-exercise-guide")
            }
        }
    }

    private func targetLabel(_ label: Text) -> some View {
        label
            .font(.subheadline)
            .foregroundStyle(NotebookStyle.quiet)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct TrainingExerciseGuide: View {
    let exercise: Exercise
    let close: () -> Void

    @State private var tab: TrainingExerciseGuideTab

    init(exercise: Exercise, initialTab: TrainingExerciseGuideTab, close: @escaping () -> Void) {
        self.exercise = exercise
        self.close = close
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        let content = WorkoutGuideContent(exercise: exercise)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Text(exercise.displayName).font(NotebookTypography.heading(28))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Button(action: close) {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("Close guide")
                .accessibilityIdentifier("close-exercise-guide")
            }
            if content.form != nil && content.hasMuscles {
                HStack(spacing: 20) {
                    guideTab("Form", .form)
                    guideTab("Muscles", .muscles)
                }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let form = content.form, tab == .form {
                        formContent(form)
                    } else if let map = exercise.muscleMap {
                        Text(map.variation).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        if let emphasis = content.emphasis {
                            guideText("Emphasis", emphasis.anatomy)
                        }
                        ExerciseMuscleMapView(map: map, showsAnatomicalNames: true,
                            emphasizesUpperChest: content.emphasizesUpperChest)
                            .accessibilityIdentifier("exercise-muscles-\(exercise.id)")
                        if let presetID = exercise.presetID,
                           ["cable-row", "wide-grip-seated-cable-row", "single-arm-cable-row"].contains(presetID) {
                            guideText("During the pull", "The lats draw your upper arms back, with help from the rear deltoids. The middle trapezius and rhomboids draw your shoulder blades together. Your biceps bend your elbows.")
                        }
                    } else if content.hasMuscles {
                        ExerciseMuscleFigures(primary: content.targets, supporting: content.supporting)
                            .accessibilityHidden(true)
                        ExerciseMuscleTagsView(exercise: exercise)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 18)
            }
            .id(tab)
        }
        .padding(.horizontal, 22).padding(.top, 12)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-exercise-guide")
    }

    private func guideTab(_ title: String, _ destination: TrainingExerciseGuideTab) -> some View {
        let selected = tab == destination
        return Button { tab = destination } label: {
            Text(title)
                .font(.body.weight(selected ? .semibold : .regular))
                .frame(minWidth: 44, minHeight: 44)
                .overlay(alignment: .bottom) {
                    if selected { Rectangle().fill(NotebookStyle.clay).frame(height: 2) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(destination == .muscles ? "workout-guide-muscles" : "workout-guide-form")
    }

    @ViewBuilder
    private func formContent(_ guide: ExerciseFormGuide) -> some View {
        let visual = ExerciseFormVisual.guide(for: guide.id)
        if let visual {
            ExerciseFormVisualView(visual: visual)
        }
        guideText("Set up", guide.setup)
        guideText("Move", guide.movement)
        guideText("Keep in mind", guide.cue)
        Link(guide.sourceTitle, destination: guide.sourceURL)
            .font(.callout).frame(minHeight: 44)
        if let visual { ExerciseIllustrationCredits(visual: visual) }
    }

    private func guideText(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(NotebookTypography.heading(20, relativeTo: .title3)).accessibilityAddTraits(.isHeader)
            Text(body).font(.body).fixedSize(horizontal: false, vertical: true)
        }
    }
}
