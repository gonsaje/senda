import SwiftUI
import SendaNotebook

struct SendaLaunchIntro: View {
    let tagline: LocalizedStringKey
    let startedAt: ContinuousClock.Instant
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trailProgress: CGFloat = 0

    static func taglines(for profileName: String?) -> [LocalizedStringKey] {
        var lines: [LocalizedStringKey] = ["Trace your own path.", "Every rep, a step.", "Your path. Your pace."]
        if let name = profileName, let word = name.split(whereSeparator: \.isWhitespace).first {
            let firstName = PersonNameComponentsFormatter().personNameComponents(from: name)?.givenName ?? String(word)
            lines.append("Welcome back, \(firstName)")
        }
        return lines
    }

    var body: some View {
        let layout = compact ? AnyLayout(HStackLayout(spacing: 5)) : AnyLayout(VStackLayout(spacing: 12))
        layout {
            Image("LaunchTrail")
                .resizable().scaledToFit()
                .mask(LaunchTrailReveal(progress: reduceMotion ? 1 : trailProgress))
                .frame(width: compact ? 25 : 92, height: compact ? 24 : 80)
            Text(tagline)
                .font(NotebookTypography.heading(compact ? 12 : 18, relativeTo: compact ? .caption : .headline))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(compact ? .leading : .center)
        }
        .foregroundStyle(NotebookStyle.ink)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            // Continue the same stroke when the opening screen gives way to the Train header.
            let elapsed = startedAt.duration(to: .now) / .seconds(1)
            let duration = 0.65
            trailProgress = min(1, max(0, elapsed / duration))
            if trailProgress < 1 {
                withAnimation(reduceMotion ? nil : .linear(duration: duration * (1 - trailProgress))) {
                    trailProgress = 1
                }
            }
        }
    }
}

// A mask for the LaunchTrail image. Coordinates follow the asset's 92 × 79.0251
// point bounds, from the fine tip at the top toward the wide lower-left end.
private struct LaunchTrailReveal: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        guard progress < 1 else { return Path(rect) }

        let position = progress * CGFloat(Self.sections.count - 1)
        let index = min(Int(position), Self.sections.count - 2)
        let fraction = position - CGFloat(index)
        let start = Self.sections[index]
        let end = Self.sections[index + 1]

        func interpolate(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * fraction,
                    y: a.y + (b.y - a.y) * fraction)
        }

        var path = Path()
        path.move(to: Self.sections[0].outer)
        for section in Self.sections[...index].dropFirst() {
            path.addLine(to: section.outer)
        }
        path.addLine(to: interpolate(start.outer, end.outer))
        path.addLine(to: interpolate(start.inner, end.inner))
        for section in Self.sections[...index].reversed() {
            path.addLine(to: section.inner)
        }
        path.closeSubpath()

        let scale = min(rect.width / 92, rect.height / 79.0251)
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                               tx: rect.midX - 46 * scale,
                                               ty: rect.midY - 79.0251 / 2 * scale))
    }

    private struct Section {
        let outer: CGPoint
        let inner: CGPoint

        init(_ outerX: CGFloat, _ outerY: CGFloat, _ innerX: CGFloat, _ innerY: CGFloat) {
            outer = CGPoint(x: outerX, y: outerY)
            inner = CGPoint(x: innerX, y: innerY)
        }
    }

    // Equal-distance samples along each edge of the LaunchTrail vector, extended
    // 1.4 points outward so the artwork itself always defines the visible outline.
    private static let sections = [
        Section(69.5, -1.4, 69.0, 1.3),
        Section(77.7, -0.7, 75.7, 2.7),
        Section(83.8, 1.7, 78.5, 5.0),
        Section(86.6, 8.1, 75.5, 7.1),
        Section(81.1, 12.4, 70.6, 8.1),
        Section(75.1, 14.2, 65.3, 9.1),
        Section(69.2, 15.5, 60.0, 10.1),
        Section(63.3, 16.8, 54.7, 11.0),
        Section(57.6, 18.2, 49.4, 12.0),
        Section(52.3, 20.0, 44.1, 13.4),
        Section(49.2, 23.5, 38.9, 15.3),
        Section(51.7, 26.8, 34.0, 18.0),
        Section(56.9, 28.8, 29.5, 21.6),
        Section(62.6, 30.3, 26.7, 27.0),
        Section(68.4, 31.9, 28.3, 33.0),
        Section(74.2, 33.7, 33.0, 36.7),
        Section(79.9, 35.9, 38.6, 37.8),
        Section(85.5, 38.4, 44.0, 38.6),
        Section(90.8, 42.1, 49.3, 39.3),
        Section(93.4, 48.4, 54.6, 39.9),
        Section(91.7, 54.8, 59.6, 41.0),
        Section(87.6, 59.8, 63.6, 43.0),
        Section(82.5, 63.4, 63.5, 46.2),
        Section(77.0, 66.3, 59.8, 48.7),
        Section(71.3, 68.6, 54.9, 50.1),
        Section(65.6, 70.4, 49.7, 51.3),
        Section(59.7, 72.0, 44.4, 52.5),
        Section(53.8, 73.3, 39.2, 53.7),
        Section(47.9, 74.5, 33.9, 55.0),
        Section(41.9, 75.4, 28.7, 56.4),
        Section(35.9, 76.3, 23.5, 58.1),
        Section(30.0, 77.0, 18.4, 60.1),
        Section(24.0, 77.7, 13.5, 62.5),
        Section(18.1, 78.4, 8.8, 65.4),
        Section(12.1, 79.2, 4.4, 68.9),
        Section(6.1, 79.9, 0.8, 73.4),
        Section(-1.9, 82.4, -3.3, 80.5)
    ]
}
