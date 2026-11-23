import SwiftUI
import SendaLogger

struct TrainingDockIcon: View {
    let section: TrainingSection
    let selected: Bool

    var body: some View {
        Canvas { context, size in
            // All four drawings share a 24-point grid.
            let scale = min(size.width, size.height) / 24
            context.translateBy(x: (size.width - 24 * scale) / 2, y: (size.height - 24 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            let ink = selected ? NotebookStyle.clay : NotebookStyle.quiet
            let stroke = StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
            func line(_ path: Path) {
                context.stroke(path, with: .color(ink), style: stroke)
            }
            func wash(_ path: Path) {
                context.fill(path, with: .color(ink.opacity(selected ? 0.28 : 0.13)))
            }

            switch section {
            case .log:
                var dumbbell = context
                dumbbell.translateBy(x: 12, y: 12)
                dumbbell.rotate(by: .degrees(-45))
                var weight = Path()
                weight.addRect(CGRect(x: -5, y: -1.55, width: 10, height: 3.1))
                for end in [-1.0, 1.0] {
                    let innerPlate = CGRect(x: end * 6.2 - 1.85, y: -5.6, width: 3.7, height: 11.2)
                    let outerPlate = CGRect(x: end * 10.3 - 1.25, y: -3.7, width: 2.5, height: 7.4)
                    weight.addRoundedRect(in: innerPlate, cornerSize: CGSize(width: 1.15, height: 1.15))
                    weight.addRoundedRect(in: outerPlate, cornerSize: CGSize(width: 1, height: 1))
                }
                dumbbell.fill(weight, with: .color(ink))

            case .trends:
                let trace = Path { path in
                    path.move(to: CGPoint(x: 2.5, y: 17.3))
                    path.addLine(to: CGPoint(x: 8.1, y: 11.5))
                    path.addQuadCurve(to: CGPoint(x: 9.8, y: 11.4), control: CGPoint(x: 8.9, y: 10.6))
                    path.addLine(to: CGPoint(x: 12.3, y: 13.4))
                    path.addQuadCurve(to: CGPoint(x: 14.1, y: 13.2), control: CGPoint(x: 13.3, y: 14.2))
                    path.addLine(to: CGPoint(x: 20.6, y: 5.4))
                }
                var area = trace
                area.addLine(to: CGPoint(x: 20.6, y: 20.2))
                area.addLine(to: CGPoint(x: 2.5, y: 20.2))
                area.closeSubpath()
                wash(area)
                line(trace)
                context.fill(Path(ellipseIn: CGRect(x: 18.6, y: 3.4, width: 4, height: 4)), with: .color(ink))

            case .learn:
                let frontRect = CGRect(x: 2.7, y: 5.8, width: 15.1, height: 16)
                let backRect = frontRect.offsetBy(dx: 3.5, dy: -3.6)
                var back = context
                let gap = Path(roundedRect: frontRect.insetBy(dx: -1.05, dy: -1.05), cornerRadius: 3.15)
                back.clip(to: gap, options: .inverse)
                back.fill(Path(roundedRect: backRect, cornerRadius: 2.1), with: .color(ink))

                var front = Path(roundedRect: frontRect, cornerRadius: 2.1)
                for y in [11.0, 15.4] {
                    let rule = CGRect(x: 5.7, y: y, width: 9.1, height: 1.65)
                    front.addRoundedRect(in: rule, cornerSize: CGSize(width: 0.825, height: 0.825))
                }
                context.fill(front, with: .color(ink), style: FillStyle(eoFill: true))

            case .profile:
                let frame = Path(ellipseIn: CGRect(x: 2.8, y: 2.8, width: 18.4, height: 18.4))
                let shoulders = Path { path in
                    path.move(to: CGPoint(x: 4.5, y: 18.7))
                    path.addCurve(to: CGPoint(x: 12, y: 14.8), control1: CGPoint(x: 6.5, y: 15.9), control2: CGPoint(x: 9.0, y: 14.8))
                    path.addCurve(to: CGPoint(x: 19.5, y: 18.7), control1: CGPoint(x: 15.0, y: 14.8), control2: CGPoint(x: 17.5, y: 15.9))
                }
                var portrait = context
                portrait.clip(to: frame)
                var bust = shoulders
                bust.addLine(to: CGPoint(x: 19.5, y: 22))
                bust.addLine(to: CGPoint(x: 4.5, y: 22))
                bust.closeSubpath()
                portrait.fill(bust, with: .color(ink.opacity(selected ? 0.28 : 0.13)))
                portrait.stroke(shoulders, with: .color(ink), style: stroke)
                let head = Path(ellipseIn: CGRect(x: 9.1, y: 6.5, width: 5.8, height: 6.2))
                wash(head)
                line(head)
                line(frame)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
