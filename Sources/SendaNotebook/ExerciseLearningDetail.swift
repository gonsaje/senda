import SwiftUI
import SendaDomain

/// Read-only instruction. Learning never changes a workout or its recorded sets.
public struct ExerciseLearningDetail: View {
    public let exercise: Exercise

    public init(exercise: Exercise) { self.exercise = exercise }

    private var visual: ExerciseFormVisual? { exercise.presetID.flatMap(ExerciseFormVisual.guide(for:)) }

    var subtitle: String {
        if let variation = visual?.variationLabel ?? exercise.muscleMap?.variation, variation != exercise.name {
            return variation
        }
        return "\(exercise.group.rawValue) · \(exercise.equipmentLabel)"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.displayName)
                    .font(NotebookTypography.heading(31))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("form-guide-\(exercise.id)")
                Text(subtitle)
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let guide = exercise.presetID.flatMap(ExerciseFormGuide.guide(for:))
            if let guide {
                if let visual {
                    ExerciseFormVisualView(visual: visual)
                }

                guideSection("Set up", guide.setup)
                guideSection("Move", guide.movement)
                guideSection("Keep in mind", guide.cue)

            } else {
                Text("No form guide yet.")
                    .foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let muscles = exercise.muscleMap {
                Divider().overlay(NotebookStyle.rule)
                VStack(alignment: .leading, spacing: 16) {
                    sectionTitle("Muscles worked")
                    ExerciseMuscleMapView(map: muscles)
                        .accessibilityIdentifier("exercise-muscles-\(exercise.id)")
                }
            } else if !exercise.taggedMuscles.isEmpty {
                ExerciseMuscleTagsView(exercise: exercise)
            }

            if let guide {
                VStack(alignment: .leading, spacing: 4) {
                    Link(destination: guide.sourceURL) {
                        Label(guide.sourceTitle, systemImage: "arrow.up.right")
                            .font(.callout).frame(minHeight: 44, alignment: .leading)
                    }.accessibilityIdentifier("form-source")
                    if let visual {
                        ExerciseIllustrationCredits(visual: visual)
                    }
                }
            }
        }.foregroundStyle(NotebookStyle.ink)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(NotebookTypography.heading(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
    }

    private func guideSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            Text(text).font(.body).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ExerciseMuscleTagsView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Muscle tags").font(.subheadline.weight(.semibold))
            Text(exercise.taggedMuscles.map(\.name).joined(separator: ", "))
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exercise-muscle-tags-\(exercise.id)")
    }
}

struct ExerciseFormVisualView: View {
    let visual: ExerciseFormVisual
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var enlargedFrame: ExerciseFormVisual.Frame?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Form").font(NotebookTypography.heading(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            let columns = [GridItem](repeating: GridItem(.flexible(), spacing: 16),
                                     count: textSize.isAccessibilitySize ? 1 : 2)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                ForEach(Array(visual.frames.enumerated()), id: \.offset) { index, frame in
                    Button { enlargedFrame = frame } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            ExerciseArtworkImage(name: frame.resourceName)
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .accessibilityHidden(true)
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(index + 1). \(frame.phase)")
                                    .font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption).foregroundStyle(NotebookStyle.quiet)
                            }
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(index + 1). \(frame.phase). \(frame.accessibleDescription)")
                    .accessibilityHint("Opens a larger illustration")
                    .accessibilityIdentifier("form-position-\(visual.id)-\(index + 1)")
                }
            }
        }.accessibilityIdentifier("exercise-form-visual-\(visual.id)")
            .sheet(item: $enlargedFrame) { frame in
                ExerciseFormPositionView(frame: frame, close: { enlargedFrame = nil })
            }
    }
}

public struct ExerciseFormPositionView: View {
    private let frame: ExerciseFormVisual.Frame
    private let close: () -> Void

    public init(frame: ExerciseFormVisual.Frame, close: @escaping () -> Void) {
        self.frame = frame
        self.close = close
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        title.fixedSize(horizontal: true, vertical: true)
                        Spacer(minLength: 0)
                        done.fixedSize(horizontal: true, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        title
                        done.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                ExerciseArtworkImage(name: frame.resourceName)
                    .scaledToFit().accessibilityHidden(true)
                Text(frame.accessibleDescription).font(.body).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .clipped()
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay)
        .accessibilityIdentifier("form-position-detail")
    }

    private var title: some View {
        Text(frame.phase).font(NotebookTypography.heading(30))
            .accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var done: some View {
        Button("Done", action: close).frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("close-form-position")
    }
}

struct ExerciseIllustrationCredits: View {
    let visual: ExerciseFormVisual
    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 0) {
                Text("Illustrations by \(visual.creator).")
                    .font(.footnote).foregroundStyle(NotebookStyle.quiet)
                Link("Original artwork", destination: visual.sourceURL).frame(minHeight: 44)
                Link(visual.licenseTitle, destination: visual.licenseURL).frame(minHeight: 44)
                Text("Original artwork, bundled unchanged for offline use. Artwork remains available under the same license.")
                    .font(.footnote).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }.font(.callout).padding(.top, 8)
        } label: {
            Text("Illustration credits").font(.callout).frame(minHeight: 44)
        }.tint(NotebookStyle.clay)
    }
}
