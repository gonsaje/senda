import SwiftUI

struct SwipeableSetRow<Content: View>: View {
    let id: UUID
    let index: Int
    @Binding var revealedRowID: UUID?
    let highlighted: Bool
    let delete: () -> Bool
    @ViewBuilder var content: () -> Content
    @State private var swipe = SetRowSwipeState()
    @State private var width: CGFloat = 0
    @GestureState private var dragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var offset: CGFloat { swipe.offset ?? (revealedRowID == id ? -SetRowSwipeState.revealWidth : 0) }
    private var animation: Animation? { reduceMotion ? nil : .easeOut(duration: 0.18) }

    var body: some View {
        HStack(spacing: 6) {
            content()
            Button {
                withAnimation(animation) { revealedRowID = revealedRowID == id ? nil : id }
            } label: {
                Image(systemName: "ellipsis").rotationEffect(.degrees(90))
                    .font(.system(size: 18, weight: .medium)).foregroundStyle(NotebookStyle.quiet)
                    .frame(width: 44, height: 56).contentShape(Rectangle())
            }
            .accessibilityLabel("Set \(index) actions")
            .accessibilityIdentifier("set-\(index)-actions")
        }
        .frame(minHeight: 60)
        // Moving buttons must not also fire their tap action on release.
        .disabled(swipe.isHorizontal)
        .background {
            NotebookStyle.ivory
            if highlighted { NotebookStyle.olive.opacity(0.10) }
        }
        .offset(x: offset)
        .background(alignment: .trailing) {
            if offset < 0 {
                Button(action: remove) {
                    Image(systemName: "xmark").font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: max(SetRowSwipeState.revealWidth, -offset))
                        .frame(maxHeight: .infinity).background(Color.red)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Delete set \(index)")
                .accessibilityIdentifier("delete-row-\(index)")
            }
        }
        .clipped()
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { width = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, value in width = value }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 12)
            .updating($dragging) { _, active, _ in active = true }
            .onChanged { value in
                swipe.move(value.translation, opened: revealedRowID == id, width: width)
                if swipe.isHorizontal && revealedRowID != id { revealedRowID = nil }
            }
            .onEnded { value in
                switch swipe.finish(value.translation, width: width) {
                case .delete: remove()
                case .revealed: withAnimation(animation) { revealedRowID = id }
                case .closed: withAnimation(animation) { revealedRowID = nil }
                case .unchanged: break
                }
            })
        .onChange(of: dragging) { _, active in
            if !active {
                Task { @MainActor in
                    // Let onEnded settle before clearing a cancelled drag.
                    await Task.yield()
                    if !dragging { swipe.cancel() }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("set-row-\(index)")
        .accessibilityAction(named: Text("Delete set \(index)"), remove)
    }

    private func remove() {
        let saved = delete()
        withAnimation(animation) { revealedRowID = saved ? nil : id; swipe.cancel() }
    }
}
