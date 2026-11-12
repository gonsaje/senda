import Foundation
import Testing
import SendaDomain
@testable import SendaPersistence

struct NotebookBackupCodecTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func archive() throws -> NotebookArchive {
        let day = try TrainingDay("2026-11-07")
        let custom = try ExerciseLibrary.custom(named: "Cable, \"high\" row")
        var journal = Journal()
        let first = try journal.record(DraftBatch(exerciseID: custom.id, sets: [
            SetValues(weight: 101, reps: 12), SetValues(weight: 13_755, reps: 9)
        ]), at: Date(timeIntervalSinceReferenceDate: 815_144_123.123456))
        let corrected = try journal.correct(batchID: first.id, revision: 1,
            sets: [SetValues(weight: 101, reps: 11), SetValues(weight: 13_755, reps: 8)],
            retainedSetIDs: first.sets.map { Optional($0.id) })
        let legacy = try journal.record(DraftBatch(exerciseID: "retired-lift", sets: [SetValues(weight: 0, reps: 15)]),
            at: Date(timeIntervalSinceReferenceDate: 815_144_124.000001))
        var correction = TrainingRow(set: corrected.sets[0], unit: .kilograms)
        correction.weight = "31."; correction.reps = ""; correction.weightIsDirty = true; correction.pendingCorrection = true
        let unfinished = TrainingRow(weight: ".", reps: "09", unit: .kilograms, weightIsDirty: true)
        let hiddenRows = [TrainingRow(set: legacy.sets[0], unit: .kilograms)]
        let training = TrainingWorkspace(visibleWeek: try day.week()[0], selectedDay: day, preferredUnit: .kilograms,
            days: [day.rawValue: DayWorkout(exerciseIDs: [custom.id], selectedExerciseID: custom.id,
                rows: [custom.id: [correction, TrainingRow(set: corrected.sets[1], unit: .kilograms), unfinished], "retired-lift": hiddenRows], unit: .kilograms)],
            legacyExerciseIDs: ["retired-lift"])
        return NotebookArchive(snapshot: JournalSnapshot(journal: journal, customExercises: [custom], training: training),
            profile: ProfileDetails(name: "Ada Example", email: "legacy@example.com"),
            createdAt: Date(timeIntervalSinceReferenceDate: 815_144_125.987654))
    }

    private func object(_ archive: NotebookArchive) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: NotebookBackupCodec.encode(archive)) as? [String: Any])
    }

    private func data(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    @Test func fullBackupRoundTripPreservesIdentityHistoryUnfinishedCorrectionsHiddenRowsAndLegacyEmail() throws {
        let original = try archive()
        let bytes = try NotebookBackupCodec.encode(original)
        let loaded = try NotebookBackupCodec.decode(bytes)
        #expect(loaded == original)
        #expect(try JSONDecoder().decode(NotebookArchive.self, from: bytes) == original)
        #expect(try original.validated() == original)
        #expect(loaded.snapshot.journal.batches.count == 2)
        #expect(loaded.snapshot.journal.batches[0].revision == 2)
        #expect(loaded.snapshot.training?.days["2026-11-07"]?.exerciseIDs.count == 1)
        #expect(loaded.snapshot.training?.days["2026-11-07"]?.rows["retired-lift"]?.count == 1)
        #expect(loaded.profile.email == "legacy@example.com")
        var journal = loaded.snapshot.journal
        let batch = journal.batches[0]
        #expect(journal.hasConsumedAction(batch.actionID))
        #expect(try journal.updateSet(batch.sets[1].id, values: SetValues(weight: 13_755, reps: 7)).id == batch.sets[1].id)
    }

    @Test func fullBackupPreservesGoalsAndOlderBackupLoadsWithoutThem() throws {
        let original = try archive()
        var details = original.profile
        details.goals = [StrengthGoal(exerciseID: "bench", target: SetValues(weight: 15_500, reps: 8))]
        let withGoals = NotebookArchive(snapshot: original.snapshot, profile: details, createdAt: original.createdAt)
        #expect(try NotebookBackupCodec.decode(NotebookBackupCodec.encode(withGoals)) == withGoals)

        var legacy = try object(withGoals)
        #expect(legacy["version"] as? Int == 5)
        legacy["version"] = 4
        var legacyDetails = try #require(legacy["profile"] as? [String: Any])
        legacyDetails.removeValue(forKey: "goals")
        legacy["profile"] = legacyDetails
        #expect(try NotebookBackupCodec.decode(data(legacy)) == original)
    }

    @Test func encodedBackupHasStrictHeaderNumericDatesAndStableReadableJSON() throws {
        let archive = try archive()
        let bytes = try NotebookBackupCodec.encode(archive)
        let object = try object(archive)
        #expect(object["format"] as? String == "senda-backup")
        #expect(object["version"] as? Int == 4)
        #expect(object["createdAt"] as? Double == archive.createdAt.timeIntervalSinceReferenceDate)
        let string = try #require(String(data: bytes, encoding: .utf8))
        #expect(string.contains("\n"))
        #expect(string.range(of: "\"createdAt\"")!.lowerBound < string.range(of: "\"format\"")!.lowerBound)
        #expect(try NotebookBackupCodec.encode(archive) == bytes)
        #expect(try JSONEncoder().encode(archive).isEmpty == false)
    }

    @Test func rejectsMalformedAndNonBackupJSONWithFriendlyErrors() throws {
        for bytes in [Data(), Data("not json".utf8), Data("[]".utf8), Data("{}".utf8)] {
            do {
                _ = try NotebookBackupCodec.decode(bytes)
                Issue.record("An invalid file was accepted")
            } catch {
                #expect(error is any LocalizedError)
                #expect(!error.localizedDescription.isEmpty)
            }
        }
    }

    @Test func rejectsWrongFormatPastFutureAndNonintegerVersions() throws {
        let original = try object(archive())
        for value: Any in ["other-backup", 1, NSNull()] {
            var candidate = original; candidate["format"] = value
            #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(candidate)) }
        }
        for value: Any in [0, 6, -1, 1.5, "1", NSNull()] {
            var candidate = original; candidate["version"] = value
            #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(candidate)) }
        }
    }

    @Test func rejectsEveryMissingRequiredArchiveFieldAndMissingTrainingWorkspace() throws {
        let original = try object(archive())
        for key in ["format", "version", "createdAt", "snapshot", "profile"] {
            var candidate = original; candidate.removeValue(forKey: key)
            #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(candidate)) }
            #expect(throws: (any Error).self) { try JSONDecoder().decode(NotebookArchive.self, from: data(candidate)) }
        }
        var snapshot = try #require(original["snapshot"] as? [String: Any])
        for key in ["training", "journal", "customExercises"] {
            var altered = snapshot; altered.removeValue(forKey: key)
            var candidate = original; candidate["snapshot"] = altered
            #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(candidate)) }
        }
        snapshot["training"] = NSNull()
        var candidate = original; candidate["snapshot"] = snapshot
        #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(candidate)) }
    }

    @Test func rejectsLegacyWorkspaceArchivesRatherThanMigratingOrFabricatingRecords() throws {
        let legacy = EntryWorkspace(sessions: ["bench": .draft(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 10_000, reps: 8)]))],
            numberInputText: "31.", numberInputDirty: true)
        for snapshot in [JournalSnapshot(), JournalSnapshot(workspace: legacy)] {
            let archive = NotebookArchive(snapshot: snapshot, profile: ProfileDetails())
            #expect(throws: (any Error).self) { try archive.validated() }
            #expect(throws: (any Error).self) { try NotebookBackupCodec.encode(archive) }
        }
    }

    @Test func rejectsInvalidProfileDomainAndNonfiniteDatesAtBothBoundaries() throws {
        let original = try archive()
        for profile in [ProfileDetails(name: String(repeating: "x", count: 81)), ProfileDetails(email: "invalid")] {
            #expect(throws: (any Error).self) {
                try NotebookBackupCodec.encode(NotebookArchive(snapshot: original.snapshot, profile: profile))
            }
            #expect(throws: (any Error).self) { try JSONEncoder().encode(NotebookArchive(snapshot: original.snapshot, profile: profile)) }
        }
        for date in [Date(timeIntervalSinceReferenceDate: .infinity), Date(timeIntervalSinceReferenceDate: .nan)] {
            #expect(throws: (any Error).self) { try NotebookArchive(snapshot: original.snapshot, profile: original.profile, createdAt: date).validated() }
            #expect(throws: (any Error).self) { try NotebookBackupCodec.encode(NotebookArchive(snapshot: original.snapshot, profile: original.profile, createdAt: date)) }
            #expect(throws: (any Error).self) { try JSONEncoder().encode(NotebookArchive(snapshot: original.snapshot, profile: original.profile, createdAt: date)) }
        }
        var json = try object(original)
        json["profile"] = ["name": "Ada", "email": "invalid"]
        #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(json)) }
        let originalBytes = try NotebookBackupCodec.encode(original)
        let originalText = try #require(String(data: originalBytes, encoding: .utf8))
        let overflowingDate = originalText.replacingOccurrences(of: #""createdAt"\s*:\s*[0-9.]+"#, with: #""createdAt": 1e999"#, options: .regularExpression)
        #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(Data(overflowingDate.utf8)) }
        json = try object(original)
        var snapshot = try #require(json["snapshot"] as? [String: Any])
        var journal = try #require(snapshot["journal"] as? [String: Any])
        var batches = try #require(journal["batches"] as? [[String: Any]])
        batches[0]["revision"] = 0; journal["batches"] = batches; snapshot["journal"] = journal; json["snapshot"] = snapshot
        #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(json)) }
        var invalid = original.snapshot
        invalid.training?.days["2026-11-07"]?.rows.removeValue(forKey: "retired-lift")
        #expect(throws: (any Error).self) { try NotebookBackupCodec.encode(NotebookArchive(snapshot: invalid, profile: original.profile)) }
        #expect(throws: (any Error).self) { try NotebookBackupCodec.csv(snapshot: invalid) }
    }

    @Test func refusesOversizedImportBeforeParsing() throws {
        let oversized = Data(repeating: 0x20, count: 50 * 1024 * 1024 + 1)
        do {
            _ = try NotebookBackupCodec.decode(oversized)
            Issue.record("An oversized file was accepted")
        } catch {
            #expect(error is any LocalizedError)
            #expect(error.localizedDescription.contains("50"))
        }
    }

    @Test(arguments: [1e100, -1e100, -62_135_596_801, 253_402_300_800])
    func rejectsFiniteCreationDatesOutsideReadableCalendarRange(_ secondsSince1970: Double) throws {
        let original = try archive()
        let date = Date(timeIntervalSince1970: secondsSince1970)
        var json = try object(original)
        json["createdAt"] = date.timeIntervalSinceReferenceDate
        #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(json)) }
        let invalid = NotebookArchive(snapshot: original.snapshot, profile: original.profile, createdAt: date)
        #expect(throws: (any Error).self) { try invalid.validated() }
        #expect(throws: (any Error).self) { try NotebookBackupCodec.encode(invalid) }
    }

    @Test(arguments: [1e100, -1e100, -62_135_596_801, 253_402_300_800], [0, 1])
    func rejectsFiniteRecordingDatesOutsideReadableCalendarRange(_ secondsSince1970: Double, _ batchIndex: Int) throws {
        let original = try archive()
        var json = try object(original)
        var snapshot = try #require(json["snapshot"] as? [String: Any])
        var journal = try #require(snapshot["journal"] as? [String: Any])
        var batches = try #require(journal["batches"] as? [[String: Any]])
        batches[batchIndex]["recordedAt"] = Date(timeIntervalSince1970: secondsSince1970).timeIntervalSinceReferenceDate
        journal["batches"] = batches; snapshot["journal"] = journal; json["snapshot"] = snapshot
        #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(json)) }
        let invalidSnapshot = try JSONDecoder().decode(JournalSnapshot.self, from: data(snapshot))
        let invalid = NotebookArchive(snapshot: invalidSnapshot, profile: original.profile, createdAt: original.createdAt)
        #expect(throws: (any Error).self) { try invalid.validated() }
        #expect(throws: (any Error).self) { try NotebookBackupCodec.encode(invalid) }
    }

    @Test(arguments: [-62_135_596_800.0, 253_402_300_799.0])
    func calendarBoundaryCreationDatesRoundTripExactly(_ secondsSince1970: Double) throws {
        let original = try archive()
        let boundary = NotebookArchive(snapshot: original.snapshot, profile: original.profile,
            createdAt: Date(timeIntervalSince1970: secondsSince1970))
        #expect(try NotebookBackupCodec.decode(NotebookBackupCodec.encode(boundary)) == boundary)
    }

    @Test(arguments: [1e100, -1e100, -62_135_596_801, 253_402_300_800])
    func rejectsUnreadableRecordingDatesRetainedByDeletedSetUndo(_ secondsSince1970: Double) throws {
        let day = try TrainingDay("2026-11-09")
        var journal = Journal()
        let batch = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]), at: day.date(in: calendar))
        let row = TrainingRow(set: batch.sets[0], unit: .pounds)
        let removal = try journal.removeSet(batch.sets[0].id)
        let training = TrainingWorkspace(visibleWeek: day, selectedDay: day,
            days: [day.rawValue: DayWorkout(exerciseIDs: ["bench"], selectedExerciseID: "bench", rows: ["bench": []])],
            undo: .deleted(day: day, exerciseID: "bench", index: 0, row: row, removal: removal))
        let original = NotebookArchive(snapshot: JournalSnapshot(journal: journal, training: training), profile: ProfileDetails())
        #expect(original.snapshot.journal.batches.isEmpty)
        #expect(try NotebookBackupCodec.decode(NotebookBackupCodec.encode(original)) == original)
        var json = try object(original)
        var snapshot = try #require(json["snapshot"] as? [String: Any])
        var workspace = try #require(snapshot["training"] as? [String: Any])
        var undo = try #require(workspace["undo"] as? [String: Any])
        var deleted = try #require(undo["deleted"] as? [String: Any])
        var retainedRemoval = try #require(deleted["removal"] as? [String: Any])
        var retainedBatch = try #require(retainedRemoval["batch"] as? [String: Any])
        retainedBatch["recordedAt"] = Date(timeIntervalSince1970: secondsSince1970).timeIntervalSinceReferenceDate
        retainedRemoval["batch"] = retainedBatch; deleted["removal"] = retainedRemoval; undo["deleted"] = deleted
        workspace["undo"] = undo; snapshot["training"] = workspace; json["snapshot"] = snapshot
        #expect(throws: (any Error).self) { try NotebookBackupCodec.decode(data(json)) }
        let invalidSnapshot = try JSONDecoder().decode(JournalSnapshot.self, from: data(snapshot))
        let invalid = NotebookArchive(snapshot: invalidSnapshot, profile: original.profile, createdAt: original.createdAt)
        #expect(throws: (any Error).self) { try invalid.validated() }
        #expect(throws: (any Error).self) { try NotebookBackupCodec.encode(invalid) }
    }

    @Test func refusesOversizedExportsSoSavedBackupsRemainImportable() throws {
        // Valid Unicode IDs stay within the domain's character limit while exercising the byte limit.
        let suffix = String(repeating: "🇺🇸", count: 72)
        let ids = (0..<90_000).map { "\($0)" + suffix }
        let training = TrainingWorkspace(visibleWeek: try TrainingDay("2026-11-09"), legacyExerciseIDs: ids)
        let archive = NotebookArchive(snapshot: JournalSnapshot(training: training), profile: ProfileDetails())
        #expect(throws: NotebookBackupError.tooLarge) { try NotebookBackupCodec.encode(archive) }
    }

    @Test func csvExportsPerformedHistoryInOrderWithExactWeightColumnsAndNoDraftsOrCorrections() throws {
        let archive = try archive()
        let csv = try #require(String(data: NotebookBackupCodec.csv(snapshot: archive.snapshot, calendar: calendar), encoding: .utf8))
        let rows = parseCSV(csv)
        #expect(rows[0] == ["Day", "Recorded At", "Exercise", "Exercise ID", "Set Position", "Weight (lb)", "Weight (kg)", "Reps", "Batch ID", "Set ID", "Set Type", "Reps Left", "Planned Working Sets", "Minimum Reps", "Maximum Reps", "Drop Group ID", "Drop Stage"])
        #expect(rows.count == 4)
        #expect(rows[1][0] == "2026-11-07")
        #expect(rows[1][2] == "Cable, \"high\" row")
        #expect(rows[1][3] == archive.snapshot.customExercises?[0].id)
        #expect(rows[1][4...7] == ["1", "1.01", "0.4581282937", "11"])
        #expect(rows[2][4...7] == ["2", "137.55", "62.3916304935", "8"])
        #expect(rows[3][2] == "retired-lift")
        #expect(rows[3][5...7] == ["0", "0", "15"])
        #expect(rows[1][8] == archive.snapshot.journal.batches[0].id.uuidString)
        #expect(rows[1][9] == archive.snapshot.journal.batches[0].sets[0].id.uuidString)
        #expect(!csv.contains("31."))
        #expect(csv.contains("\"Cable, \"\"high\"\" row\""))
        #expect(csv.hasSuffix("\r\n"))
    }

    @Test func csvUsesCalendarForLegacyDaysAndUTCForRecordedTimestamps() throws {
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: "push-up", sets: [SetValues(weight: 0, reps: 10)]),
            at: Date(timeIntervalSince1970: 1_794_182_400)) // 2026-11-09 00:00 UTC.
        let csv = try #require(String(data: NotebookBackupCodec.csv(snapshot: JournalSnapshot(journal: journal), calendar: calendar), encoding: .utf8))
        let rows = parseCSV(csv)
        #expect(rows[1][0] == "2026-11-08")
        #expect(rows[1][1] == "2026-11-09T00:00:00.000Z")
        #expect(rows[1][2] == "Push-up")
        #expect(rows[1][5...7] == ["0", "0", "10"])
    }

    @Test(arguments: ["=SUM(1,2)", "+Cable", "-Cable", "@Cable"])
    func csvNeutralizesFormulaLeadingCustomNames(_ name: String) throws {
        let custom = try ExerciseLibrary.custom(named: name)
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: custom.id, sets: [SetValues(weight: 100, reps: 10)]), at: Date())
        let csv = try #require(String(data: NotebookBackupCodec.csv(snapshot: JournalSnapshot(journal: journal, customExercises: [custom])), encoding: .utf8))
        #expect(parseCSV(csv)[1][2] == "'" + name)
    }

    @Test(arguments: ["\tlegacy", "\rlegacy", "=legacy", "old,\"lift\"\nline"])
    func csvEscapesLegacyNamesAndNeutralizesControlPrefix(_ name: String) throws {
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: name, sets: [SetValues(weight: 100, reps: 10)]), at: Date())
        let csv = try #require(String(data: NotebookBackupCodec.csv(snapshot: JournalSnapshot(journal: journal)), encoding: .utf8))
        let expected = name.hasPrefix("old") ? name : "'" + name
        #expect(parseCSV(csv)[1][2] == expected)
        #expect(parseCSV(csv)[1][3] == expected)
        #expect(parseCSV(csv).count == 2)
    }

    @Test func emptyCSVContainsOnlyHeaderWithoutFabricatedSets() throws {
        let snapshot = JournalSnapshot(training: TrainingWorkspace(visibleWeek: try TrainingDay("2026-11-09")))
        let csv = try #require(String(data: NotebookBackupCodec.csv(snapshot: snapshot), encoding: .utf8))
        #expect(parseCSV(csv).count == 1)
    }

    @Test func emptyLibraryBackupsCarryAnExplicitLibraryWithoutInventingExercises() throws {
        let snapshot = JournalSnapshot(training: TrainingWorkspace(visibleWeek: try TrainingDay("2026-11-09")))
        let archive = NotebookArchive(snapshot: snapshot, profile: ProfileDetails())
        let json = try object(archive)
        let payload = try #require(json["snapshot"] as? [String: Any])
        #expect((payload["customExercises"] as? [Any])?.isEmpty == true)
        #expect(try NotebookBackupCodec.decode(NotebookBackupCodec.encode(archive)) == archive)
    }

    @Test func csvRejectsDatesOutsideReadableCalendarRangeWithoutCrashing() throws {
        var journal = Journal()
        _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 100, reps: 10)]),
            at: Date(timeIntervalSinceReferenceDate: 1e100))
        #expect(throws: (any Error).self) { try NotebookBackupCodec.csv(snapshot: JournalSnapshot(journal: journal)) }
    }

    /// Small independent RFC 4180 reader to check exported cell boundaries, including embedded newlines.
    private func parseCSV(_ text: String) -> [[String]] {
        let characters = Array(text)
        var rows: [[String]] = [], row: [String] = [], cell = "", quoted = false, index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if quoted, index + 1 < characters.count, characters[index + 1] == "\"" { cell.append("\""); index += 1 }
                else { quoted.toggle() }
            } else if !quoted, character == "," { row.append(cell); cell = "" }
            else if !quoted, character == "\r\n" || character == "\n" || character == "\r" {
                row.append(cell); rows.append(row); row = []; cell = ""
            } else { cell.append(character) }
            index += 1
        }
        if !cell.isEmpty || !row.isEmpty { row.append(cell); rows.append(row) }
        return rows
    }
}
