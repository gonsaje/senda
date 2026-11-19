import SwiftUI
import SendaNotebook

struct SendaLaunchIntro: View {
    let finish: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsWordmark = false

    // Match the size and center constraints of the system launch storyboard.
    private let trailSize = CGSize(width: 92, height: 80)
    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 247 / 255, green: 243 / 255, blue: 235 / 255)
            : Color(red: 48 / 255, green: 39 / 255, blue: 32 / 255)
    }

    var body: some View {
        GeometryReader { bounds in
            VStack(spacing: 18) {
                Image("LaunchTrail")
                    .resizable()
                    .scaledToFit()
                    .frame(width: trailSize.width, height: trailSize.height)
                    .accessibilityHidden(true)

                ZStack {
                    Text("trace your path to greatness")
                        .font(NotebookTypography.heading(18, relativeTo: .headline))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showsWordmark ? 0 : 1)
                        .accessibilityHidden(showsWordmark)
                        .accessibilityIdentifier("senda-launch-tagline")

                    Image("LaunchWordmark")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 116, height: 40)
                        .opacity(showsWordmark ? 1 : 0)
                        .accessibilityLabel("Senda")
                        .accessibilityHidden(!showsWordmark)
                        .accessibilityIdentifier("senda-launch-wordmark")
                }
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .padding(.top, max(0, (bounds.size.height - trailSize.height) / 2))
        }
        .background(Color("LaunchPaper"))
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("senda-launch-intro")
        .task {
            do {
                try await Task.sleep(for: .milliseconds(1250))
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                    showsWordmark = true
                }
                try await Task.sleep(for: .milliseconds(720))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { finish() }
            } catch is CancellationError {
                // Leaving the app during launch dismisses the intro.
            } catch {
                finish()
            }
        }
    }
}
