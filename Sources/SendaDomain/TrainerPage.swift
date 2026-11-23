import Foundation

/// Only these fields belong on the trainer's reader-facing page.
public struct TrainerPage: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var credential: String
    public var bio: String
    public var programTitle: String
    public var groupsIntoProgram: Bool?
    public var publicationID: UUID?
    public var version: Int?
    public var offersProgram: Bool { groupsIntoProgram ?? !programTitle.isEmpty }
    public var weeks: Int
    public var workouts: [WorkoutTemplate]
    public var website: String
    public var instagram: String

    public init(name: String = "", credential: String = "", bio: String = "", programTitle: String = "",
                weeks: Int = 4, workouts: [WorkoutTemplate] = [], website: String = "", instagram: String = "") {
        id = UUID()
        self.name = name
        self.credential = credential
        self.bio = bio
        self.programTitle = programTitle
        self.weeks = weeks
        self.workouts = workouts
        self.website = website
        self.instagram = instagram
    }

    public func makeProgram() throws -> TrainingProgram? {
        guard offersProgram else { return nil }
        let offsets = workouts.count == 3 ? [0, 2, 4] : (workouts.count == 4 ? [0, 1, 3, 5] : [0, 1, 2, 4, 5])
        let sessions = try zip(workouts, offsets).map { workout, offset in
            let lifts = try workout.exerciseIDs.map { id in
                guard let plan = workout.exercisePlans[id] else { throw TrainerPageError.missingTargets(workout.name) }
                return ProgramExercise(exerciseID: id, plan: try plan.validated())
            }
            var session = ProgramSession(title: workout.name, dayOffset: offset, exercises: lifts, supersets: workout.supersets ?? [])
            session.trainerDetails = workout.trainerDetails
            return session
        }
        var program = TrainingProgram(id: (publicationID ?? id).uuidString.lowercased(), title: programTitle, summary: bio,
            author: name, credential: credential, sourceURL: website.isEmpty ? nil : website,
            blocks: [ProgramBlock(title: programTitle, weeks: weeks, progression: "", sessions: sessions)])
        program.trainerPageID = id
        program.trainerVersion = version ?? 1
        return program
    }

    public func validate(availableExercises: Set<String>? = nil) throws {
        guard TrainingProgram.validTitle(name), TrainingProgram.validTitle(credential),
              !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, TrainingProgram.validText(bio, max: 300),
              !offersProgram || (TrainingProgram.validTitle(programTitle) && (1...12).contains(weeks)) else { throw TrainerPageError.details }
        guard (3...5).contains(workouts.count), Set(workouts.map(\.id)).count == workouts.count else {
            throw TrainerPageError.workoutCount
        }
        let available = availableExercises ?? Set(workouts.flatMap(\.exerciseIDs))
        for workout in workouts {
            guard UUID(uuidString: workout.id) != nil else { throw WorkoutTemplateError.invalidID }
            guard workout.exerciseIDs.count <= 30 else { throw ProgramError.exerciseList }
            _ = try workout.validated(against: available)
            guard workout.exerciseIDs.allSatisfy({ workout.exercisePlans[$0] != nil }) else {
                throw TrainerPageError.missingTargets(workout.name)
            }
        }
        try makeProgram()?.validated(against: available)
        for address in [website, instagram] where !address.isEmpty {
            guard TrainingProgram.validSource(address), URL(string: address)?.scheme?.lowercased() == "https" else {
                throw TrainerPageError.links
            }
        }
        if !instagram.isEmpty {
            guard let host = URL(string: instagram)?.host?.lowercased(),
                  ["instagram.com", "www.instagram.com"].contains(host) else { throw TrainerPageError.links }
        }
    }

    public static let sample: TrainerPage = {
        func workout(_ id: String, _ title: String, _ minutes: Int, _ lifts: [(String, Int)]) -> WorkoutTemplate {
            WorkoutTemplate(id: id, name: title, exerciseIDs: lifts.map(\.0),
                exercisePlans: Dictionary(uniqueKeysWithValues: lifts.map { exercise, reps in
                    (exercise, ExercisePlan(workingSets: 3, minimumReps: reps, maximumReps: reps))
                }), trainerDetails: TrainerWorkoutDetails(minutes: minutes, equipment: "Dumbbells and bench",
                    notes: "Choose a weight you could lift for two more reps."))
        }
        var page = TrainerPage(name: "Maya Ellis", credential: "ACE Certified Personal Trainer",
            bio: "I help new lifters get strong with dumbbells.", programTitle: "Dumbbell Foundations",
            workouts: [
                workout("472c2b06-eac2-45e7-b291-51b7e9f7fb6a", "Full Body A", 35, [
                    ("goblet-squat", 8), ("dumbbell-floor-press", 10), ("one-arm-dumbbell-row", 10), ("hammer-curl", 10)]),
                workout("2fb41f87-9c0a-4df0-bad8-f39f4a1bdce8", "Full Body B", 30, [
                    ("dumbbell-romanian-deadlift", 8), ("dumbbell-shoulder-press", 8), ("reverse-lunge", 10)]),
                workout("ef50b182-b976-4dc2-a032-768ff8fa31e9", "Full Body C", 40, [
                    ("bulgarian-split-squat", 8), ("incline-dumbbell-bench", 10), ("chest-supported-dumbbell-row", 10)])
            ])
        page.id = UUID(uuidString: "48d71ca6-0992-4e4a-9a13-f30f66fdc4fe")!
        return page
    }()
}

public struct TrainerApplication: Codable, Equatable, Sendable {
    public var name: String
    public var credential: String
    public var credentialID: String
    public var expires: TrainingDay
    public var preview: TrainerPage?
    public var locallyApproved: Bool?
    public var listedOnDevice: Bool?
    public private(set) var published: TrainerPage?

    private enum CodingKeys: String, CodingKey { case name, credential, credentialID, expires, preview, locallyApproved, listedOnDevice, published }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        name = try box.decode(String.self, forKey: .name)
        credential = try box.decode(String.self, forKey: .credential)
        credentialID = try box.decode(String.self, forKey: .credentialID)
        expires = try box.decode(TrainingDay.self, forKey: .expires)
        preview = try box.decodeIfPresent(TrainerPage.self, forKey: .preview)
        locallyApproved = try box.decodeIfPresent(Bool.self, forKey: .locallyApproved)
        listedOnDevice = try box.decodeIfPresent(Bool.self, forKey: .listedOnDevice)
        published = try box.decodeIfPresent(TrainerPage.self, forKey: .published)
        // Migrate the single live snapshot used by the first local build.
        if published == nil, listedOnDevice == true {
            if let preview, (try? preview.validate()) != nil { published = preview }
            else { listedOnDevice = false }
        }
    }

    public mutating func publish(on day: TrainingDay, availableExercises: Set<String>) throws {
        guard locallyApproved == true, expires >= day, var draft = preview else { throw TrainerPageError.review }
        try draft.validate(availableExercises: availableExercises)
        if let last = published {
            guard draft.id == last.id else { throw TrainerPageError.details }
            if draft != last {
                for i in draft.workouts.indices {
                    if let prior = last.workouts.first(where: { $0.id == draft.workouts[i].id }),
                       draft.workouts[i] != prior { draft.workouts[i].startNewTrainerVersion() }
                }
                draft.version = (last.version ?? 1) + 1
                draft.publicationID = UUID()
            }
        } else { draft.version = 1 }
        published = draft
        preview = draft
        listedOnDevice = true
    }

    public func listing(on day: TrainingDay) -> TrainerPage? {
        guard locallyApproved == true, listedOnDevice == true, expires >= day else { return nil }
        return published
    }

    public init(name: String, credential: String, credentialID: String, expires: TrainingDay) {
        self.name = name
        self.credential = credential
        self.credentialID = credentialID
        self.expires = expires
    }

    public func validate() throws {
        guard [name, credential, credentialID].allSatisfy(TrainingProgram.validTitle) else { throw TrainerPageError.application }
        guard preview?.id != TrainerPage.sample.id, published?.id != TrainerPage.sample.id else { throw TrainerPageError.details }
        if let published { try published.validate() }
        if listedOnDevice == true && (locallyApproved != true || published == nil) { throw TrainerPageError.application }
    }
}

public enum TrainerPageError: LocalizedError {
    case application, details, workoutCount, links, review, workoutDetails, missingTargets(String)
    public var errorDescription: String? {
        switch self {
        case .missingTargets(let workout): "Set the working sets and reps for every exercise in \(workout)."
        case .workoutDetails: "Use a duration of 1–1440 minutes, equipment up to 200 characters and notes up to 2000 characters."
        case .review: "Publishing requires a current credential and local approval."
        case .application: "Enter the name on your credential, certification, and credential number (up to 80 characters each)."
        case .details: "Enter a name, credential and bio of up to 300 characters. A grouped program also needs a title and 1–12 weeks."
        case .workoutCount: "Choose three to five different workouts."
        case .links: "Use full https links. The Instagram link must open instagram.com."
        }
    }
}
