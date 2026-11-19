import SwiftUI
import ImageIO

struct TrainingWordmark: View {
    var width: CGFloat = 125
    @Environment(\.colorScheme) private var colorScheme
    private static let artwork: CGImage = {
        guard let url = Bundle.module.url(forResource: "senda-wordmark", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            preconditionFailure("The bundled Senda logo could not be loaded.")
        }
        return image
    }()

    var body: some View {
        Image(Self.artwork, scale: 1, label: Text("Senda"))
            .renderingMode(colorScheme == .dark ? .template : .original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .foregroundStyle(NotebookStyle.ink)
            .frame(width: width, height: width * 32 / 125, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Senda")
    }
}
