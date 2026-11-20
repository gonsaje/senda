import Foundation

public struct ProgramExercise: Codable, Equatable, Sendable {
    public var exerciseID: String
    public var plan: ExercisePlan
    public var targetRIR: Int?
    public var restSeconds: Int?

    public init(exerciseID: String, plan: ExercisePlan = .init(workingSets: 2, minimumReps: 8, maximumReps: 8),
                targetRIR: Int? = nil, restSeconds: Int? = nil) {
        self.exerciseID = exerciseID
        self.plan = plan
        self.targetRIR = targetRIR
        self.restSeconds = restSeconds
    }
}

public struct ProgramSession: Codable, Equatable, Sendable {
    public var title: String
    /// Relative to the program's start, repeated in every week of this block.
    public var dayOffset: Int
    public var exercises: [ProgramExercise]
    public var supersets: [SupersetPlan]

    public init(title: String = "", dayOffset: Int = 0, exercises: [ProgramExercise] = [], supersets: [SupersetPlan] = []) {
        self.title = title
        self.dayOffset = dayOffset
        self.exercises = exercises
        self.supersets = supersets
    }
}

public struct ProgramBlock: Codable, Equatable, Sendable {
    public var title: String
    public var weeks: Int
    public var progression: String
    public var sessions: [ProgramSession]

    public init(title: String = "", weeks: Int = 1, progression: String = "", sessions: [ProgramSession] = []) {
        self.title = title
        self.weeks = weeks
        self.progression = progression
        self.sessions = sessions
    }
}

public struct TrainingProgram: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var author: String?
    public var credential: String?
    public var sourceURL: String?
    public var coachingNotes: String?
    public var blocks: [ProgramBlock]

    public init(id: String = UUID().uuidString.lowercased(), title: String = "", summary: String = "", author: String? = nil,
                credential: String? = nil, sourceURL: String? = nil, coachingNotes: String? = nil, blocks: [ProgramBlock] = []) {
        self.id = id
        self.title = title
        self.summary = summary
        self.author = author
        self.credential = credential
        self.sourceURL = sourceURL
        self.coachingNotes = coachingNotes
        self.blocks = blocks
    }

    /// Safe during editing and while checking documents from other devices.
    public var weeks: Int { blocks.reduce(0) { $0 + min(53, max(0, $1.weeks)) } }

    public func copyForEditing() -> Self {
        var copy = self
        copy.id = UUID().uuidString.lowercased()
        copy.title = String(title.prefix(72)) + " (copy)"
        copy.author = nil
        copy.credential = nil
        return copy
    }

    public func exportData(customExercises: [Exercise] = []) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let file = ProgramFile(version: customExercises.isEmpty ? 1 : 2, program: self, customExercises: customExercises.isEmpty ? nil : customExercises)
        let formatted = try encoder.encode(file)
        if formatted.count <= Self.maximumImportBytes { return formatted }
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let compact = try encoder.encode(file)
        guard compact.count <= Self.maximumImportBytes else { throw ProgramError.exportTooLarge }
        return compact
    }

    public static let maximumImportBytes = 2 * 1024 * 1024
    public static func decodeFile(_ data: Data) throws -> Self {
        try ProgramFile.decode(data).program
    }

    public var referencedExerciseIDs: Set<String> { Set(blocks.flatMap(\.sessions).flatMap(\.exercises).map(\.exerciseID)) }

    package func mappingExercises(_ mapping: [String: String]) -> Self {
        guard !mapping.isEmpty else { return self }
        var copy = self
        for i in copy.blocks.indices {
            for j in copy.blocks[i].sessions.indices {
                var session = copy.blocks[i].sessions[j]
                for k in session.exercises.indices {
                    let id = session.exercises[k].exerciseID
                    session.exercises[k].exerciseID = mapping[id] ?? id
                }
                session.supersets = session.supersets.map {
                    SupersetPlan(first: mapping[$0.first] ?? $0.first, second: mapping[$0.second] ?? $0.second,
                                 rounds: $0.rounds, restSeconds: $0.restSeconds)
                }
                copy.blocks[i].sessions[j] = session
            }
        }
        return copy
    }

    @discardableResult public func validated(against availableExercises: Set<String>) throws -> Self {
        guard UUID(uuidString: id) != nil || Self.catalog.contains(where: { $0.id == id }) else { throw ProgramError.invalidID }
        guard Self.validTitle(title) else { throw ProgramError.invalidTitle }
        guard Self.validText(summary, max: 2000), Self.validText(author, max: 100), Self.validText(credential, max: 100),
              Self.validText(coachingNotes, max: 4000) else { throw ProgramError.invalidDetails }
        if let credential, !credential.isEmpty, author?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            throw ProgramError.credentialNeedsAuthor
        }
        guard Self.validSource(sourceURL) else { throw ProgramError.invalidSource }
        guard (1...52).contains(blocks.count), (1...52).contains(weeks) else { throw ProgramError.invalidLength }
        for block in blocks {
            guard Self.validTitle(block.title), Self.validText(block.progression, max: 2000) else { throw ProgramError.invalidBlock }
            guard (1...52).contains(block.weeks) else { throw ProgramError.invalidLength }
            guard (1...7).contains(block.sessions.count), Set(block.sessions.map(\.dayOffset)).count == block.sessions.count
                else { throw ProgramError.sessionDays }
            for session in block.sessions {
                guard Self.validTitle(session.title), (0...6).contains(session.dayOffset) else { throw ProgramError.invalidSession }
                let ids = session.exercises.map(\.exerciseID)
                guard (1...30).contains(ids.count), Set(ids).count == ids.count else { throw ProgramError.exerciseList }
                guard Set(ids).isSubset(of: availableExercises) else { throw ProgramError.unavailableExercise }
                for exercise in session.exercises { try Self.validateExercise(exercise) }
                do { try SupersetPlan.validate(session.supersets, order: ids) }
                catch { throw ProgramError.invalidPair }
            }
        }
        return self
    }

    static func validSource(_ address: String?) -> Bool {
        guard let address, !address.isEmpty else { return true }
        guard address.count <= 2048, let url = URLComponents(string: address),
              ["https", "http"].contains(url.scheme?.lowercased()), let host = url.host, !host.isEmpty
        else { return false }
        return url.user == nil && url.password == nil
    }

    static func validTitle(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 80 &&
            value.unicodeScalars.allSatisfy { !$0.properties.isWhitespace || $0 == " " } && validText(value, max: 80)
    }

    static func validText(_ value: String?, max: Int) -> Bool {
        guard let value else { return true }
        return value.count <= max && value.unicodeScalars.allSatisfy { $0 == "\n" || $0 == "\t" || $0.properties.generalCategory != .control }
    }

    static func validateExercise(_ exercise: ProgramExercise) throws {
        guard (try? exercise.plan.validated()) != nil,
              exercise.targetRIR.map({ (0...5).contains($0) }) ?? true,
              exercise.restSeconds.map({ (0...3600).contains($0) }) ?? true else { throw ProgramError.invalidPrescription }
    }
}

package struct ProgramFile: Codable {
    let version: Int
    package let program: TrainingProgram
    package let customExercises: [Exercise]?

    package static func decode(_ data: Data) throws -> Self {
        guard data.count <= TrainingProgram.maximumImportBytes else { throw ProgramError.fileTooLarge }
        guard let file = try? JSONDecoder().decode(Self.self, from: data) else { throw ProgramError.invalidFile }
        guard (1...2).contains(file.version) else { throw ProgramError.unsupportedVersion }
        let supplied = file.customExercises ?? []
        guard (file.version == 2) == !supplied.isEmpty else { throw ProgramError.invalidFile }
        let referenced = file.program.referencedExerciseIDs
        guard supplied.allSatisfy({ referenced.contains($0.id) && !$0.isArchived }) else { throw ProgramError.invalidFile }
        return file
    }
}

/// Calendar rows have enough information for Week. The exercise prescriptions and
/// coaching notes come from one frozen definition shared by the whole enrollment.
public struct ScheduledProgramReference: Codable, Equatable, Sendable {
    public let programID: String
    public let programTitle: String
    public let sessionTitle: String
    public let week: Int
    public let dayOffset: Int
    public let start: TrainingDay

    public init(program: TrainingProgram, start: TrainingDay, slot: ProgramScheduleSlot) {
        self.start = start
        programID = program.id
        programTitle = program.title
        sessionTitle = slot.session.title
        week = slot.week
        dayOffset = slot.session.dayOffset
    }
}

public struct ScheduledProgramSession: Equatable, Sendable {
    public let programID: String
    public let programTitle: String
    public let blockTitle: String
    public let sessionTitle: String
    public let week: Int
    public let start: TrainingDay
    public let progression: String
    public let coachingNotes: String?
    public let author: String?
    public let credential: String?
    public let sourceURL: String?
    public let exercises: [ProgramExercise]

    public init(program: TrainingProgram, start: TrainingDay, week: Int, block: ProgramBlock, session: ProgramSession) {
        programID = program.id
        programTitle = program.title
        self.start = start
        self.week = week
        blockTitle = block.title
        sessionTitle = session.title
        progression = block.progression
        coachingNotes = program.coachingNotes
        author = program.author
        credential = program.credential
        sourceURL = program.sourceURL
        exercises = session.exercises
    }
}

public struct ProgramEnrollment: Codable, Equatable, Sendable {
    public var programID: String { program.id }
    public let program: TrainingProgram
    public let start: TrainingDay

    public init(program: TrainingProgram, start: TrainingDay) {
        self.program = program
        self.start = start
    }

    public func session(for reference: ScheduledProgramReference) -> ScheduledProgramSession? {
        guard programID == reference.programID, start == reference.start, reference.week >= 1 else { return nil }
        var remainingWeeks = reference.week
        for block in program.blocks {
            if remainingWeeks <= block.weeks {
                guard let session = block.sessions.first(where: { $0.dayOffset == reference.dayOffset }) else { return nil }
                return ScheduledProgramSession(program: program, start: start, week: reference.week, block: block, session: session)
            }
            remainingWeeks -= block.weeks
        }
        return nil
    }

    struct Key: Hashable { let programID: String; let start: TrainingDay }
    var key: Key { Key(programID: programID, start: start) }
}

public struct ProgramScheduleSlot: Identifiable, Sendable {
    public var id: TrainingDay { day }
    public let day: TrainingDay
    public let week: Int
    public let blockTitle: String
    public let session: ProgramSession
    public let isOccupied: Bool
    public let isScheduled: Bool

    public init(day: TrainingDay, week: Int, blockTitle: String, session: ProgramSession, isOccupied: Bool, isScheduled: Bool) {
        self.day = day; self.week = week; self.blockTitle = blockTitle; self.session = session
        self.isOccupied = isOccupied; self.isScheduled = isScheduled
    }
}

public enum ProgramError: LocalizedError {
    case invalidID, invalidTitle, invalidDetails, invalidSource, invalidBlock, invalidLength, sessionDays, invalidSession
    case exerciseList, unavailableExercise, invalidPrescription, invalidPair, credentialNeedsAuthor, duplicateID, immutable
    case allOccupied, invalidFile, fileTooLarge, exportTooLarge, unsupportedVersion, writeFailure, exerciseConflict, previousRemoval

    public var errorDescription: String? {
        switch self {
        case .invalidID: "This program’s identifier is invalid."
        case .invalidTitle: "Enter a program name of up to 80 characters."
        case .invalidDetails: "Shorten the program description, author details, or coaching notes."
        case .invalidSource: "Enter a web address starting with https:// or http://."
        case .invalidBlock: "Give each block a name of up to 80 characters and progression notes of up to 2,000 characters."
        case .invalidLength: "Choose a program length between 1 and 52 weeks."
        case .sessionDays: "Give each block one to seven workouts, each on a different day of its week."
        case .invalidSession: "Give each workout a name and a day within its week."
        case .exerciseList: "Choose one to 30 different exercises for each workout."
        case .unavailableExercise: "An exercise in this program is unavailable. Replace it before scheduling."
        case .invalidPrescription: "Check the sets, rep range, reps in reserve, and rest time for each exercise."
        case .invalidPair: "Pair two adjacent exercises in order. Use 1–20 rounds and up to 60 minutes of rest."
        case .credentialNeedsAuthor: "Add the coach’s name alongside their credentials."
        case .duplicateID: "A different version of this program is already in your library. Save a separate copy to import it."
        case .immutable: "Save a copy to change a Senda program."
        case .allOccupied: "Every scheduled date already has a workout. Choose another start date."
        case .exerciseConflict: "A custom exercise in this file conflicts with an existing or archived exercise. Your library has been kept intact."
        case .invalidFile: "Choose a program file exported from Senda."
        case .fileTooLarge: "Choose a Senda program file smaller than 2 MB."
        case .exportTooLarge: "This program exceeds the 2 MB sharing limit. Split it into shorter programs to share it."
        case .previousRemoval: "Return to Week to finish the previous workout removal, then schedule the edited program."
        case .unsupportedVersion: "This program file needs a newer version of Senda."
        case .writeFailure: "The program couldn’t be saved. Try again."
        }
    }
}

extension TrainingWorkspace {
    private var activeEnrollmentKeys: Set<ProgramEnrollment.Key> {
        Set(days.values.compactMap { $0.programSession.map { ProgramEnrollment.Key(programID: $0.programID, start: $0.start) } })
    }

    public var activeProgramEnrollments: [ProgramEnrollment] {
        guard let enrollments = programEnrollments else { return [] }
        let keys = activeEnrollmentKeys
        return enrollments.filter { keys.contains($0.key) }
    }

    /// A removed workout can still be restored until another notebook action releases its Undo.
    package mutating func discardUnusedProgramEnrollments() {
        guard let enrollments = programEnrollments else { return }
        var needed = activeEnrollmentKeys
        if case let .removedFromWorkout(_, _, original, _)? = undo, let ref = original.programSession {
            needed.insert(ProgramEnrollment.Key(programID: ref.programID, start: ref.start))
        }
        let kept = enrollments.filter { needed.contains($0.key) }
        programEnrollments = kept.isEmpty ? nil : kept
    }

    func validatePrograms(knownExercises: Set<String>) throws -> [ProgramEnrollment.Key: ProgramEnrollment] {
        var ids = Set<UUID>()
        for program in programs ?? [] {
            guard let id = UUID(uuidString: program.id), ids.insert(id).inserted else { throw ProgramError.duplicateID }
            try program.validated(against: knownExercises)
        }
        var enrolled: [ProgramEnrollment.Key: ProgramEnrollment] = [:]
        for enrollment in programEnrollments ?? [] {
            try enrollment.program.validated(against: knownExercises)
            guard enrolled.updateValue(enrollment, forKey: enrollment.key) == nil else { throw TrainingError.invalidWorkspace }
        }
        return enrolled
    }
}

extension ScheduledProgramReference {
    func validate(day: TrainingDay, enrollments: [ProgramEnrollment.Key: ProgramEnrollment]) throws {
        let key = ProgramEnrollment.Key(programID: programID, start: start)
        guard let enrolled = enrollments[key], let session = enrolled.session(for: self),
              programTitle == session.programTitle, sessionTitle == session.sessionTitle,
              day == (try start.adding(days: (week - 1) * 7 + dayOffset)) else { throw TrainingError.invalidWorkspace }
    }
}
