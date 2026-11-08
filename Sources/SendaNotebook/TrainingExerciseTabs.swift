import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingExerciseTabs: View {
    @Bindable var model: TrainingNotebookModel
    let day: TrainingDay
    var add: () -> Void
    var showAll: () -> Void
    @State private var visibleTabID: String?
    @State private var contentFrame: CGRect = .zero
    @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 22
    @Environment(\.layoutDirection) private var layoutDirection
    @Namespace private var viewportSpace

    private var tabHeight: CGFloat { max(48, lineHeight + 22) }

    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { viewport in
                let canOverflow = !model.tabs.isEmpty && contentFrame.width > viewport.size.width + 1
                let leftOverflow = canOverflow && contentFrame.minX < -1
                let rightOverflow = canOverflow && contentFrame.maxX > viewport.size.width + 1
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(model.tabs) { exercise in
                            tab(exercise).id(exercise.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 5).padding(.vertical, 6)
                    .background {
                        GeometryReader { content in
                            let frame = content.frame(in: .named(viewportSpace))
                            Color.clear
                                .onAppear { contentFrame = frame }
                                .onChange(of: frame) { _, value in contentFrame = value }
                        }
                    }
                }
                .scrollIndicators(.never)
                .scrollPosition(id: $visibleTabID, anchor: .center)
                .coordinateSpace(name: viewportSpace)
                .overlay(alignment: .leading) {
                    if layoutDirection == .leftToRight ? leftOverflow : rightOverflow { edgeShadow(leading: true) }
                }
                .overlay(alignment: .trailing) {
                    if layoutDirection == .leftToRight ? rightOverflow : leftOverflow { edgeShadow(leading: false) }
                }
                .accessibilityIdentifier("exercise-tabs")
            }
            HStack(spacing: 2) {
                if model.tabs.count > 1 {
                    Button(action: showAll) {
                        HStack(spacing: 5) {
                            Text("All \(model.tabs.count)").monospacedDigit()
                            Image(systemName: "list.bullet")
                        }.font(.caption).fixedSize()
                            .padding(.horizontal, 4).frame(minWidth: 44, minHeight: tabHeight)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("View all \(model.tabs.count) exercises")
                    .accessibilityIdentifier("all-exercises")
                }
                Button(action: add) {
                    Image(systemName: "plus").font(.title2).frame(width: 44, height: tabHeight)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Add exercise").accessibilityIdentifier("add-exercise")
            }.foregroundStyle(NotebookStyle.clay)
        }
        .frame(height: tabHeight + 12)
        .onChange(of: day) { _, _ in visibleTabID = model.exercise?.id }
        .onChange(of: model.exercise?.id) { _, id in visibleTabID = id }
        .onAppear { visibleTabID = model.exercise?.id }
    }

    private func tab(_ exercise: Exercise) -> some View {
        let selected = model.exercise?.id == exercise.id
        return Button { model.selectExercise(exercise.id) } label: {
            VStack(spacing: 4) {
                Text(exercise.name).font(.body.weight(selected ? .semibold : .regular))
                    .lineLimit(1).frame(maxWidth: 180)
                Rectangle().fill(selected ? NotebookStyle.clay : .clear).frame(height: 2)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(minWidth: 64, minHeight: tabHeight)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 7).fill(NotebookStyle.ivory)
                        .shadow(color: NotebookStyle.ink.opacity(0.22), radius: 3, x: 0, y: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.ink)
        .accessibilityLabel(exercise.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("exercise-\(exercise.id)")
        .contextMenu { Button("Remove from day", role: .destructive) { model.removeExercise(exercise.id) } }
    }

    private func edgeShadow(leading: Bool) -> some View {
        let leftEdge = leading == (layoutDirection == .leftToRight)
        return Rectangle().fill(NotebookStyle.ivory).frame(width: 3)
            .shadow(color: NotebookStyle.ink.opacity(0.30), radius: 5, x: leftEdge ? 3 : -3, y: 0)
            .frame(width: 16, alignment: leading ? .leading : .trailing)
            .clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}
