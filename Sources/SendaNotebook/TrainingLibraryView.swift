import SwiftUI
import SendaLogger

struct TrainingLibraryView: View {
    @Bindable var model: TrainingNotebookModel

    var body: some View {
        switch model.libraryArea {
        case .workouts:
            TrainingWorkoutLibrary(model: model, destinationDay: model.selectedDay ?? model.today,
                                  embedded: true, close: { model.selectSection(.log) })
        case .exercises:
            TrainingExerciseLibrary(model: model)
        case .learn:
            TrainingGuideLibrary(model: model)
        }
    }
}

struct TrainingLibraryHeader: View {
    @Bindable var model: TrainingNotebookModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TrainingSection.learn.title)
                .font(NotebookTypography.heading(31))
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { areas }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 0) { areas }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .bottom) {
                Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
            }
        }
    }

    private var areas: some View {
        ForEach(TrainingLibraryArea.allCases, id: \.self) { area in
            let selected = model.libraryArea == area
            Button { model.libraryArea = area } label: {
                Text(area.rawValue)
                    .font(.headline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? NotebookStyle.ink : NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 44, minHeight: 44)
                    .overlay(alignment: .bottom) {
                        if selected {
                            Rectangle().fill(NotebookStyle.clay).frame(height: 2).accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(area.rawValue)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("library-\(area.rawValue.lowercased())")
        }
    }
}

struct LibrarySegments<Content: View>: View {
    var stacked: Bool
    @ViewBuilder var content: Content

    var body: some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                             : AnyLayout(HStackLayout(spacing: 0))
        layout { content }
            .padding(3)
            .background(NotebookStyle.ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .contain)
    }
}

struct LibrarySegmentLabel: View {
    let title: String
    let selected: Bool
    var expands = false

    var body: some View {
        Text(title)
            .font(.subheadline.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? NotebookStyle.ink : NotebookStyle.quiet)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .frame(minWidth: 44, maxWidth: expands ? .infinity : nil, minHeight: 44)
            .background {
                if selected { RoundedRectangle(cornerRadius: 6).fill(NotebookStyle.ivory) }
            }
            .contentShape(Rectangle())
    }
}
