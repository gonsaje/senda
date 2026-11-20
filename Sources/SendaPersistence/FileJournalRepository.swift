import Foundation
import SendaDomain

extension JournalSnapshot {
    var hasCustomExerciseSetups: Bool {
        customExercises?.contains { !$0.customSetup.isEmpty } == true
    }
    var customExerciseSetupCount: Int {
        customExercises?.count(where: { !$0.customSetup.isEmpty }) ?? 0
    }
    var archivedCustomExerciseCount: Int {
        customExercises?.count(where: \.isArchived) ?? 0
    }
}

/// Included only in the new file format; older app versions will refuse to overwrite
/// content they cannot represent. Counts catch missing optional collections on import.
struct StructuredTrainingCounts: Codable, Equatable {
    var programs = 0
    var enrollments = 0
    var scheduledSessions = 0
    var supersets = 0
    var templatePairs = 0

    private struct Management: Codable, Equatable {
        var endedEnrollments = 0
        var rescheduledSessions = 0
        var sessionsWithInitialUnit = 0
        var hiddenSupersets = 0
        var supersetUndo = 0
    }
    private var management: Management?
    var hasManagement: Bool { management != nil }

    init(_ training: TrainingWorkspace?) {
        guard let training else { return }
        programs = training.programs?.count ?? 0
        enrollments = training.programEnrollments?.count ?? 0
        templatePairs = (training.workoutTemplates ?? []).reduce(0) { $0 + ($1.supersets?.count ?? 0) }
        var management = Management()
        management.endedEnrollments = training.programEnrollments?.count(where: { $0.endedOn != nil }) ?? 0
        switch training.undo {
        case .unpaired?: supersets += 1; management.supersetUndo = 1
        case .hidSuperset?: management.supersetUndo = 1
        default: break
        }
        for day in training.days.values { include(day, management: &management) }
        if case let .removedFromWorkout(_, _, original, _)? = training.undo { include(original, management: &management) }
        if management != Management() { self.management = management }
    }

    private mutating func include(_ day: DayWorkout, management: inout Management) {
        if let session = day.programSession {
            scheduledSessions += 1
            if session.initialUnit != nil { management.sessionsWithInitialUnit += 1 }
            if session.rescheduledTo != nil { management.rescheduledSessions += 1 }
        }
        management.hiddenSupersets += day.hiddenSupersets.count
        supersets += day.supersets?.count ?? 0
    }

    var isEmpty: Bool { self == Self(nil) }
}

@MainActor public final class FileJournalRepository: JournalRepository {
    private var encoder = JournalFileEncoder()
    private let url: URL
    private let writer: (Data, URL) throws -> Void
    public convenience init(url: URL) {
        self.init(url: url, writer: { data, url in try data.write(to: url, options: .atomic) })
    }
    init(url: URL, writer: @escaping (Data, URL) throws -> Void) {
        self.url = url; self.writer = writer
    }
    private struct Header: Decodable { let version: Int }
    private struct Envelope: Decodable {
        let version: Int
        let journal: Journal
        let workspace: EntryWorkspace?
        let customExercises: [Exercise]?
        let trainingEnabled: Bool?
        let training: TrainingWorkspace?
        let legacyBase: EntryWorkspace?
        let workoutTemplateCount: Int?
        let archivedCustomExerciseCount: Int?
        let customExerciseSetupCount: Int?
        let customMuscleMetadata: CustomMuscleMetadata?
        let structuredTraining: StructuredTrainingCounts?
    }

    private struct WriteHeader: Encodable {
        let version: Int
        let workspace: EntryWorkspace?
        let customExercises: [Exercise]
        let trainingEnabled: Bool
        let legacyBase: EntryWorkspace?
        let workoutTemplateCount: Int?
        let archivedCustomExerciseCount: Int?
        let customExerciseSetupCount: Int?
        let customMuscleMetadata: CustomMuscleMetadata?
        let structuredTraining: StructuredTrainingCounts?
    }

    public func loadSnapshot() throws -> JournalSnapshot {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return JournalSnapshot() }
        let decoder = JSONDecoder()
        let version = try decoder.decode(Header.self, from: data).version
        guard (1...13).contains(version) else { throw StorageError.unsupportedVersion(version) }
        let envelope = try decoder.decode(Envelope.self, from: data)
        if version >= 3, envelope.customExercises == nil { throw StorageError.missingExerciseLibrary }
        if version >= 4 {
            guard let enabled = envelope.trainingEnabled, enabled == (envelope.training != nil) else { throw StorageError.missingTrainingWorkspace }
        }
        if version == 8, envelope.training?.workoutTemplates?.isEmpty != false {
            throw StorageError.missingWorkoutTemplates
        }
        let snapshot = JournalSnapshot(journal: envelope.journal, workspace: version == 1 ? nil : envelope.workspace,
            customExercises: version >= 3 ? envelope.customExercises : nil, training: version >= 4 ? envelope.training : nil, legacyBase: version >= 4 ? envelope.legacyBase : nil)
        let structures = StructuredTrainingCounts(snapshot.training)
        let muscleMetadata = CustomMuscleMetadata(envelope.customExercises ?? [])
        guard (version == 13) == (muscleMetadata != nil), envelope.customMuscleMetadata == muscleMetadata else {
            throw StorageError.invalidCustomMuscleMetadata
        }
        guard version == 13 || (version == 12) == structures.hasManagement,
              version >= 11 ? ((version == 13 || !structures.isEmpty) && envelope.structuredTraining == structures) : structures.isEmpty
        else { throw StorageError.incompleteStructuredTraining }
        if version >= 10 {
            guard (version > 10 || snapshot.archivedCustomExerciseCount > 0),
                  envelope.archivedCustomExerciseCount == snapshot.archivedCustomExerciseCount
            else { throw StorageError.invalidExerciseArchive }
            guard envelope.customExerciseSetupCount == snapshot.customExerciseSetupCount
            else { throw StorageError.missingExerciseSetups }
        } else if envelope.customExercises?.contains(where: \.isArchived) == true {
            throw StorageError.invalidExerciseArchive
        }
        if version == 9, !snapshot.hasCustomExerciseSetups { throw StorageError.missingExerciseSetups }
        if version >= 9, envelope.workoutTemplateCount != (snapshot.training?.workoutTemplates?.count ?? 0) {
            throw StorageError.missingWorkoutTemplates
        }
        return try snapshot.validated()
    }

    public func saveSnapshot(_ snapshot: JournalSnapshot) throws {
        try saveValidatedSnapshot(ValidatedJournalSnapshot(snapshot))
    }

    public func saveValidatedSnapshot(_ checked: ValidatedJournalSnapshot) throws {
        let snapshot = checked.snapshot
        let archived = snapshot.archivedCustomExerciseCount
        let structures = StructuredTrainingCounts(snapshot.training)
        let muscleMetadata = CustomMuscleMetadata(snapshot.customExercises ?? [])
        let version = if muscleMetadata != nil { 13 }
            else if structures.hasManagement { 12 }
            else if !structures.isEmpty { 11 }
            else if archived > 0 { 10 }
            else if snapshot.hasCustomExerciseSetups { 9 }
            else if snapshot.training?.workoutTemplates?.isEmpty == false { 8 }
            else { 7 }
        let header = WriteHeader(version: version, workspace: snapshot.workspace,
            customExercises: snapshot.customExercises ?? [], trainingEnabled: snapshot.training != nil, legacyBase: snapshot.legacyBase,
            workoutTemplateCount: version >= 9 ? snapshot.training?.workoutTemplates?.count ?? 0 : nil,
            archivedCustomExerciseCount: version >= 10 ? archived : nil,
            customExerciseSetupCount: version >= 10 ? snapshot.customExerciseSetupCount : nil,
            customMuscleMetadata: muscleMetadata, structuredTraining: version >= 11 ? structures : nil)
        let data = try encoder.encode(header, journal: snapshot.journal, training: snapshot.training)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writer(data, url)
    }
}

public enum StorageError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case missingExerciseLibrary
    case missingTrainingWorkspace
    case missingWorkoutTemplates
    case missingExerciseSetups
    case invalidCustomMuscleMetadata
    case invalidExerciseArchive
    case incompleteStructuredTraining
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This journal uses format \(version), which this app cannot open. The file has been left untouched."
        case .missingTrainingWorkspace:
            "The saved notebook is missing or inconsistent. The journal file has been left untouched."
        case .missingExerciseLibrary:
            "The saved exercise library is missing. The journal file has been left untouched."
        case .missingWorkoutTemplates:
            "This journal is missing its saved workouts."
        case .invalidCustomMuscleMetadata:
            "This journal has incomplete muscle details for a custom exercise."
        case .missingExerciseSetups:
            "This journal is missing its custom exercise gym and equipment details."
        case .incompleteStructuredTraining:
            "This journal is missing program or superset data."
        case .invalidExerciseArchive:
            "The journal’s archived exercises could not be read. The journal file has been left untouched."
        }
    }
}
