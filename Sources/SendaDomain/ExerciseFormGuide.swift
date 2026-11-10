import Foundation

public struct ExerciseFormGuide: Identifiable, Equatable, Sendable {
    public let id: String
    public let setup: String
    public let movement: String
    public let cue: String
    public let sourceTitle: String
    public let sourceURL: URL

    public static func guide(for id: String) -> ExerciseFormGuide? { all.first { $0.id == id } }
    public static func search(_ query: String, in exercises: [Exercise]) -> [Exercise] {
        let key = ExerciseLibrary.searchKey(query)
        return exercises.filter {
            key.isEmpty || ExerciseLibrary.searchKey([$0.name, $0.shortName, $0.group.rawValue, $0.equipmentType.rawValue].joined(separator: " ")).contains(key)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private static func ace(_ id: String, _ path: String, _ setup: String, _ movement: String, _ cue: String) -> ExerciseFormGuide {
        ExerciseFormGuide(id: id, setup: setup, movement: movement, cue: cue, sourceTitle: "ACE Exercise Library",
            sourceURL: URL(string: "https://www.acefitness.org/resources/everyone/exercise-library/\(path)/")!)
    }
    public static let all: [ExerciseFormGuide] = [
        ace("bench", "5/chest-press",
            "Lie on a flat bench with both feet planted. Take a full grip a little wider than your shoulders.",
            "Lower the bar toward your chest under control, then press it upward while keeping your hips on the bench.",
            "Keep the bar balanced and use a rack with appropriate safeties or a spotter."),
        ace("deadlift", "6/deadlift",
            "Stand close to the bar with feet around shoulder width. Bend at your hips and knees to grip the bar, keeping your back steady.",
            "Push through your feet and extend your hips to stand tall. Reverse the movement to return the bar to the floor.",
            "Keep the bar close to your legs; finish tall without leaning backward."),
        ace("squat", "11/back-squat",
            "Position the bar across your upper back in a rack. Grip firmly, stand clear of the hooks and set your feet just wider than your shoulders.",
            "Bend your hips and knees to lower with control, keeping your chest lifted. Press through your feet to return to standing.",
            "Keep your trunk steady and use a rack with safeties set for your range of motion."),
        ace("row", "12/bent-over-row",
            "Hold the bar with an overhand grip. Hinge forward at your hips with a small knee bend and a steady back.",
            "Pull the bar toward your abdomen, then straighten your arms slowly to lower it.",
            "Keep your torso still rather than standing up to move the weight."),
        ace("overhead-press", "71/standing-shoulder-press",
            "Take the bar from a shoulder-height rack. Hold it across the front of your shoulders with your hands around shoulder width.",
            "Press the bar overhead while standing tall, then lower it smoothly to your shoulders.",
            "Keep your trunk steady rather than arching your lower back to finish the press."),
        ace("lat-pulldown", "158/seated-lat-pulldown",
            "Adjust the thigh pad so you sit securely. Grip the bar overhead and keep your trunk braced with a small backward lean.",
            "Draw your elbows down toward your sides, bringing the bar toward your upper chest. Let it rise under control.",
            "Keep your lean consistent; avoid swinging backward or pulling behind your neck."),
        ace("romanian-deadlift", "317/romanian-deadlift",
            "Stand with the bar in front of your thighs, a small bend in your knees and a steady back.",
            "Send your hips backward as the bar moves down close to your legs. Stop within a controlled range, then extend your hips to stand.",
            "Move from your hips; the bar does not have to reach the floor."),
        ace("dumbbell-bench", "19/chest-press",
            "Lie on a flat bench with a dumbbell in each hand. Plant your feet and keep your shoulders supported by the bench.",
            "Lower both dumbbells toward the sides of your chest, then press upward smoothly.",
            "Keep your wrists aligned with your forearms and avoid bouncing at the bottom."),
        ace("pull-up", "191/pull-ups",
            "Grip a secure overhead bar with your palms facing away. Brace your trunk and keep your body aligned beneath your hands.",
            "Draw your elbows downward to lift your body until your chin reaches bar height. Lower with control until your arms extend.",
            "Keep your body quiet rather than swinging to complete the rep."),
        ace("leg-press", "154/seated-leg-press",
            "Adjust the seat so your back and hips stay supported. Place your feet on the plate with your heels in contact.",
            "Press the platform away, stopping short of locking your knees. Bend your hips and knees to return slowly.",
            "Keep your hips on the seat and stop the return before your lower back rounds."),
        ace("leg-curl", "153/lying-hamstrings-curl",
            "For the lying machine, align your knees with its pivot and position the pad against your lower legs, above your heels.",
            "Bend your knees to bring the pad toward your hips. Lower it slowly while keeping your trunk supported.",
            "Keep your hips down and avoid arching your lower back."),
        ExerciseFormGuide(id: "leg-extension",
            setup: "Adjust the seat so your knees align with the machine pivot and the pad rests near your ankles.",
            movement: "Straighten your knees against the pad, stopping short of locking them, then lower smoothly.",
            cue: "Stay supported against the backrest; reduce the load if you need to arch your back.",
            sourceTitle: "Hawaii Pacific Health · Seated leg extensions",
            sourceURL: URL(string: "https://livinghealthy.hawaiipacifichealth.org/wellness/fitness/your-exercise-routine-seated-leg-extensions")!),
        ace("lunge", "363/lunge",
            "Stand with feet around hip width and a dumbbell at each side. Keep your trunk tall.",
            "Step forward, then bend both knees to lower through a comfortable range. Push through your front foot to return and repeat on the other side.",
            "Use a controlled step and keep your balance before adding weight."),
        ace("biceps-curl", "44/seated-biceps-curl",
            "Sit against a backrest with feet planted. Hold the dumbbells at your sides with palms facing forward.",
            "Bend your elbows to lift both dumbbells, then extend your arms slowly to lower them.",
            "Keep your elbows near your sides and your wrists steady; avoid leaning back."),
        ace("triceps-extension", "3/triceps-pressdown",
            "Stand facing a high cable with a rope attachment. Hold both ends and bring your elbows near your sides.",
            "Extend your elbows to press the rope downward, then bend them to return under control.",
            "Keep your upper arms and torso quiet; this guide covers the cable pressdown variation."),
        ace("lateral-raise", "26/lateral-raise",
            "Stand steadily with a light dumbbell at each side and a small bend in your elbows.",
            "Lift your arms out to the sides to roughly shoulder height, then lower slowly.",
            "Keep your torso upright and your wrists neutral; avoid swinging the weights."),
        ace("calf-raise", "294/calf-raise",
            "For the seated foot-press machine, support your legs and place the balls of your feet on the platform.",
            "Press through your forefeet to extend your ankles, then return slowly through a comfortable range.",
            "Keep your legs steady and move at your ankles rather than bending your knees."),
        ExerciseFormGuide(id: "hip-thrust",
            setup: "Support your shoulders on a stable bench, plant your feet and position a padded bar across your hips.",
            movement: "Press through your feet and lift your hips until your shoulders, hips and knees align. Lower with control.",
            cue: "Finish by extending your hips, without arching your lower back.",
            sourceTitle: "ACE · Understanding the barbell hip thrust",
            sourceURL: URL(string: "https://www.acefitness.org/continuing-education/certified/november-2019/7403/understanding-the-barbell-hip-thrust/")!),
        ace("cable-row", "48/seated-row",
            "Sit at a low cable with your knees slightly bent. Hold the handle and keep your chest lifted.",
            "Draw your elbows backward beside your ribs, bringing the handle toward your abdomen. Reach forward slowly to return.",
            "Keep your torso steady rather than rocking to move the stack."),
        ace("push-up", "41/push-up",
            "Place your hands around shoulder width and extend your legs behind you. Brace your trunk to keep your head, hips and legs aligned.",
            "Bend your elbows to lower your body as one unit, then press the floor away to rise.",
            "Keep your hips from sagging or lifting ahead of your chest.")
    ]
}
