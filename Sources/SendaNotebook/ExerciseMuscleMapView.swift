import SwiftUI
import SendaDomain

/// An anatomical overview of the muscles involved in an exercise.
/// Filled regions are primary muscles; outlined regions support the movement.
public struct ExerciseMuscleMapView: View {
    private let map: ExerciseMuscleMap

    public init(map: ExerciseMuscleMap) {
        self.map = map
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 28) {
                figure(.front, title: "Front")
                figure(.back, title: "Back")
            }
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 13) {
                legend("Primary", muscles: map.primary, filled: true)
                if !map.supporting.isEmpty {
                    legend("Also works", muscles: map.supporting, filled: false)
                }
                if !map.stabilizing.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Stabilizers")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NotebookStyle.quiet)
                        Text(names(map.stabilizing))
                            .font(.subheadline)
                            .foregroundStyle(NotebookStyle.quiet)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 21)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private func figure(_ aspect: MuscleFigureAspect, title: String) -> some View {
        VStack(spacing: 8) {
            MuscleFigure(aspect: aspect, primary: map.primary, supporting: map.supporting)
                .aspectRatio(132.0 / 294.0, contentMode: .fit)
                .frame(maxHeight: 288)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(NotebookStyle.quiet)
        }
        .frame(maxWidth: .infinity)
    }

    private func legend(_ title: String, muscles: [MuscleRegion], filled: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            RoundedRectangle(cornerRadius: 3)
                .fill(filled ? NotebookStyle.clay : NotebookStyle.ivory)
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(filled ? NotebookStyle.clay : NotebookStyle.olive, lineWidth: filled ? 1 : 1.8)
                }
                .frame(width: 12, height: 12)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(names(muscles))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(NotebookStyle.ink)
        }
    }

    private func names(_ muscles: [MuscleRegion]) -> String {
        muscles.map(\.name).joined(separator: ", ")
    }

    private var accessibilityDescription: String {
        var description = "Muscles worked. Primary: \(names(map.primary))."
        if !map.supporting.isEmpty {
            description += " Also works: \(names(map.supporting))."
        }
        if !map.stabilizing.isEmpty {
            description += " Stabilizers: \(names(map.stabilizing))."
        }
        description += " The front and back diagrams show primary muscles filled and supporting muscles outlined."
        return description
    }
}

/// Compact anatomy artwork for exercises without a matching form illustration.
struct ExerciseMuscleThumbnail: View {
    let map: ExerciseMuscleMap

    var body: some View {
        HStack(spacing: 2) {
            MuscleFigure(aspect: .front, primary: map.primary, supporting: map.supporting)
                .frame(width: 26, height: 58)
            MuscleFigure(aspect: .back, primary: map.primary, supporting: map.supporting)
                .frame(width: 26, height: 58)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }
}

private enum MuscleFigureAspect {
    case front, back
}

private struct MuscleFigure: View {
    let aspect: MuscleFigureAspect
    let primary: [MuscleRegion]
    let supporting: [MuscleRegion]

    private let neutral = Color(red: 225 / 255, green: 218 / 255, blue: 205 / 255)
    private let muscleNeutral = Color(red: 214 / 255, green: 205 / 255, blue: 188 / 255)

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 132, size.height / 294)
            context.translateBy(x: (size.width - 132 * scale) / 2, y: (size.height - 294 * scale) / 2)
            context.scaleBy(x: scale, y: scale)

            let silhouette = Self.silhouette
            context.fill(silhouette, with: .color(neutral.opacity(0.55)))
            context.stroke(silhouette, with: .color(NotebookStyle.ink.opacity(0.33)), style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))

            let head = Path(ellipseIn: CGRect(x: 55.5, y: 6, width: 21, height: 29))
            context.fill(head, with: .color(neutral.opacity(0.55)))
            context.stroke(head, with: .color(NotebookStyle.ink.opacity(0.33)), lineWidth: 0.8)

            for (region, path) in Self.regions(for: aspect) {
                let isPrimary = primary.contains(region)
                let isSupporting = supporting.contains(region) && !isPrimary
                let fill = isPrimary ? NotebookStyle.clay : (isSupporting ? NotebookStyle.ivory : muscleNeutral.opacity(0.50))
                let outline = isPrimary ? NotebookStyle.clay.opacity(0.95) : (isSupporting ? NotebookStyle.olive : NotebookStyle.ink.opacity(0.18))
                context.fill(path, with: .color(fill))
                context.stroke(path, with: .color(outline), style: StrokeStyle(lineWidth: isSupporting ? 1.8 : 0.65, lineCap: .round, lineJoin: .round))
            }

            context.stroke(Self.details(for: aspect), with: .color(NotebookStyle.ink.opacity(0.25)), style: StrokeStyle(lineWidth: 0.65, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }

    // A relaxed anatomical stance, with the arms slightly away from the torso.
    private static var silhouette: Path {
        let half = Contour(start: p(58, 34), curves: [
            .init(to: p(54, 44), c1: p(58, 38), c2: p(57, 42)),
            .init(to: p(37, 48), c1: p(49, 45), c2: p(42, 45)),
            .init(to: p(29, 61), c1: p(32, 50), c2: p(30, 55)),
            .init(to: p(23, 88), c1: p(27, 70), c2: p(25, 81)),
            .init(to: p(18, 105), c1: p(22, 94), c2: p(19, 100)),
            .init(to: p(12, 130), c1: p(16, 115), c2: p(13, 125)),
            .init(to: p(8, 143), c1: p(11, 134), c2: p(8, 139)),
            .init(to: p(11, 150), c1: p(8, 147), c2: p(9, 150)),
            .init(to: p(17, 148), c1: p(13, 151), c2: p(16, 150)),
            .init(to: p(21, 136), c1: p(19, 145), c2: p(19, 139)),
            .init(to: p(25, 119), c1: p(22, 131), c2: p(24, 125)),
            .init(to: p(31, 100), c1: p(27, 112), c2: p(30, 106)),
            .init(to: p(37, 79), c1: p(32, 92), c2: p(35, 85)),
            .init(to: p(41, 70), c1: p(38, 75), c2: p(40, 72)),
            .init(to: p(46, 96), c1: p(42, 79), c2: p(44, 90)),
            .init(to: p(47, 116), c1: p(48, 103), c2: p(48, 109)),
            .init(to: p(43, 139), c1: p(46, 123), c2: p(43, 132)),
            .init(to: p(45, 174), c1: p(41, 150), c2: p(43, 165)),
            .init(to: p(48, 201), c1: p(47, 184), c2: p(48, 194)),
            .init(to: p(47, 224), c1: p(48, 208), c2: p(46, 214)),
            .init(to: p(51, 265), c1: p(47, 238), c2: p(51, 257)),
            .init(to: p(47, 278), c1: p(51, 269), c2: p(48, 274)),
            .init(to: p(50, 282), c1: p(46, 280), c2: p(47, 282)),
            .init(to: p(60, 282), c1: p(53, 283), c2: p(58, 283)),
            .init(to: p(63, 277), c1: p(63, 282), c2: p(64, 280)),
            .init(to: p(60, 266), c1: p(63, 274), c2: p(60, 270)),
            .init(to: p(61, 231), c1: p(60, 256), c2: p(61, 241)),
            .init(to: p(61, 205), c1: p(62, 220), c2: p(61, 212)),
            .init(to: p(63, 181), c1: p(61, 198), c2: p(63, 190)),
            .init(to: p(66, 151), c1: p(65, 170), c2: p(64, 157))
        ])
        return half.symmetricOutline
    }

    private static func regions(for aspect: MuscleFigureAspect) -> [(MuscleRegion, Path)] {
        var regions: [(MuscleRegion, Path)] = []
        func add(_ region: MuscleRegion, _ contour: Contour) {
            regions.append((region, contour.bilateral))
        }

        if aspect == .front {
            add(.chest, Contour(start: p(43, 55), curves: [
                .init(to: p(64, 54), c1: p(49, 52), c2: p(58, 53)),
                .init(to: p(64, 78), c1: p(65, 61), c2: p(65, 72)),
                .init(to: p(48, 81), c1: p(59, 82), c2: p(53, 84)),
                .init(to: p(42, 69), c1: p(45, 78), c2: p(43, 74)),
                .init(to: p(43, 55), c1: p(40, 63), c2: p(41, 59))
            ]))
            add(.frontShoulders, Contour(start: p(39, 50), curves: [
                .init(to: p(43, 55), c1: p(41, 50), c2: p(43, 52)),
                .init(to: p(40, 72), c1: p(42, 60), c2: p(42, 66)),
                .init(to: p(33, 66), c1: p(36, 73), c2: p(34, 70)),
                .init(to: p(39, 50), c1: p(32, 59), c2: p(34, 52))
            ]))
            add(.biceps, Contour(start: p(33, 73), curves: [
                .init(to: p(36, 78), c1: p(35, 73), c2: p(36, 75)),
                .init(to: p(30, 100), c1: p(35, 86), c2: p(34, 95)),
                .init(to: p(25, 99), c1: p(28, 103), c2: p(25, 103)),
                .init(to: p(27, 83), c1: p(24, 94), c2: p(26, 88)),
                .init(to: p(33, 73), c1: p(28, 78), c2: p(30, 74))
            ]))
            add(.abdominals, Contour(start: p(57, 85), curves: [
                .init(to: p(64, 84), c1: p(59, 84), c2: p(62, 84)),
                .init(to: p(64, 125), c1: p(65, 96), c2: p(65, 116)),
                .init(to: p(58, 124), c1: p(62, 127), c2: p(59, 127)),
                .init(to: p(55, 102), c1: p(56, 117), c2: p(55, 109)),
                .init(to: p(57, 85), c1: p(54, 95), c2: p(55, 89))
            ]))
            add(.quadriceps, Contour(start: p(47, 143), curves: [
                .init(to: p(61, 147), c1: p(51, 140), c2: p(58, 141)),
                .init(to: p(61, 174), c1: p(63, 153), c2: p(62, 164)),
                .init(to: p(59, 194), c1: p(59, 181), c2: p(62, 189)),
                .init(to: p(51, 198), c1: p(57, 199), c2: p(54, 201)),
                .init(to: p(47, 173), c1: p(50, 191), c2: p(48, 180)),
                .init(to: p(47, 143), c1: p(44, 160), c2: p(44, 151))
            ]))
        } else {
            add(.upperBack, Contour(start: p(59, 42), curves: [
                .init(to: p(64, 46), c1: p(61, 44), c2: p(63, 45)),
                .init(to: p(64, 80), c1: p(65, 58), c2: p(65, 71)),
                .init(to: p(54, 79), c1: p(61, 82), c2: p(57, 81)),
                .init(to: p(45, 65), c1: p(51, 75), c2: p(46, 69)),
                .init(to: p(43, 51), c1: p(44, 59), c2: p(43, 55)),
                .init(to: p(59, 42), c1: p(49, 48), c2: p(56, 47))
            ]))
            add(.rearShoulders, Contour(start: p(40, 50), curves: [
                .init(to: p(44, 54), c1: p(42, 50), c2: p(44, 51)),
                .init(to: p(41, 72), c1: p(44, 60), c2: p(44, 68)),
                .init(to: p(33, 69), c1: p(38, 75), c2: p(34, 73)),
                .init(to: p(40, 50), c1: p(31, 61), c2: p(33, 53))
            ]))
            add(.triceps, Contour(start: p(33, 75), curves: [
                .init(to: p(36, 80), c1: p(35, 75), c2: p(36, 77)),
                .init(to: p(30, 103), c1: p(35, 89), c2: p(33, 98)),
                .init(to: p(25, 100), c1: p(27, 105), c2: p(25, 104)),
                .init(to: p(27, 84), c1: p(24, 96), c2: p(26, 89)),
                .init(to: p(33, 75), c1: p(28, 79), c2: p(30, 76))
            ]))
            add(.lats, Contour(start: p(44, 76), curves: [
                .init(to: p(59, 85), c1: p(49, 78), c2: p(55, 80)),
                .init(to: p(60, 110), c1: p(62, 91), c2: p(61, 104)),
                .init(to: p(51, 123), c1: p(57, 116), c2: p(54, 119)),
                .init(to: p(49, 104), c1: p(49, 118), c2: p(49, 110)),
                .init(to: p(44, 76), c1: p(48, 95), c2: p(45, 85))
            ]))
            add(.spinalErectors, Contour(start: p(62, 88), curves: [
                .init(to: p(64, 88), c1: p(63, 87), c2: p(64, 87)),
                .init(to: p(64, 127), c1: p(65, 100), c2: p(65, 118)),
                .init(to: p(60, 126), c1: p(63, 129), c2: p(61, 129)),
                .init(to: p(62, 88), c1: p(59, 116), c2: p(61, 99))
            ]))
            add(.glutes, Contour(start: p(48, 131), curves: [
                .init(to: p(64, 133), c1: p(54, 127), c2: p(62, 128)),
                .init(to: p(64, 153), c1: p(65, 140), c2: p(66, 149)),
                .init(to: p(47, 158), c1: p(60, 161), c2: p(51, 161)),
                .init(to: p(48, 131), c1: p(43, 152), c2: p(45, 139))
            ]))
            add(.hamstrings, Contour(start: p(47, 162), curves: [
                .init(to: p(62, 160), c1: p(51, 164), c2: p(57, 163)),
                .init(to: p(60, 183), c1: p(63, 168), c2: p(61, 176)),
                .init(to: p(59, 200), c1: p(59, 190), c2: p(60, 196)),
                .init(to: p(51, 200), c1: p(56, 198), c2: p(54, 198)),
                .init(to: p(47, 162), c1: p(49, 190), c2: p(46, 173))
            ]))
            add(.calves, Contour(start: p(51, 208), curves: [
                .init(to: p(59, 209), c1: p(54, 205), c2: p(58, 205)),
                .init(to: p(60, 231), c1: p(61, 216), c2: p(61, 225)),
                .init(to: p(55, 248), c1: p(59, 238), c2: p(57, 244)),
                .init(to: p(49, 230), c1: p(52, 244), c2: p(49, 237)),
                .init(to: p(51, 208), c1: p(48, 221), c2: p(49, 214))
            ]))
        }

        // The lateral shoulder and forearm surfaces are visible from both sides.
        add(.sideShoulders, Contour(start: p(34, 52), curves: [
            .init(to: p(32, 69), c1: p(31, 56), c2: p(30, 63)),
            .init(to: p(29, 73), c1: p(32, 72), c2: p(31, 74)),
            .init(to: p(29, 61), c1: p(28, 70), c2: p(28, 65)),
            .init(to: p(34, 52), c1: p(30, 57), c2: p(32, 53))
        ]))
        add(.forearms, Contour(start: p(23, 107), curves: [
            .init(to: p(28, 108), c1: p(25, 105), c2: p(28, 105)),
            .init(to: p(23, 126), c1: p(27, 114), c2: p(25, 120)),
            .init(to: p(18, 137), c1: p(21, 131), c2: p(19, 136)),
            .init(to: p(15, 134), c1: p(16, 138), c2: p(15, 137)),
            .init(to: p(23, 107), c1: p(17, 124), c2: p(19, 113))
        ]))
        return regions
    }

    private static func details(for aspect: MuscleFigureAspect) -> Path {
        var lines = Path()
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            lines.move(to: p(x1, y1)); lines.addLine(to: p(x2, y2))
        }
        if aspect == .front {
            line(66, 53, 66, 79)
            for y: CGFloat in [94, 105, 116] {
                line(57, y, 64, y)
                line(68, y, 75, y)
            }
            // Kneecaps and the unhighlighted anterior shin establish the lower leg.
            for x: CGFloat in [55, 77] {
                lines.addRoundedRect(in: CGRect(x: x - 3.7, y: 201, width: 7.4, height: 6), cornerSize: CGSize(width: 3, height: 3))
                line(x, 214, x, 261)
            }
        } else {
            line(66, 46, 66, 127)
            line(66, 138, 66, 153)
            for x: CGFloat in [55, 77] {
                line(x, 252, x, 270)
            }
        }
        return lines
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}

/// Cubic contours keep both sides exactly symmetric while leaving each muscle distinct.
private struct Contour {
    struct Curve {
        let to: CGPoint
        let c1: CGPoint
        let c2: CGPoint
    }

    let start: CGPoint
    let curves: [Curve]

    private var path: Path {
        var result = Path()
        result.move(to: start)
        for curve in curves {
            result.addCurve(to: curve.to, control1: curve.c1, control2: curve.c2)
        }
        result.closeSubpath()
        return result
    }

    var bilateral: Path {
        var result = path
        result.addPath(path, transform: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 132, ty: 0))
        return result
    }

    var symmetricOutline: Path {
        var result = Path()
        result.move(to: start)
        for curve in curves {
            result.addCurve(to: curve.to, control1: curve.c1, control2: curve.c2)
        }
        let starts = [start] + curves.dropLast().map(\.to)
        for (curve, previous) in zip(curves, starts).reversed() {
            result.addCurve(to: mirror(previous), control1: mirror(curve.c2), control2: mirror(curve.c1))
        }
        result.closeSubpath()
        return result
    }

    private func mirror(_ point: CGPoint) -> CGPoint {
        CGPoint(x: 132 - point.x, y: point.y)
    }
}
