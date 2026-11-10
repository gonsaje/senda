import Foundation
import SendaDomain

/// Shared with readable exports and the notebook's Gregorian calendar views.
private let notebookDateRange: ClosedRange<TimeInterval> = -62_135_596_800...253_402_300_799

public struct NotebookArchive: Codable, Equatable, Sendable {
    public let snapshot: JournalSnapshot
    public let profile: ProfileDetails
    public let createdAt: Date
    public init(snapshot: JournalSnapshot, profile: ProfileDetails, createdAt: Date = Date()) {
        self.snapshot = snapshot; self.profile = profile; self.createdAt = createdAt
    }

    public func validated() throws -> NotebookArchive {
        guard snapshot.training != nil, createdAt.timeIntervalSinceReferenceDate.isFinite,
              notebookDateRange.contains(createdAt.timeIntervalSince1970),
              snapshot.journal.batches.allSatisfy({ notebookDateRange.contains($0.recordedAt.timeIntervalSince1970) }) else {
            throw NotebookBackupError.invalidBackup
        }
        if case .deleted(_, _, _, _, let removal)? = snapshot.training?.undo, let removal {
            guard notebookDateRange.contains(removal.batch.recordedAt.timeIntervalSince1970) else {
                throw NotebookBackupError.invalidBackup
            }
        }
        if case .deletedGroup(_, _, _, _, let removal)? = snapshot.training?.undo {
            guard removal.batches.allSatisfy({ notebookDateRange.contains($0.batch.recordedAt.timeIntervalSince1970) }) else {
                throw NotebookBackupError.invalidBackup
            }
        }
        do {
            return try NotebookArchive(snapshot: snapshot.validated(), profile: profile.validated(), createdAt: createdAt)
        } catch {
            throw NotebookBackupError.invalidBackup
        }
    }

    private enum CodingKeys: String, CodingKey { case format, version, createdAt, snapshot, profile }

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
            guard (1...4).contains(version) else { throw NotebookBackupError.unsupportedVersion(version) }
            self = try NotebookArchive(snapshot: box.decode(SnapshotPayload.self, forKey: .snapshot).snapshot,
                profile: box.decode(ProfileDetails.self, forKey: .profile), createdAt: box.decode(Date.self, forKey: .createdAt)).validated()
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
        try box.encode(4, forKey: .version)
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
        let exercises = Dictionary(uniqueKeysWithValues: (Exercise.catalog + (validated.customExercises ?? [])).map { ($0.id, $0.name) })
        var daysBySet: [UUID: String] = [:]
        var annotationsBySet: [UUID: TrainingRow] = [:]
        var plansBySet: [UUID: ExercisePlan] = [:]
        var dropStagesBySet: [UUID: Int] = [:]
        for (day, workout) in validated.training?.days ?? [:] {
            for (exerciseID, rows) in workout.rows {
                for entry in TrainingSetEntry.grouping(rows) {
                    for (stage, row) in entry.rows.enumerated() {
                        if let id = row.performedSetID {
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
                let fields = [daysBySet[set.id] ?? fallbackDay, date,
                    spreadsheetText(exercises[batch.exerciseID] ?? batch.exerciseID), spreadsheetText(batch.exerciseID),
                    String(set.position), exactWeight(set.values.weight, unit: .pounds), exactWeight(set.values.weight, unit: .kilograms),
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
