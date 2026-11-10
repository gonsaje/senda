import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SwipeableSetRow<Content: View>: View {
    let id: UUID
    let index: Int
    @Binding var revealedRowID: UUID?
    let highlighted: Bool
    let effort: String
    let includesDropStages: Bool
    let editEffort: () -> Void
    let delete: () -> Bool
    @ViewBuilder var content: () -> Content
    @State private var swipe = SetRowSwipeState()
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var offset: CGFloat { swipe.offset ?? (revealedRowID == id ? -SetRowSwipeState.revealWidth : 0) }
    private var animation: Animation? { reduceMotion ? nil : .easeOut(duration: 0.18) }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            content()
            Menu {
                Button(effort, action: editEffort)
                    .accessibilityLabel("Set \(index), \(effort)")
                    .accessibilityHint("Edit optional reps left without changing weight, reps, or set type")
                    .accessibilityIdentifier("row-\(index)-details")
                Button(role: .destructive, action: remove) {
                    Label(includesDropStages ? "Delete entire set" : "Delete set", systemImage: "trash")
                }
                    .accessibilityLabel(includesDropStages ? "Delete set \(index) and all its drops" : "Delete set \(index)")
                    .accessibilityIdentifier("delete-row-\(index)")
            } label: {
                Image(systemName: "ellipsis").rotationEffect(.degrees(90))
                    .font(.system(size: 18, weight: .medium)).foregroundStyle(NotebookStyle.quiet)
                    .frame(width: 44, height: 56).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .frame(width: 44, height: 56).contentShape(Rectangle())
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
        .modifier(SetRowPanGesture(changed: move, ended: finish, cancelled: { swipe.cancel() }))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("set-row-\(index)")
        .accessibilityAction(named: Text("Delete set \(index)"), remove)
    }

    private func move(_ translation: CGSize) {
        swipe.move(translation, opened: revealedRowID == id, width: width)
        if swipe.isHorizontal && revealedRowID != id { revealedRowID = nil }
    }

    private func finish(_ translation: CGSize) {
        switch swipe.finish(translation, width: width) {
        case .delete: remove()
        case .revealed: withAnimation(animation) { revealedRowID = id }
        case .closed: withAnimation(animation) { revealedRowID = nil }
        case .unchanged: break
        }
    }

    private func remove() {
        let saved = delete()
        withAnimation(animation) { revealedRowID = saved ? nil : id; swipe.cancel() }
    }
}

private struct SetRowPanGesture: ViewModifier {
    let changed: (CGSize) -> Void
    let ended: (CGSize) -> Void
    let cancelled: () -> Void
    @GestureState private var dragging = false

    @ViewBuilder func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            content.gesture(HorizontalSetRowPan(changed: changed, ended: ended, cancelled: cancelled))
        } else {
            legacy(content)
        }
        #else
        legacy(content)
        #endif
    }

    private func legacy(_ content: Content) -> some View {
        content.simultaneousGesture(DragGesture(minimumDistance: 12)
            .updating($dragging) { _, active, _ in active = true }
            .onChanged { changed($0.translation) }
            .onEnded { ended($0.translation) })
        .onChange(of: dragging) { _, active in
            if !active {
                Task { @MainActor in
                    // Let onEnded settle before clearing a cancelled drag.
                    await Task.yield()
                    if !dragging { cancelled() }
                }
            }
        }
    }
}

#if os(iOS)
@available(iOS 18.0, *)
private struct HorizontalSetRowPan: UIGestureRecognizerRepresentable {
    let changed: (CGSize) -> Void
    let ended: (CGSize) -> Void
    let cancelled: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.cancelsTouchesInView = true
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let point = recognizer.translation(in: nil)
        let translation = CGSize(width: point.x, height: point.y)
        switch recognizer.state {
        case .began, .changed: changed(translation)
        case .ended: ended(translation)
        case .cancelled, .failed: cancelled()
        default: break
        }
    }

    @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let recognizer = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let translation = recognizer.translation(in: nil)
            // Fail vertical motion before recognition so the enclosing scroll view can begin.
            return translation.x.isFinite && translation.y.isFinite
                && (translation.x != 0 || translation.y != 0)
                && abs(translation.x) > abs(translation.y) * 1.2
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
            return otherGestureRecognizer === scrollView.panGestureRecognizer
        }
    }
}
#endif
