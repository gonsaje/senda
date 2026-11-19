import SwiftUI
import SendaDomain

struct TrainingEmptyWorkout: View {
    let isFirstWorkout: Bool
    let unit: WeightUnit
    let addExercise: (() -> Void)?
    let chooseTemplate: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isFirstWorkout && !textSize.isAccessibilitySize {
                example
            } else {
                Divider()
            }
            VStack(spacing: 4) {
                if let addExercise {
                    Button(action: addExercise) {
                        actionLabel("Add exercise", symbol: "plus")
                            .foregroundStyle(NotebookStyle.onPrimary)
                            .background(NotebookStyle.primaryFill, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .accessibilityIdentifier("add-exercise")
                }
                Button(action: chooseTemplate) {
                    Text("Choose a template").font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityIdentifier("choose-workout")
            }
            if isFirstWorkout && textSize.isAccessibilitySize { example }
        }
        .padding(.top, 6)
    }

    private func actionLabel(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
    }

    private var example: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 6))
        let values = "\(unit.text(for: 13_500)) \(unit.symbol) × 8 reps"
        let visual = ExerciseFormVisual.guide(for: "bench")
        return VStack(alignment: .leading, spacing: 0) {
            Divider()
            layout {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Example set").font(.footnote).foregroundStyle(NotebookStyle.quiet)
                    Text("Bench").font(NotebookTypography.heading(28, relativeTo: .title2))
                    Text(values).font(.body.weight(.semibold).monospacedDigit())
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Example set, Bench, \(values)")
                .accessibilityIdentifier("first-workout-example")
                if let frame = visual?.frames.last {
                    let drawing = ExerciseArtworkImage(name: frame.resourceName, maximumPixelSize: 540)
                        .aspectRatio(contentMode: .fit)
                    Group {
                        if colorScheme == .dark {
                            drawing.colorInvert().colorMultiply(NotebookStyle.ink).blendMode(.screen)
                        } else {
                            drawing.blendMode(.multiply)
                        }
                    }
                    .frame(maxWidth: 150, maxHeight: 154)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(frame.accessibleDescription)
                    .accessibilityAddTraits(.isImage)
                }
            }
            .padding(.top, 16)
            if let visual {
                let creditLayout = textSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 6))
                creditLayout {
                    Link(destination: visual.sourceURL) {
                        Text("Art by \(visual.creator)").underline()
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    if !textSize.isAccessibilitySize { Text("·").accessibilityHidden(true) }
                    Link(destination: visual.licenseURL) {
                        Text(visual.licenseTitle).underline()
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
                .font(.caption2)
                .foregroundStyle(NotebookStyle.quiet)
            }
            Divider()
        }
    }
}
