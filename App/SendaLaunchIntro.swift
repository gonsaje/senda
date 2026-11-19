import SwiftUI
import SendaNotebook

struct SendaLaunchIntro: View {
    let finish: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    private static let words = ["trace", "your", "path", "to", "greatness"]
    private static let taglineFont = NotebookTypography.heading(18, relativeTo: .headline)
    private let trailSize = CGSize(width: 92, height: 80)
    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 247 / 255, green: 243 / 255, blue: 235 / 255)
            : Color(red: 48 / 255, green: 39 / 255, blue: 32 / 255)
    }

    var body: some View {
        GeometryReader { bounds in
            TimelineView(.animation(paused: reduceMotion)) { frame in
                let elapsed = startedAt.map { frame.date.timeIntervalSince($0) } ?? 0
                let trail = reduceMotion ? 1 : fraction(at: elapsed, from: 0.06, duration: 0.85)
                let wordmark = reduceMotion ? 1 : fraction(at: elapsed, from: 1.65, duration: 0.32)

                VStack(spacing: 18) {
                    Image("LaunchTrail")
                        .resizable()
                        .scaledToFit()
                        .mask(LaunchTrailReveal(progress: trail))
                        .frame(width: trailSize.width, height: trailSize.height)
                        .accessibilityHidden(true)

                    ZStack {
                        tagline(at: elapsed)
                            .font(Self.taglineFont)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(reduceMotion ? 0 : 1 - fraction(at: elapsed, from: 1.56, duration: 0.26))
                            .accessibilityLabel(Self.words.joined(separator: " "))
                            .accessibilityHidden(reduceMotion || elapsed < 0.45 || wordmark > 0.5)
                            .accessibilityIdentifier("senda-launch-tagline")

                        Image("LaunchWordmark")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 116, height: 40)
                            .opacity(wordmark)
                            .accessibilityLabel("Senda")
                            .accessibilityHidden(wordmark <= 0.5)
                            .accessibilityIdentifier("senda-launch-wordmark")
                    }
                }
                .foregroundStyle(ink)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .padding(.top, max(0, (bounds.size.height - trailSize.height) / 2))
            }
        }
        .background(Color("LaunchPaper"))
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("senda-launch-intro")
        .task(id: reduceMotion) {
            startedAt = .now
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 500 : 2420))
            } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.29)) { finish() }
        }
    }

    private func tagline(at elapsed: TimeInterval) -> Text {
        var text = AttributedString()
        for (index, word) in Self.words.enumerated() {
            let opacity = fraction(at: elapsed, from: 0.45 + Double(index) * 0.072, duration: 0.32)
            var run = AttributedString(index == 0 ? word : " " + word)
            run.foregroundColor = ink.opacity(opacity)
            text.append(run)
        }
        return Text(text)
    }

    private func fraction(at time: TimeInterval, from start: TimeInterval, duration: TimeInterval) -> Double {
        let t = min(1, max(0, (time - start) / duration))
        return t * t * (3 - 2 * t)
    }
}

// A mask for the LaunchTrail image. Coordinates follow the asset's 92 × 79.0251
// point bounds, from the fine tip at the top toward the wide lower-left end.
private struct LaunchTrailReveal: Shape {
    let progress: CGFloat

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
