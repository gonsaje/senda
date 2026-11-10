import Foundation
import Testing
@testable import SendaNotebook
import SendaDomain

struct ExerciseVisualResourceTests {
    @Test @MainActor func everyFrameDecodesThroughTheImagePathUsedByTheApp() throws {
        for visual in ExerciseFormVisual.all {
            for frame in visual.frames {
                let thumbnail = try #require(ExerciseArtwork.image(named: frame.resourceName, maximumPixelSize: 192))
                #expect(thumbnail.width > 0 && thumbnail.height > 0)
                #expect(max(thumbnail.width, thumbnail.height) <= 192)
                let detail = try #require(ExerciseArtwork.image(named: frame.resourceName))
                #expect(detail.width > thumbnail.width && detail.height > thumbnail.height)
            }
        }
        #expect(ExerciseArtwork.image(named: "missing-form-test") == nil)
    }

    @Test func everyIllustratedGuideHasOfflinePNGFramesAndAttribution() throws {
        for exercise in Exercise.catalog {
            guard let visual = ExerciseFormVisual.guide(for: exercise.id) else { continue }
            #expect(visual.frames.count == 2)
            #expect(visual.id == exercise.id)
            #expect(!visual.variationLabel.isEmpty && !visual.creator.isEmpty)
            #expect(visual.sourceURL.scheme == "https" && visual.licenseURL.scheme == "https")
            #expect(visual.licenseTitle.contains("CC BY-SA"))
            for frame in visual.frames {
                #expect(!frame.phase.isEmpty && !frame.accessibleDescription.isEmpty)
                let url = try #require(Bundle.module.url(forResource: frame.resourceName, withExtension: "png"))
                let bytes = try Data(contentsOf: url)
                #expect(Array(bytes.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
                #expect(bytes.count > 1_000)
            }
        }
    }

    @Test func commonIllustrationsExistButDifferentVariationsAreNotSubstituted() {
        for id in ["bench", "squat", "deadlift", "push-up", "leg-curl", "lunge", "calf-raise"] {
            #expect(ExerciseFormVisual.guide(for: id) != nil)
        }
        // Available source poses use a different grip, seat or bar path.
        for id in ["row", "overhead-press", "lat-pulldown", "biceps-curl", "hip-thrust", "custom-test", "unknown"] {
            #expect(ExerciseFormVisual.guide(for: id) == nil)
        }
    }
}
