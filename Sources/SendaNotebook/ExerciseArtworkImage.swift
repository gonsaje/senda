import SwiftUI
import ImageIO

/// File-backed SwiftPM artwork uses the same explicit decoding path as the logo.
/// Named SwiftUI asset lookup does not display these plain PNGs on macOS.
@MainActor
enum ExerciseArtwork {
    private static let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 24 * 1_024 * 1_024
        return cache
    }()

    static func image(named name: String, maximumPixelSize: Int = 960) -> CGImage? {
        let key = "\(name)-\(maximumPixelSize)" as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        cache.setObject(image, forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}

struct ExerciseArtworkImage: View {
    let name: String
    var maximumPixelSize = 960

    var body: some View {
        if let image = ExerciseArtwork.image(named: name, maximumPixelSize: maximumPixelSize) {
            Image(image, scale: 1, label: Text(""))
                .renderingMode(.original).resizable().interpolation(.high)
        } else {
            Text("Illustration unavailable").font(.caption).foregroundStyle(NotebookStyle.quiet)
        }
    }
}
