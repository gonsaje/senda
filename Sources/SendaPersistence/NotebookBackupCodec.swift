import Foundation
import SendaDomain

/// Shared with readable exports and the notebook's Gregorian calendar views.
private let notebookDateRange: ClosedRange<TimeInterval> = -62_135_596_800...253_402_300_799

public struct NotebookArchive: Codable, Equatable, Sendable {
    public let snapshot: JournalSnapshot
    public let profile: ProfileDetails
    /// Missing in workout-only and older backups. An empty array explicitly restores an empty history.
    public let manualMeasurements: [BodyMeasurement]?
    public let createdAt: Date
    public init(snapshot: JournalSnapshot, profile: ProfileDetails, manualMeasurements: [BodyMeasurement]? = nil, createdAt: Date = Date()) {
        self.manualMeasurements = manualMeasurements
        self.snapshot = snapshot; self.profile = profile; self.createdAt = createdAt
    }

    public func validated() throws -> NotebookArchive {
        guard snapshot.training != nil, createdAt.timeIntervalSinceReferenceDate.isFinite,
              notebookDateRange.contains(createdAt.timeIntervalSince1970),
              snapshot.journal.batches.allSatisfy({ notebookDateRange.contains($0.recordedAt.timeIntervalSince1970) }) else {
            throw NotebookBackupError.invalidBackup
        }
        switch snapshot.training?.undo {
        case .deleted(_, _, _, _, let removal), .deletedSupersetSet(_, _, _, _, let removal, _):
            if let removal, !notebookDateRange.contains(removal.batch.recordedAt.timeIntervalSince1970) {
                throw NotebookBackupError.invalidBackup
            }
        case .deletedGroup(_, _, _, _, let removal), .removedFromWorkout(_, _, _, let removal):
            guard removal.batches.allSatisfy({ notebookDateRange.contains($0.batch.recordedAt.timeIntervalSince1970) }) else {
                throw NotebookBackupError.invalidBackup
            }
        default: break
        }
        do {
            if let manualMeasurements { try validateManualReadings(manualMeasurements) }
            return try NotebookArchive(snapshot: snapshot.validated(), profile: profile.validated(),
                manualMeasurements: manualMeasurements, createdAt: createdAt)
        } catch {
            throw NotebookBackupError.invalidBackup
        }
    }

    private enum CodingKeys: String, CodingKey {
        case format, version, createdAt, snapshot, profile, workoutTemplateCount
        case includesManualMeasurements, manualMeasurements, manualMeasurementCount
        case archivedCustomExerciseCount, customExerciseSetupCount, customMuscleMetadata, structuredTraining
    }

    /// Backups require the library even when it is empty: a missing library must not silently erase names.
    private struct SnapshotPayload: Codable {
        let journal: Journal
        let customExercises: [Exercise]
        let training: TrainingWorkspace
        let workspace: EntryWorkspace?
        let legacyBase: EntryWorkspace?

        init(_ snapshot: JournalSnapshot) throws {
            guard let training = snapshot.training else { throw NotebookBackupError.invalidBackup }
            journal = snapshot.journal; customExercises = snapshot.customExercises ?? []
            self.training = training; workspace = snapshot.workspace; legacyBase = snapshot.legacyBase
        }

        var snapshot: JournalSnapshot {
            JournalSnapshot(journal: journal, workspace: workspace, customExercises: customExercises,
                training: training, legacyBase: legacyBase)
        }
    }

    public init(from decoder: any Decoder) throws {
        do {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            guard try box.decode(String.self, forKey: .format) == "senda-backup" else {
                throw NotebookBackupError.incompatibleFormat
            }
            let version = try box.decode(Int.self, forKey: .version)
            guard (1...13).contains(version) else { throw NotebookBackupError.unsupportedVersion(version) }
            let payload = try box.decode(SnapshotPayload.self, forKey: .snapshot)
            if version == 7, payload.training.workoutTemplates?.isEmpty != false {
                throw NotebookBackupError.invalidBackup
            }
            let snapshot = payload.snapshot
            let structures = StructuredTrainingCounts(payload.training)
            let muscleMetadata = CustomMuscleMetadata(payload.customExercises)
            guard (version == 13) == (muscleMetadata != nil),
                  try box.decodeIfPresent(CustomMuscleMetadata.self, forKey: .customMuscleMetadata) == muscleMetadata,
                  version == 13 || (version == 12) == structures.hasManagement else { throw NotebookBackupError.invalidBackup }
            if version >= 10 {
                guard (version == 11 || version == 13 || !structures.isEmpty), try box.decode(StructuredTrainingCounts.self, forKey: .structuredTraining) == structures
                else { throw NotebookBackupError.invalidBackup }
            } else if !structures.isEmpty { throw NotebookBackupError.invalidBackup }
            if version >= 9 {
                guard (version > 9 || snapshot.archivedCustomExerciseCount > 0),
                      try box.decode(Int.self, forKey: .archivedCustomExerciseCount) == snapshot.archivedCustomExerciseCount,
                      try box.decode(Int.self, forKey: .customExerciseSetupCount) == snapshot.customExerciseSetupCount
                else { throw NotebookBackupError.invalidBackup }
            } else if snapshot.archivedCustomExerciseCount > 0 {
                throw NotebookBackupError.invalidBackup
            }
            if version == 8, !snapshot.hasCustomExerciseSetups { throw NotebookBackupError.invalidBackup }
            if version >= 8, try box.decode(Int.self, forKey: .workoutTemplateCount) != (payload.training.workoutTemplates?.count ?? 0) {
                throw NotebookBackupError.invalidBackup
            }
            let measurements: [BodyMeasurement]?
            let includesMeasurements: Bool
            if version >= 12 {
                includesMeasurements = try box.decode(Bool.self, forKey: .includesManualMeasurements)
            } else {
                guard !box.contains(.includesManualMeasurements) else { throw NotebookBackupError.invalidBackup }
                includesMeasurements = version == 11
            }
            if includesMeasurements {
                let readings = try box.decode([BodyMeasurement].self, forKey: .manualMeasurements)
                guard try box.decode(Int.self, forKey: .manualMeasurementCount) == readings.count else {
                    throw NotebookBackupError.invalidBackup
                }
                measurements = readings
            } else {
                guard !box.contains(.manualMeasurements), !box.contains(.manualMeasurementCount) else {
                    throw NotebookBackupError.invalidBackup
                }
                measurements = nil
            }
            self = try NotebookArchive(snapshot: snapshot,
                profile: box.decode(ProfileDetails.self, forKey: .profile), manualMeasurements: measurements,
                createdAt: box.decode(Date.self, forKey: .createdAt)).validated()
        } catch let error as NotebookBackupError {
            throw error
        } catch {
            throw NotebookBackupError.invalidBackup
        }
    }

    public func encode(to encoder: any Encoder) throws {
        let archive = try validated()
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode("senda-backup", forKey: .format)
        let archived = archive.snapshot.archivedCustomExerciseCount
        let structures = StructuredTrainingCounts(archive.snapshot.training)
        let muscleMetadata = CustomMuscleMetadata(archive.snapshot.customExercises ?? [])
        let version = if muscleMetadata != nil { 13 }
            else if structures.hasManagement { 12 }
            else if archive.manualMeasurements != nil { 11 }
            else if !structures.isEmpty { 10 }
            else if archived > 0 { 9 }
            else if archive.snapshot.hasCustomExerciseSetups { 8 }
            else if archive.snapshot.training?.workoutTemplates?.isEmpty == false { 7 }
            else if !archive.profile.weeklyMuscleTargets.isEmpty { 6 }
            else if !archive.profile.goals.isEmpty { 5 }
            else { 4 }
        try box.encode(version, forKey: .version)
        try box.encodeIfPresent(muscleMetadata, forKey: .customMuscleMetadata)
        if version >= 8 {
            try box.encode(archive.snapshot.training?.workoutTemplates?.count ?? 0, forKey: .workoutTemplateCount)
        }
        if version >= 10 { try box.encode(structures, forKey: .structuredTraining) }
        if version >= 12 { try box.encode(archive.manualMeasurements != nil, forKey: .includesManualMeasurements) }
        if let readings = archive.manualMeasurements {
            try box.encode(readings, forKey: .manualMeasurements)
            try box.encode(readings.count, forKey: .manualMeasurementCount)
        }
        if version >= 9 {
            try box.encode(archived, forKey: .archivedCustomExerciseCount)
            try box.encode(archive.snapshot.customExerciseSetupCount, forKey: .customExerciseSetupCount)
        }
        try box.encode(archive.createdAt, forKey: .createdAt)
        try box.encode(SnapshotPayload(archive.snapshot), forKey: .snapshot)
        try box.encode(archive.profile, forKey: .profile)
    }
}

public enum NotebookBackupCodec {
    public static let maxImportBytes = 50 * 1024 * 1024

    public static func encode(_ archive: NotebookArchive) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            // Foundation's numeric Date representation preserves the original stored Date exactly.
            let data = try encoder.encode(archive.validated())
            guard data.count <= maxImportBytes else { throw NotebookBackupError.tooLarge }
            return data
        } catch let error as NotebookBackupError {
            throw error
        } catch {
            throw NotebookBackupError.invalidBackup
        }
    }

    public static func decode(_ data: Data) throws -> NotebookArchive {
        guard data.count <= maxImportBytes else { throw NotebookBackupError.tooLarge }
        do {
            return try JSONDecoder().decode(NotebookArchive.self, from: data)
        } catch let error as NotebookBackupError {
            throw error
        } catch {
            throw NotebookBackupError.invalidBackup
        }
    }

    public static func csv(snapshot: JournalSnapshot, calendar: Calendar = .current) throws -> Data {
        let validated: JournalSnapshot
        do { validated = try snapshot.validated() }
        catch { throw NotebookBackupError.invalidBackup }
        let exercises = Dictionary(uniqueKeysWithValues: validated.exerciseLibrary.map { ($0.id, $0.name) })
        var daysBySet: [UUID: String] = [:]
        var annotationsBySet: [UUID: TrainingRow] = [:]
        var plansBySet: [UUID: ExercisePlan] = [:]
        var dropStagesBySet: [UUID: Int] = [:]
        var workoutPositions: [UUID: Int] = [:]
        for (day, workout) in validated.training?.days ?? [:] {
            for (exerciseID, rows) in workout.rows {
                for (position, entry) in TrainingSetEntry.grouping(rows).enumerated() {
                    for (stage, row) in entry.rows.enumerated() {
                        if let id = row.performedSetID {
                            workoutPositions[id] = position + 1
                            daysBySet[id] = day
                            annotationsBySet[id] = row
                            plansBySet[id] = workout.exercisePlans?[exerciseID]
                            if entry.dropGroupID != nil { dropStagesBySet[id] = stage + 1 }
                        }
                    }
                }
            }
        }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var lines = ["Day,Recorded At,Exercise,Exercise ID,Set Position,Weight (lb),Weight (kg),Reps,Batch ID,Set ID,Set Type,Reps Left,Planned Working Sets,Minimum Reps,Maximum Reps,Drop Group ID,Drop Stage"]
        var legacyPositions: [String: [String: Int]] = [:]
        for batch in validated.journal.batches {
            // TrainingDay and the readable ISO timestamp support Gregorian years 1 through 9999.
            guard notebookDateRange.contains(batch.recordedAt.timeIntervalSince1970) else {
                throw NotebookBackupError.unreadableDate
            }
            let fallbackDay = TrainingDay(batch.recordedAt, calendar: calendar).rawValue
            let date = formatter.string(from: batch.recordedAt)
            for set in batch.sets {
                let annotation = annotationsBySet[set.id]
                let plan = plansBySet[set.id]
                let reserve = annotation?.repsInReserve.map { $0 == 5 ? "5+" : String($0) } ?? ""
                let dropGroupID = annotation?.dropGroupID?.uuidString ?? ""
                let dropStage = dropStagesBySet[set.id].map { String($0) } ?? ""
                let position: Int
                if let savedPosition = workoutPositions[set.id] {
                    position = savedPosition
                } else {
                    // Earlier journals have no row order. Continue across batches for this exercise and day.
                    legacyPositions[fallbackDay, default: [:]][batch.exerciseID, default: 0] += 1
                    position = legacyPositions[fallbackDay]![batch.exerciseID]!
                }
                let fields = [daysBySet[set.id] ?? fallbackDay, date,
                    spreadsheetText(exercises[batch.exerciseID] ?? batch.exerciseID), spreadsheetText(batch.exerciseID),
                    String(position), exactWeight(set.values.weight, unit: .pounds), exactWeight(set.values.weight, unit: .kilograms),
                    String(set.values.reps), batch.id.uuidString, set.id.uuidString,
                    annotation?.kind?.rawValue ?? "", reserve, plan.map { String($0.workingSets) } ?? "",
                    plan.map { String($0.minimumReps) } ?? "", plan.map { String($0.maximumReps) } ?? "",
                    dropGroupID, dropStage]
                lines.append(fields.map(csvCell).joined(separator: ","))
            }
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    private static func exactWeight(_ canonicalWeight: Int, unit: WeightUnit) -> String {
        var amount = unit.amount(for: canonicalWeight)
        return NSDecimalString(&amount, Locale(identifier: "en_US_POSIX"))
    }

    private static func spreadsheetText(_ text: String) -> String {
        guard let first = text.unicodeScalars.first,
              [61, 43, 45, 64, 9, 13, 10].contains(first.value) else { return text }
        return "'" + text
    }

    private static func csvCell(_ text: String) -> String {
        guard text.contains(",") || text.contains("\"") || text.contains("\r") || text.contains("\n") else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

public enum NotebookBackupError: LocalizedError, Equatable, Sendable {
    case invalidBackup, incompatibleFormat, unsupportedVersion(Int), tooLarge, unreadableDate

    public var errorDescription: String? {
        switch self {
        case .invalidBackup: "This backup is incomplete or damaged. Choose a complete Senda backup JSON file."
        case .incompatibleFormat: "Choose a Senda backup JSON file to restore your notebook."
        case .unsupportedVersion(let version): "This backup uses format version \(version), which this app cannot open."
        case .tooLarge: "This backup is larger than 50 MB. Choose a smaller Senda backup file."
        case .unreadableDate: "A recorded date is outside the supported calendar range and could not be exported."
        }
    }
}
