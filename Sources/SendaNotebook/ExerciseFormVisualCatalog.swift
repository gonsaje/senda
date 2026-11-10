import Foundation

/// Offline form illustrations with the source and license needed for visible attribution.
/// A missing entry means no matching, reviewed illustration is bundled for that variation.
public struct ExerciseFormVisual: Identifiable, Equatable, Sendable {
    public struct Frame: Identifiable, Equatable, Sendable {
        public var id: String { resourceName }
        /// Image name in `Bundle.module`, without a file extension.
        public let resourceName: String
        public let phase: String
        public let accessibleDescription: String
    }

    public let id: String
    public let variationLabel: String
    public let frames: [Frame]
    public let sourceTitle: String
    public let sourceURL: URL
    public let creator: String
    public let licenseTitle: String
    public let licenseURL: URL
    public let modificationsNotice: String

    public static func guide(for id: String) -> ExerciseFormVisual? {
        all.first { $0.id == id }
    }

    private static func everkinetic(_ id: String, variation: String, sourceFile: String, frames: [Frame]) -> ExerciseFormVisual {
        ExerciseFormVisual(
            id: id,
            variationLabel: variation,
            frames: frames,
            sourceTitle: "Everkinetic",
            sourceURL: URL(string: "https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/\(sourceFile)")!,
            creator: "Greg Priday / Everkinetic",
            licenseTitle: "CC BY-SA 4.0",
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!,
            modificationsNotice: "Original PNGs; filenames changed for bundling."
        )
    }

    public static let all: [ExerciseFormVisual] = [
        everkinetic("bench", variation: "Flat barbell bench press", sourceFile: "bench-press-1.png", frames: [
                Frame(resourceName: "form-bench-lowered", phase: "Lowered", accessibleDescription: "Person lying on a flat bench with feet on the floor and a barbell lowered toward the chest."),
                Frame(resourceName: "form-bench-pressed", phase: "Pressed", accessibleDescription: "Person lying on a flat bench with the barbell above the chest and arms extended.")
            ]),
        everkinetic("deadlift", variation: "Barbell deadlift", sourceFile: "barbell-dead-lifts-1.png", frames: [
                Frame(resourceName: "form-deadlift-lowered", phase: "Lowered", accessibleDescription: "Person bent at the hips and knees, holding a barbell close to the lower legs."),
                Frame(resourceName: "form-deadlift-standing", phase: "Standing", accessibleDescription: "Person standing tall with the barbell held in front of the thighs.")
            ]),
        everkinetic("squat", variation: "Barbell back squat", sourceFile: "barbell-squat-1.png", frames: [
                Frame(resourceName: "form-squat-standing", phase: "Standing", accessibleDescription: "Person standing with a barbell supported across the upper back."),
                Frame(resourceName: "form-squat-lowered", phase: "Lowered", accessibleDescription: "Person bending the hips and knees into a squat, with the barbell across the upper back.")
            ]),
        everkinetic("romanian-deadlift", variation: "Barbell Romanian deadlift", sourceFile: "romanian-dead-lift-1.png", frames: [
                Frame(resourceName: "form-romanian-deadlift-standing", phase: "Standing", accessibleDescription: "Person standing with a barbell in front of the thighs."),
                Frame(resourceName: "form-romanian-deadlift-hinged", phase: "Hip hinge", accessibleDescription: "Person sending the hips back with a slight knee bend, lowering the barbell close to the legs.")
            ]),
        everkinetic("dumbbell-bench", variation: "Flat dumbbell bench press", sourceFile: "bench-press-dumbbell-1.png", frames: [
                Frame(resourceName: "form-dumbbell-bench-lowered", phase: "Lowered", accessibleDescription: "Person lying on a flat bench with dumbbells near the sides of the chest and elbows bent."),
                Frame(resourceName: "form-dumbbell-bench-pressed", phase: "Pressed", accessibleDescription: "Person lying on a flat bench with both dumbbells above the chest and arms extended.")
            ]),
        everkinetic("pull-up", variation: "Overhand pull-up", sourceFile: "pull-ups-1.png", frames: [
                Frame(resourceName: "form-pull-up-hanging", phase: "Hanging", accessibleDescription: "Person hanging from an overhead bar with an overhand grip and extended arms."),
                Frame(resourceName: "form-pull-up-raised", phase: "Raised", accessibleDescription: "Person pulling upward with bent elbows, bringing the head near the bar.")
            ]),
        everkinetic("leg-press", variation: "Inclined leg press", sourceFile: "leg-press-1.png", frames: [
                Frame(resourceName: "form-leg-press-lowered", phase: "Lowered", accessibleDescription: "Person seated in an inclined leg-press machine with the hips and knees bent and feet on the platform."),
                Frame(resourceName: "form-leg-press-pressed", phase: "Pressed", accessibleDescription: "Person seated in the leg-press machine with the platform pressed away and legs extended.")
            ]),
        everkinetic("leg-curl", variation: "Lying machine leg curl", sourceFile: "lying-leg-curl-machine-1.png", frames: [
                Frame(resourceName: "form-leg-curl-extended", phase: "Extended", accessibleDescription: "Person lying face down on a leg-curl machine with the roller behind the lower legs and knees extended."),
                Frame(resourceName: "form-leg-curl-curled", phase: "Curled", accessibleDescription: "Person lying face down and bending both knees to lift the roller toward the hips.")
            ]),
        everkinetic("leg-extension", variation: "Seated machine leg extension", sourceFile: "leg-extensions-1.png", frames: [
                Frame(resourceName: "form-leg-extension-bent", phase: "Bent", accessibleDescription: "Person seated against a machine backrest with knees bent and the roller in front of the lower legs."),
                Frame(resourceName: "form-leg-extension-extended", phase: "Extended", accessibleDescription: "Person seated against the backrest and extending both knees to raise the roller.")
            ]),
        everkinetic("lunge", variation: "Forward dumbbell lunge", sourceFile: "dumbbell-lunges-1.png", frames: [
                Frame(resourceName: "form-lunge-standing", phase: "Standing", accessibleDescription: "Person standing with a dumbbell at each side."),
                Frame(resourceName: "form-lunge-lowered", phase: "Forward lunge", accessibleDescription: "Person stepping forward and bending both knees into a lunge while holding dumbbells at the sides.")
            ]),
        everkinetic("triceps-extension", variation: "Cable rope pressdown", sourceFile: "triceps-pushdown-with-rope-and-cable-1.png", frames: [
                Frame(resourceName: "form-triceps-extension-bent", phase: "Bent", accessibleDescription: "Person standing at a high cable, holding the rope near the chest with elbows bent beside the torso."),
                Frame(resourceName: "form-triceps-extension-extended", phase: "Extended", accessibleDescription: "Person extending the elbows to press the rope ends downward beside the thighs.")
            ]),
        everkinetic("lateral-raise", variation: "Standing dumbbell lateral raise", sourceFile: "lateral-dumbbell-raises-1.png", frames: [
                Frame(resourceName: "form-lateral-raise-lowered", phase: "Lowered", accessibleDescription: "Person standing with a dumbbell lowered at each side."),
                Frame(resourceName: "form-lateral-raise-raised", phase: "Raised", accessibleDescription: "Person raising both dumbbells out to the sides near shoulder height with a small bend in the elbows.")
            ]),
        everkinetic("calf-raise", variation: "Calf press on leg-press machine", sourceFile: "calves-press-on-leg-machine-1.png", frames: [
                Frame(resourceName: "form-calf-raise-returned", phase: "Returned", accessibleDescription: "Person supported in an inclined leg-press machine with legs steady and the balls of the feet on the platform."),
                Frame(resourceName: "form-calf-raise-pressed", phase: "Ankle press", accessibleDescription: "Person pressing the platform through the forefeet by extending the ankles while keeping the legs steady.")
            ]),
        everkinetic("cable-row", variation: "Seated cable row", sourceFile: "seated-cable-rows-1.png", frames: [
                Frame(resourceName: "form-cable-row-reached", phase: "Reached", accessibleDescription: "Person seated at a low cable with arms reaching forward and a small bend in the knees."),
                Frame(resourceName: "form-cable-row-pulled", phase: "Pulled", accessibleDescription: "Person seated at a low cable with elbows drawn backward and the handle near the abdomen.")
            ]),
        everkinetic("push-up", variation: "Floor push-up", sourceFile: "push-ups-1.png", frames: [
                Frame(resourceName: "form-push-up-raised", phase: "Raised", accessibleDescription: "Person supported on the hands and toes with arms extended and head, trunk and legs aligned."),
                Frame(resourceName: "form-push-up-lowered", phase: "Lowered", accessibleDescription: "Person bending the elbows to lower the chest toward the floor while keeping the body aligned.")
            ])
    ]
}
