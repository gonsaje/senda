import SwiftUI
import ImageIO

struct TrainingWordmark: View {
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
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 124, height: 32, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Senda")
    }
}
