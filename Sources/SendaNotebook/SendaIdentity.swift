import SwiftUI

/// Original tapered trail geometry; the standalone SVG uses the same 32 × 44 coordinates.
struct SendaPathMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 3, y: 41))
        path.addCurve(to: CGPoint(x: 23, y: 26), control1: CGPoint(x: 11, y: 37), control2: CGPoint(x: 24, y: 34))
        path.addCurve(to: CGPoint(x: 12, y: 13), control1: CGPoint(x: 22, y: 19), control2: CGPoint(x: 12, y: 20))
        path.addCurve(to: CGPoint(x: 29, y: 2), control1: CGPoint(x: 12, y: 7), control2: CGPoint(x: 22, y: 4))
        path.addCurve(to: CGPoint(x: 19, y: 16), control1: CGPoint(x: 24, y: 8), control2: CGPoint(x: 19, y: 12))
        path.addCurve(to: CGPoint(x: 28, y: 30), control1: CGPoint(x: 19, y: 21), control2: CGPoint(x: 29, y: 23))
        path.addCurve(to: CGPoint(x: 3, y: 41), control1: CGPoint(x: 27, y: 38), control2: CGPoint(x: 12, y: 42))
        path.closeSubpath()
        let scale = min(rect.width / 32, rect.height / 44)
        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
            .offsetBy(dx: rect.midX - 16 * scale, dy: rect.midY - 22 * scale)
    }
}

struct TrainingWordmark: View {
    var body: some View {
        HStack(spacing: 6) {
            SendaPathMark().fill(NotebookStyle.olive).frame(width: 23, height: 32)
                .accessibilityHidden(true)
            Text("senda").font(NotebookTypography.heading(23, italic: true, relativeTo: .title3)).tracking(-0.7)
                .foregroundStyle(NotebookStyle.ink)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Senda")
    }
}
