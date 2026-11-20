import Foundation
import Observation
import SendaDomain
import SendaPersistence

public struct TrainingPerformanceReference: Equatable, Sendable {
    public let day: TrainingDay
    public let exerciseID: String
    public let rowID: UUID
    public let values: SetValues
}

public struct TrainingWorkoutRecord: Equatable, Sendable {
    public let values: SetValues
    public let previousValues: SetValues
}

public struct TrainingWorkoutStructure: Identifiable, Equatable, Sendable {
    public let day: TrainingDay
    public let exerciseIDs: [String]
    public let recordedSetCount: Int
    public var id: TrainingDay { day }
}

public struct TrainingSetPosition: Equatable, Sendable {
    public let setIndex: Int
    public let stageIndex: Int
    public let stageCount: Int
    public let isDropSet: Bool
}

public enum TrainingLoadAdjustment: Equatable, Sendable {
    case plates(size: Decimal, count: Int)
    case barbell
    case plateLoad
}

public enum TrainingRowStatus: Equatable, Sendable { case empty, unfinished, recorded, pendingCorrection }

@Observable @MainActor public final class TrainingNotebookModel {
    public func rowStatus(for row: TrainingRow) -> TrainingRowStatus {
        if let values = recordedValues(for: row) {
            guard let id = journal.reference(to: row.performedSetID!)?.batch.exerciseID else { return .recorded }
            return row.pendingCorrection == true || row.parsed(for: exercise(id)) != values ? .pendingCorrection : .recorded
        }
        return row.weight.isEmpty && row.reps.isEmpty ? .empty : .unfinished
    }
    public func recordedValues(for row: TrainingRow) -> SetValues? {
        row.performedSetID.flatMap { journal.reference(to: $0)?.set.values }
    }
    @discardableResult public func discardCorrection(_ rowID: UUID) -> Bool {
        for (key, workout) in workspace.days {
            for (id, rows) in workout.rows {
                guard let index = rows.firstIndex(where: { $0.id == rowID }),
                      rowStatus(for: rows[index]) == .pendingCorrection,
                      let values = recordedValues(for: rows[index]), let setID = rows[index].performedSetID else { continue }
                return commit { state in
                    var row = state.training!.days[key]!.rows[id]![index]
                    row.weight = values.weight == 0 && !exercise(id).requiresWeight ? "" : row.unit.text(for: values.weight)
                    row.accept(values, setID: setID)
                    state.training!.days[key]!.rows[id]![index] = row
                    if state.training!.focus?.rowID == rowID { state.training!.focus = nil }
                    state.training!.undo = nil
                }
            }
        }
        return false
    }
    public func unfinishedSetCount(for day: TrainingDay) -> Int {
        workspace.days[day.rawValue]?.rows.values.reduce(0) { count, rows in
            count + TrainingSetEntry.grouping(rows).filter { entry in
                entry.rows.contains { rowStatus(for: $0) == .unfinished || rowStatus(for: $0) == .pendingCorrection }
            }.count
        } ?? 0
    }
    public var canRetrySave: Bool { pendingSave != nil }
    @discardableResult public func cancelPendingAction() -> Bool {
        // Supersede the unpublished transaction with the visible recovery state.
        // In particular, do not finalize input or retain the old success callback.
        commit { _ in }
    }
    @discardableResult public func beginMetadataEditing() -> Bool {
        // Entering an annotation editor abandons an older failed destination.
        // The current input still participates in automatic saving.
        cancelPendingAction()
    }
    @discardableResult public func retrySave() -> Bool {
        guard let pendingSave else { return true }
        return persist(pendingSave)
    }
    @discardableResult public func openToday() -> Bool { openDay(today) }
    public private(set) var snapshot: JournalSnapshot
    public private(set) var hasSavedFirstSet: Bool
    public private(set) var latestWorkoutSetWrite: TrainingPerformanceReference?
    public private(set) var errorMessage: String?
    public internal(set) var revealRowID: UUID?
    public private(set) var section: TrainingSection = .log
    public private(set) var landingResetID: UInt = 0
    public var isProgressPresented = false
    public var progressExerciseID: String?
    public var progressRange: ExerciseProgressRange = .threeMonths
    public private(set) var progressSessionDay: TrainingDay?
    public private(set) var progressSetID: UUID?
    private struct HistoryReturnContext {
        let day: TrainingDay?
        let week: TrainingDay
        let exerciseID: String?
    }
    private var historyReturnContext: HistoryReturnContext?
    public var hasHistoryReturnContext: Bool { historyReturnContext != nil }
    public var historyReturnsToWeek: Bool { historyReturnContext?.day == nil }
    private var pendingProgressAction = false
    public var canRetryProgressAction: Bool { pendingProgressAction && canRetrySave }
    public var libraryArea = TrainingLibraryArea.workouts
    public var guideTopic: TrainingGuideTopic?
    public var guideQuery = ""
    public var guideExerciseID: String?
    public var learningScope = LearnExerciseScope.library
    private var libraryQuery = ""
    private var personalExerciseQuery = ""
    public var learningQuery: String {
        get { learningScope == .library ? libraryQuery : personalExerciseQuery }
        set {
            if learningScope == .library { libraryQuery = newValue }
            else { personalExerciseQuery = newValue }
        }
    }
    public var learningExerciseID: String?
    private enum ProfileAction { case unit(WeightUnit), record(ExercisePersonalRecord) }
    private var pendingProfileAction: ProfileAction?
    public var canRetryProfileAction: Bool { pendingProfileAction != nil }
    public private(set) var backupErrorMessage: String?
    public private(set) var backupRecoveryRequired = false
    @ObservationIgnored private let restoreStore: any NotebookRestoreStore
    public let bodyMeasurements: BodyMeasurementsModel
    public let profile: ProfileModel
    public let isSample: Bool
    public let calendar: Calendar
    @ObservationIgnored private let repository: any JournalRepository
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored private var lastWritten: JournalSnapshot
    private struct PendingSave {
        let checked: ValidatedJournalSnapshot
        let onSuccess: (() -> Void)?
    }
    private var pendingSave: PendingSave?
    private var plateUndo: PlateUndo?

    private struct PlateUndo {
        let day: TrainingDay
        let exerciseID: String
        let change: TrainingLoadAdjustment
        let before: TrainingRow
        let recordedBefore: SetValues?
        let after: TrainingRow

        func matches(_ row: TrainingRow?) -> Bool {
            guard let row, row.id == after.id, row.unit == after.unit, row.actionID == after.actionID,
                  row.weight == after.weight, row.parsedWeight == after.parsedWeight, row.barbellWeight == after.barbellWeight,
                  row.performedSetID == after.performedSetID else { return false }
            if row.reps == after.reps { return true }
            // Finishing the editor can normalize leading zeros without changing a set.
            guard let reps = NumericField.reps.parse(row.reps) else { return false }
            return reps == NumericField.reps.parse(after.reps)
        }
    }

    public init(repository: any JournalRepository, isSample: Bool = false, calendar: Calendar = .current,
                now: @escaping () -> Date = Date.init, profileRepository: (any ProfileRepository)? = nil,
                restoreStore: (any NotebookRestoreStore)? = nil, health: (any BodyMeasurementsHealthSource)? = nil) throws {
        let profileRepository = profileRepository ?? MemoryProfileRepository()
        let restoreStore = restoreStore ?? MemoryNotebookRestoreStore(repository: repository, profileRepository: profileRepository)
        try restoreStore.recoverInterruptedRestore()
        self.bodyMeasurements = BodyMeasurementsModel(repository: restoreStore.measurementsRepository, health: health)
        self.restoreStore = restoreStore
        self.profile = ProfileModel(repository: profileRepository)
        self.repository = repository; self.isSample = isSample; self.calendar = calendar; self.now = now
        let saved = try repository.loadSnapshot().validated()
        lastWritten = saved
        hasSavedFirstSet = !saved.journal.batches.isEmpty
        let training = try TrainingWorkspace.migrate(saved, today: TrainingDay(now(), calendar: calendar), calendar: calendar)
        snapshot = try JournalSnapshot(journal: saved.journal, customExercises: saved.customExercises, training: training).validated()
    }
    public func backupArchive(includingManualMeasurements: Bool = true) throws -> NotebookArchive {
        guard !backupRecoveryRequired else { throw NotebookBackupWorkflowError.recoveryRequired }
        guard profile.openingError == nil else { throw NotebookBackupWorkflowError.profileUnavailable }
        let readings = includingManualMeasurements ? try restoreStore.measurementsRepository.load() : nil
        return NotebookArchive(snapshot: snapshot, profile: profile.details, manualMeasurements: readings, createdAt: now())
    }
    public func backupData() throws -> Data {
        try NotebookBackupCodec.encode(backupArchive())
    }
    public func csvData() throws -> Data {
        guard !backupRecoveryRequired else { throw NotebookBackupWorkflowError.recoveryRequired }
        return try NotebookBackupCodec.csv(snapshot: snapshot, calendar: calendar)
    }
    public func previousBackupData() throws -> Data? { try restoreStore.previousBackupData() }
    public func previousBackupArchive() async throws -> NotebookArchive? { try await restoreStore.previousBackupArchive() }
    public func previousOriginalFilesData() throws -> Data? { try restoreStore.previousOriginalFilesData() }
    public func originalJournalData() throws -> Data? { try restoreStore.originalJournalData() }
    @discardableResult public func restoreBackup(_ archive: NotebookArchive) -> Bool {
        do {
            let checked = try archive.validated()
            let training = try TrainingWorkspace.migrate(checked.snapshot, today: today, calendar: calendar)
            let archive = try NotebookArchive(snapshot: JournalSnapshot(journal: checked.snapshot.journal,
                customExercises: checked.snapshot.customExercises, training: training), profile: checked.profile,
                manualMeasurements: checked.manualMeasurements, createdAt: checked.createdAt).validated()
            try restoreStore.recoverInterruptedRestore()
            // Persist current drafts when an unreadable file requires a raw pre-restore copy.
            bodyMeasurements.reloadManual()
            let needsRawCopy = profile.openingError != nil || bodyMeasurements.manualLoadFailed
            if needsRawCopy {
                try repository.saveSnapshot(snapshot)
                lastWritten = snapshot
            }
            let current = needsRawCopy ? nil : try NotebookArchive(snapshot: snapshot, profile: profile.details,
                manualMeasurements: bodyMeasurements.manualReadings, createdAt: now()).validated()
            try restoreStore.restore(archive, current: current)
            snapshot = archive.snapshot; lastWritten = archive.snapshot
            plateUndo = nil
            if !archive.snapshot.journal.batches.isEmpty { hasSavedFirstSet = true }
            pendingSave = nil; pendingProfileAction = nil; revealRowID = nil
            errorMessage = nil; backupErrorMessage = nil; backupRecoveryRequired = false
            resetLibrary()
            isProgressPresented = false; progressExerciseID = nil; progressRange = .threeMonths; pendingProgressAction = false
            progressSessionDay = nil; progressSetID = nil; historyReturnContext = nil
            profile.reload()
            bodyMeasurements.reloadManual()
            return true
        } catch {
            backupErrorMessage = error.localizedDescription
            do { try restoreStore.recoverInterruptedRestore() }
            catch {
                backupRecoveryRequired = true
                backupErrorMessage = "Restore recovery must finish before you can use this notebook. " + error.localizedDescription
            }
            return false
        }
    }
    @discardableResult public func retryBackupRecovery() -> Bool {
        do {
            try restoreStore.recoverInterruptedRestore()
            backupRecoveryRequired = false; backupErrorMessage = nil
            profile.reload()
            bodyMeasurements.reloadManual()
            return true
        } catch { backupErrorMessage = error.localizedDescription; return false }
    }
    public var personalRecords: [ExercisePersonalRecord] {
        journal.personalRecords.sorted { exercise($0.exerciseID).name.localizedStandardCompare(exercise($1.exerciseID).name) == .orderedAscending }
    }
    public var bigThreeProgress: BigThreeProgress { journal.bigThreeProgress }
    public var trackedStrengthExerciseIDs: [String] {
        Self.orderedStrengthExerciseIDs(workspace.trackedStrengthExerciseIDs ?? [])
    }
    @discardableResult public func setTrackedStrengthExercises(_ ids: [String]) -> Bool {
        guard !canRetrySave else { return false }
        let selection = Self.orderedStrengthExerciseIDs(ids)
        guard selection != trackedStrengthExerciseIDs else { return true }
        return commit(synchronizeInput: false) { $0.training!.trackedStrengthExerciseIDs = selection }
    }
    private static func orderedStrengthExerciseIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && seen.insert($0).inserted }
    }
    @discardableResult public func openProgress(for exerciseID: String? = nil, on day: TrainingDay? = nil,
                                               highlighting setID: UUID? = nil) -> Bool {
        if let exerciseID, !exercises.contains(where: { $0.id == exerciseID }) {
            errorMessage = "This exercise is no longer available."
            return false
        }
        if let day {
            guard let exerciseID,
                  let session = snapshot.recordedSessions(for: exercise(exerciseID), calendar: calendar).first(where: { $0.day == day }),
                  setID.map({ id in session.sets.contains { $0.id == id } }) ?? true else {
                errorMessage = "This recorded workout is no longer available."
                return false
            }
        }
        let saved = commit(onSuccess: { [weak self] in
            self?.progressExerciseID = exerciseID
            self?.progressSessionDay = day
            self?.progressSetID = setID
            self?.isProgressPresented = true
            self?.pendingProgressAction = false
        }) { try finalize(&$0) }
        pendingProgressAction = !saved
        return saved
    }
    @discardableResult public func dismissProgress() -> Bool {
        cancelProgressNavigation()
        isProgressPresented = false
        return true
    }
    public func cancelProgressNavigation() {
        if pendingProgressAction { _ = cancelPendingAction() }
        pendingProgressAction = false
    }
    public func progressSheetDidDismiss() {
        cancelProgressNavigation()
        if !isProgressPresented { progressSessionDay = nil; progressSetID = nil }
    }
    @discardableResult public func returnFromProgressToWorkout() -> Bool {
        let saved = commit(onSuccess: { [weak self] in
            self?.section = .log
            self?.isProgressPresented = false
            self?.pendingProgressAction = false
        }) { try finalize(&$0) }
        pendingProgressAction = !saved
        return saved
    }
    @discardableResult public func selectSection(_ section: TrainingSection) -> Bool {
        guard section != self.section else {
            return pendingSave == nil ? true : commit { _ in }
        }
        return commit(onSuccess: { [weak self] in
            self?.section = section
            self?.pendingProfileAction = nil
        }) { try finalize(&$0) }
    }
    @discardableResult public func selectDockSection(_ section: TrainingSection) -> Bool {
        guard section == self.section else { return selectSection(section) }
        return commit(onSuccess: { [weak self] in
            guard let self else { return }
            isProgressPresented = false
            progressExerciseID = nil
            progressSessionDay = nil
            progressSetID = nil
            if section == .log {
                revealRowID = nil
                historyReturnContext = nil
            } else if section == .learn {
                resetLibrary()
            }
            landingResetID &+= 1
        }) { state in
            try finalize(&state)
            if section == .log {
                state.training!.selectedDay = nil
                state.training!.undo = nil
            }
        }
    }
    @discardableResult public func retryProfileAction() -> Bool {
        switch pendingProfileAction {
        case .unit(let unit): setPreferredUnit(unit)
        case .record(let record): openPersonalRecord(record)
        case nil: false
        }
    }
    @discardableResult public func setPreferredUnit(_ unit: WeightUnit) -> Bool {
        let saved = commit { $0.training!.preferredUnit = unit }
        pendingProfileAction = saved ? nil : .unit(unit)
        return saved
    }
    @discardableResult public func openPersonalRecord(_ record: ExercisePersonalRecord) -> Bool {
        for key in workspace.days.keys.sorted() {
            guard let day = try? TrainingDay(key),
                  let row = workspace.days[key]?.rows[record.exerciseID]?.first(where: { $0.performedSetID == record.reference.setID }),
                  let performed = journal.reference(to: record.reference.setID) else { continue }
            guard performed.batch.exerciseID == record.exerciseID else { continue }
            let saved = openProgress(for: record.exerciseID, on: day, highlighting: row.performedSetID)
            pendingProfileAction = saved ? nil : .record(record)
            return saved
        }
        errorMessage = JournalError.missingBatch.localizedDescription
        pendingProfileAction = .record(record)
        return false
    }
    public var journal: Journal { snapshot.journal }
    public var workspace: TrainingWorkspace { snapshot.training! }
    public var isFirstWorkout: Bool {
        journal.batches.isEmpty && workspace.days.values.allSatisfy { day in
            day.exerciseIDs.isEmpty && (day.exercisePlans?.isEmpty ?? true) &&
                day.rows.values.allSatisfy { rows in
                    rows.allSatisfy { row in
                        row.weight.isEmpty && row.reps.isEmpty && row.repsInReserve == nil &&
                            row.dropGroupID == nil && row.kind != .warmup && row.kind != .dropSet
                    }
                }
        }
    }
    public var today: TrainingDay { TrainingDay(now(), calendar: calendar) }
    public var selectedDay: TrainingDay? { workspace.selectedDay }
    public var focus: TrainingFocus? { workspace.focus }
    public var workout: DayWorkout? { selectedDay.flatMap { workspace.days[$0.rawValue] } }
    public var exercise: Exercise? { workout?.selectedExerciseID.map { exercise($0) } }
    public var exercises: [Exercise] {
        let known = snapshot.exerciseLibrary
        guard let legacy = workspace.legacyExerciseIDs, !legacy.isEmpty else { return known }
        let ids = Set(known.map(\.id))
        return known + legacy.filter { !ids.contains($0) }.map {
            Exercise(id: $0, name: $0, shortName: $0, startingWeight: 0)
        }
    }
    public func learningResults(in exercises: [Exercise], gymFilter: ExerciseGymFilter) -> [Exercise] {
        let exercises = exercises.filter { !$0.isArchived }
        if learningScope == .library {
            return ExerciseFormGuide.search(libraryQuery, in: exercises, gymFilter: gymFilter)
        }
        let customIDs = Set((snapshot.customExercises ?? []).filter(ExerciseLibrary.canManageCustom).map(\.id))
        let personal = exercises.filter { exercise in
            customIDs.contains(exercise.id) && (learningScope == .personal
                || exercise.customSetup.gyms.isEmpty || exercise.customSetup.requiredEquipment == nil)
        }
        return ExerciseFormGuide.search(personalExerciseQuery, in: personal)
    }

    private func resetLibrary() {
        libraryArea = .workouts
        guideTopic = nil
        guideQuery = ""
        guideExerciseID = nil
        learningScope = .library
        libraryQuery = ""
        personalExerciseQuery = ""
        learningExerciseID = nil
    }
    public var activeExercises: [Exercise] { exercises.filter { !$0.isArchived } }

    public func canManageCustomExercise(_ id: String) -> Bool {
        guard let stored = snapshot.customExercises?.first(where: { $0.id == id }) else { return false }
        return !stored.isArchived && ExerciseLibrary.canManageCustom(stored)
    }
    public var tabs: [Exercise] { workout?.exerciseIDs.map { exercise($0) } ?? [] }
    public var unit: WeightUnit { workout?.unit ?? workspace.preferredUnit }
    public var rows: [TrainingRow] { exercise.flatMap { workout?.rows[$0.id] } ?? [] }
    public var setEntries: [TrainingSetEntry] { TrainingSetEntry.grouping(rows) }
    public func setPosition(for rowID: UUID) -> TrainingSetPosition? {
        for (index, entry) in setEntries.enumerated() {
            if let stage = entry.rows.firstIndex(where: { $0.id == rowID }) {
                return TrainingSetPosition(setIndex: index + 1, stageIndex: stage + 1,
                                           stageCount: entry.rows.count, isDropSet: entry.isDropSet)
            }
        }
        return nil
    }
    public func plan(for exerciseID: String, on day: TrainingDay? = nil) -> ExercisePlan? {
        workspace.days[(day ?? selectedDay ?? today).rawValue]?.exercisePlans?[exerciseID]
    }
    public func nextWorkoutGuidance(for exerciseID: String, on day: TrainingDay? = nil) -> NextWorkoutGuidance {
        snapshot.nextWorkout(for: exercise(exerciseID), on: day ?? selectedDay ?? today,
                             through: today, calendar: calendar)
    }
    @discardableResult public func setPlan(_ plan: ExercisePlan?, for exerciseID: String) -> Bool {
        commit { state in
            guard let day = state.training!.selectedDay,
                  state.training!.days[day.rawValue]?.rows[exerciseID] != nil else { throw TrainingError.missingRow }
            if let plan { _ = try plan.validated() }
            var plans = state.training!.days[day.rawValue]!.exercisePlans ?? [:]
            plans[exerciseID] = plan
            state.training!.days[day.rawValue]!.exercisePlans = plans.isEmpty ? nil : plans
        }
    }
    @discardableResult public func setKind(_ kind: TrainingSetKind?, for rowID: UUID) -> Bool {
        commit { state in
            try changeKind(kind, for: rowID, in: &state)
        }
    }
    @discardableResult public func setRepsInReserve(_ value: Int?, for rowID: UUID) -> Bool {
        commit { state in
            let location = try rowLocation(rowID, in: state)
            state.training!.days[location.day]!.rows[location.exerciseID]![location.index].repsInReserve = value
        }
    }
    @discardableResult public func updateSetDetails(_ rowID: UUID, kind: TrainingSetKind?, repsInReserve: Int?) -> Bool {
        commit { state in
            try changeKind(kind, for: rowID, in: &state)
            let location = try rowLocation(rowID, in: state)
            state.training!.days[location.day]!.rows[location.exerciseID]![location.index].repsInReserve = repsInReserve
        }
    }
    private func changeKind(_ kind: TrainingSetKind?, for rowID: UUID, in state: inout JournalSnapshot) throws {
        let location = try rowLocation(rowID, in: state)
        var rows = state.training!.days[location.day]!.rows[location.exerciseID]!
        if let group = rows[location.index].dropGroupID, kind != .dropSet {
            for index in rows.indices where rows[index].dropGroupID == group {
                rows[index].kind = kind; rows[index].dropGroupID = nil
            }
            state.training!.undo = nil
        } else {
            rows[location.index].kind = kind
            if kind == .dropSet, rows[location.index].dropGroupID == nil { rows[location.index].dropGroupID = UUID() }
        }
        state.training!.days[location.day]!.rows[location.exerciseID] = rows
        if state.training!.selectedDay?.rawValue != location.day {
            state.training!.days[location.day]?.reconcileSupersetRows()
        }
    }
    private func rowLocation(_ rowID: UUID, in state: JournalSnapshot) throws -> (day: String, exerciseID: String, index: Int) {
        for (day, workout) in state.training!.days {
            for (exerciseID, rows) in workout.rows {
                if let index = rows.firstIndex(where: { $0.id == rowID }) { return (day, exerciseID, index) }
            }
        }
        throw TrainingError.missingRow
    }
    public var weekDays: [TrainingDay] { (try? workspace.visibleWeek.week()) ?? [] }
    public var weekSetCount: Int { weekDays.reduce(0) { $0 + summary(for: $1).setCount } }
    public var trainingDayCount: Int { weekDays.filter { summary(for: $0).setCount > 0 }.count }
    public var canRepeat: Bool {
        guard let exercise, let last = setEntries.last else { return false }
        return last.rows.allSatisfy { $0.parsed(for: exercise) != nil }
    }
    public var undoLabel: String? {
        switch workspace.undo {
        case .hidSuperset: "Superset tabs hidden"
        case .unpaired: "Superset unpaired"
        case .repeated, .repeatedGroup: "Set repeated"
        case .deleted, .deletedGroup, .deletedSupersetSet: "Set removed"
        case .removedFromWorkout(_, .exercise, _, _): "Exercise deleted"
        case .removedFromWorkout(_, .workout, _, _): "Workout reset"
        case nil: nil
        }
    }
    public var saveStatus: String {
        errorMessage != nil || pendingSave != nil ? "Couldn’t save changes" : "All changes saved"
    }
    public func exercise(_ id: String) -> Exercise {
        exercises.first { $0.id == id } ?? Exercise(id: id, name: id, shortName: id, startingWeight: 0)
    }
    public func loggedSetCount(for exerciseID: String, on day: TrainingDay) -> Int {
        TrainingSetEntry.grouping(workspace.days[day.rawValue]?.rows[exerciseID] ?? [])
            .filter { $0.rows.contains { $0.performedSetID != nil } }.count
    }
    public func summary(for day: TrainingDay) -> TrainingDaySummary {
        guard let workout = workspace.days[day.rawValue] else { return TrainingDaySummary(performed: [], setCount: 0) }
        let order = workout.exerciseIDs + workout.rows.keys.sorted().filter { !workout.exerciseIDs.contains($0) }
        let performed = order.filter { id in workout.rows[id]?.contains { $0.performedSetID != nil } == true }
        return TrainingDaySummary(performed: performed.map { exercise($0) }, setCount: recordedSetCount(in: workout))
    }
    private func recordedSetCount(in workout: DayWorkout) -> Int {
        workout.rows.values.reduce(0) { count, rows in
            count + TrainingSetEntry.grouping(rows).filter { $0.rows.contains { $0.performedSetID != nil } }.count
        }
    }
    public var lastReference: TrainingPerformanceReference? {
        guard let selectedDay else { return nil }
        let prior = references.filter { $0.day < selectedDay }
        guard let lastDay = prior.map(\.day).max() else { return nil }
        return best(prior.filter { $0.day == lastDay })
    }
    public func previousRecordedSet(before rowID: UUID) -> TrainingPerformanceReference? {
        guard let selectedDay, let exercise, let index = rows.firstIndex(where: { $0.id == rowID }) else { return nil }
        if let reference = rows[..<index].reversed().compactMap({ recordedReference($0, exerciseID: exercise.id, day: selectedDay) }).first {
            return reference
        }
        for key in workspace.days.keys.sorted(by: >) {
            guard let day = try? TrainingDay(key), day < selectedDay else { continue }
            if let reference = (workspace.days[key]?.rows[exercise.id] ?? []).reversed().compactMap({
                recordedReference($0, exerciseID: exercise.id, day: day)
            }).first { return reference }
        }
        return nil
    }
    private func recordedReference(_ row: TrainingRow, exerciseID: String, day: TrainingDay) -> TrainingPerformanceReference? {
        guard let id = row.performedSetID, let reference = journal.reference(to: id), reference.batch.exerciseID == exerciseID else { return nil }
        return TrainingPerformanceReference(day: day, exerciseID: exerciseID, rowID: row.id, values: reference.set.values)
    }
    @discardableResult public func prefillSet(_ rowID: UUID) -> Bool {
        guard let row = rows.first(where: { $0.id == rowID }), row.performedSetID == nil,
              row.weight.isEmpty, row.reps.isEmpty, let reference = previousRecordedSet(before: rowID) else { return false }
        return writeSet(rowID) { state in
            if state.training!.focus?.rowID != rowID { try finalize(&state) }
            let (day, id) = try context(state)
            guard let index = state.training!.days[day.rawValue]!.rows[id]?.firstIndex(where: { $0.id == rowID }) else { throw TrainingError.missingRow }
            var row = state.training!.days[day.rawValue]!.rows[id]![index]
            row.weight = reference.values.weight == 0 && !exercise(id).requiresWeight ? "" : row.unit.text(for: reference.values.weight)
            let sourceRow = state.training!.days[reference.day.rawValue]?.rows[reference.exerciseID]?.first { $0.id == reference.rowID }
            if let bar = sourceRow?.barbellWeight, bar <= reference.values.weight { row.barbellWeight = bar }
            row.reps = String(reference.values.reps)
            row.canonicalWeight = reference.values.weight; row.weightIsDirty = false; row.pendingCorrection = nil
            row.repsInReserve = nil
            state.training!.days[day.rawValue]!.rows[id]![index] = row
            let field: NumericField = exercise(id).requiresWeight ? .weight : .reps
            state.training!.focus = TrainingFocus(day: day, exerciseID: id, rowID: rowID, field: field, keyboard: field == .reps)
            state.training!.undo = nil
        }
    }
    public func recentExercises(limit: Int = 6) -> [Exercise] {
        guard limit > 0 else { return [] }
        let newest = journal.batches.enumerated().sorted {
            if $0.element.recordedAt != $1.element.recordedAt { return $0.element.recordedAt > $1.element.recordedAt }
            return $0.offset > $1.offset
        }
        var seen = Set<String>(), result: [Exercise] = []
        for batch in newest where seen.insert(batch.element.exerciseID).inserted {
            let choice = exercise(batch.element.exerciseID)
            guard !choice.isArchived else { continue }
            result.append(choice)
            if result.count == limit { break }
        }
        return result
    }
    public func indexedExercises(on day: TrainingDay) -> [Exercise] {
        guard let workout = workspace.days[day.rawValue] else { return [] }
        return indexedExerciseIDs(in: workout).map { exercise($0) }
    }
    private func indexedExerciseIDs(in workout: DayWorkout) -> [String] {
        let paired = workout.hiddenSupersets.flatMap { $0.plan.exerciseIDs }
        let hidden = workout.rows.keys.sorted().filter { id in
            !workout.exerciseIDs.contains(id) && !paired.contains(id) && workout.rows[id]?.contains {
                $0.performedSetID != nil || !$0.weight.isEmpty || !$0.reps.isEmpty
            } == true
        }
        return workout.exerciseIDs + paired + hidden
    }

    public var starterWorkouts: [WorkoutTemplate] {
        guard snapshot.customExercises?.isEmpty == false else { return WorkoutTemplate.catalog }
        let alternates = Dictionary(uniqueKeysWithValues: exercises.compactMap { exercise -> (String, String)? in
            guard let preset = exercise.presetID, preset != exercise.id else { return nil }
            return (preset, exercise.id)
        })
        guard !alternates.isEmpty else { return WorkoutTemplate.catalog }
        return WorkoutTemplate.catalog.map { starter in
            WorkoutTemplate(id: starter.id, name: starter.name,
                exerciseIDs: starter.exerciseIDs.map { alternates[$0] ?? $0 },
                exercisePlans: Dictionary(uniqueKeysWithValues: starter.exercisePlans.map { (alternates[$0.key] ?? $0.key, $0.value) }))
        }
    }

    public var savedWorkouts: [WorkoutTemplate] { workspace.workoutTemplates ?? [] }

    @discardableResult public func saveWorkout(_ template: WorkoutTemplate) -> Bool {
        do {
            let previouslySaved = savedWorkouts.first { $0.id == template.id }
            let allowed = Set(activeExercises.map(\.id)).union(previouslySaved?.exerciseIDs ?? [])
            let template = try template.validated(against: allowed)
            guard !WorkoutTemplate.catalog.contains(where: { $0.id == template.id }) else {
                errorMessage = "Save a copy to edit a starter workout."
                return false
            }
            var workouts = savedWorkouts
            if let index = workouts.firstIndex(where: { $0.id == template.id }) {
                guard workouts[index] != template else { return true }
                workouts[index] = template
            } else {
                workouts.append(template)
            }
            return commit(synchronizeInput: false) { $0.training!.workoutTemplates = workouts }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult public func deleteWorkout(id: String) -> Bool {
        guard !WorkoutTemplate.catalog.contains(where: { $0.id == id }) else {
            errorMessage = "Starter workouts cannot be deleted."
            return false
        }
        let remaining = savedWorkouts.filter { $0.id != id }
        guard remaining.count != savedWorkouts.count else { return true }
        return commit(synchronizeInput: false) {
            $0.training!.workoutTemplates = remaining.isEmpty ? nil : remaining
        }
    }

    @discardableResult public func applyWorkout(_ template: WorkoutTemplate, on destination: TrainingDay? = nil) -> Bool {
        guard let day = destination ?? selectedDay else {
            errorMessage = TrainingError.invalidDay.localizedDescription
            return false
        }
        do {
            let source = starterWorkouts.first { $0.id == template.id } ?? template
            let template = try source.validated(against: Set(exercises.map(\.id)))
            let visible = Set(workspace.days[day.rawValue]?.exerciseIDs ?? [])
            let allowed = availableWorkoutExerciseIDs(template.exerciseIDs, on: day)
            guard !allowed.isEmpty else { throw WorkoutTemplateError.unavailableExercise }
            if selectedDay == day, allowed.allSatisfy(visible.contains), template.supersets?.isEmpty != false { return true }
            return addExercises(allowed, plansFrom: template.exercisePlans, supersets: template.supersets ?? [],
                                preserveExistingRows: true, on: day)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public var reusableWorkouts: [TrainingWorkoutStructure] {
        guard let selectedDay else { return [] }
        return reusableWorkouts(before: selectedDay)
    }

    public func reusableWorkouts(before destination: TrainingDay?) -> [TrainingWorkoutStructure] {
        workspace.days.sorted { $0.key > $1.key }.compactMap { key, workout in
            guard let day = try? TrainingDay(key), destination.map({ day < $0 }) ?? true else { return nil }
            let count = recordedSetCount(in: workout)
            guard count > 0 else { return nil }
            return TrainingWorkoutStructure(day: day, exerciseIDs: indexedExerciseIDs(in: workout), recordedSetCount: count)
        }
    }
    @discardableResult public func reuseWorkout(from day: TrainingDay, on destination: TrainingDay? = nil) -> Bool {
        guard let destination = destination ?? selectedDay,
              let structure = reusableWorkouts(before: destination).first(where: { $0.day == day }),
              let source = workspace.days[day.rawValue] else { return false }
        let allowed = availableWorkoutExerciseIDs(structure.exerciseIDs, on: destination)
        guard !allowed.isEmpty else {
            errorMessage = WorkoutTemplateError.unavailableExercise.localizedDescription
            return false
        }
        return addExercises(allowed, plansFrom: source.exercisePlans ?? [:], supersets: source.supersets?.map(\.plan) ?? [],
                            preserveExistingRows: true, on: destination)
    }
    public func availableWorkoutExerciseIDs(_ sourceIDs: [String], on day: TrainingDay) -> [String] {
        let existing = Set(workspace.days[day.rawValue]?.exerciseIDs ?? [])
        let allowed = Set(activeExercises.map(\.id)).union(existing)
        return sourceIDs.filter(allowed.contains)
    }
    public var personalBest: TrainingPerformanceReference? { best(references) }

    /// Keys are workout row IDs, including individual stages of grouped drop sets.
    public var workoutPersonalRecords: [UUID: TrainingWorkoutRecord] {
        guard let selectedDay else { return [:] }
        let history = references
        guard var previous = best(history.filter { $0.day < selectedDay })?.values else { return [:] }
        var records: [UUID: TrainingWorkoutRecord] = [:]
        for set in history where set.day == selectedDay && set.values.isPersonalRecord(over: previous) {
            records[set.rowID] = TrainingWorkoutRecord(values: set.values, previousValues: previous)
            previous = set.values
        }
        return records
    }
    private var references: [TrainingPerformanceReference] {
        guard let exercise else { return [] }
        let values = Dictionary(uniqueKeysWithValues: journal.batches
            .filter { $0.exerciseID == exercise.id }
            .flatMap { $0.sets.map { ($0.id, $0.values) } })
        return workspace.days.keys.sorted().flatMap { key -> [TrainingPerformanceReference] in
            guard let rows = workspace.days[key]?.rows[exercise.id], let day = TrainingDay(rawValue: key) else { return [] }
            return rows.compactMap { row in
                guard let id = row.performedSetID, let value = values[id] else { return nil }
                return TrainingPerformanceReference(day: day, exerciseID: exercise.id, rowID: row.id, values: value)
            }
        }
    }
    private func best(_ refs: [TrainingPerformanceReference]) -> TrainingPerformanceReference? {
        refs.reduce(nil as TrainingPerformanceReference?) { best, candidate in
            guard let best, best.values.isPersonalRecord(over: candidate.values) else { return candidate }
            return best
        }
    }
    @discardableResult public func openDay(_ day: TrainingDay) -> Bool {
        return commit(onSuccess: { [weak self] in self?.revealRowID = nil }) { state in
            try finalize(&state)
            state.training!.selectedDay = day; state.training!.visibleWeek = try day.week()[0]
            if state.training!.days[day.rawValue] == nil { state.training!.days[day.rawValue] = DayWorkout(unit: state.training!.preferredUnit) }
            state.training!.undo = nil
        }
    }
    @discardableResult public func changeDay(_ direction: Int) -> Bool {
        guard let selectedDay, let destination = try? selectedDay.adding(days: direction < 0 ? -1 : 1) else { return false }
        return openDay(destination)
    }
    @discardableResult public func showWeek() -> Bool {
        return commit(onSuccess: { [weak self] in self?.revealRowID = nil }) { state in try finalize(&state); state.training!.selectedDay = nil; state.training!.undo = nil }
    }
    @discardableResult public func showCurrentWeek() -> Bool {
        showWeek(containing: today)
    }
    @discardableResult public func showWeek(containing day: TrainingDay) -> Bool {
        commit(onSuccess: { [weak self] in self?.revealRowID = nil }) { state in
            try finalize(&state)
            state.training!.visibleWeek = try day.week()[0]
            state.training!.selectedDay = nil; state.training!.undo = nil
        }
    }
    @discardableResult public func changeWeek(_ direction: Int) -> Bool {
        commit { state in
            try finalize(&state)
            state.training!.visibleWeek = try state.training!.visibleWeek.adding(days: direction < 0 ? -7 : 7)
            state.training!.selectedDay = nil; state.training!.undo = nil
        }
    }
    @discardableResult public func addExercise(_ id: String) -> Bool {
        // A hidden exercise with saved rows can still be reopened on its original day.
        guard exercises.contains(where: { $0.id == id && (!$0.isArchived || workout?.rows[id] != nil) }) else { return false }
        return commit { state in try finalize(&state); try add(id, in: &state) }
    }
    @discardableResult public func addExercise(_ id: String, on day: TrainingDay) -> Bool {
        let existing = workspace.days[day.rawValue]?.rows[id] != nil
        guard exercises.contains(where: { $0.id == id && (!$0.isArchived || existing) }) else {
            errorMessage = WorkoutTemplateError.unavailableExercise.localizedDescription
            return false
        }
        return commit(onSuccess: { [weak self] in
            self?.revealRowID = nil
            self?.historyReturnContext = nil
            self?.isProgressPresented = false
            self?.section = .log
        }) { state in
            try finalize(&state)
            state.training!.selectedDay = day
            state.training!.visibleWeek = try day.week()[0]
            if state.training!.days[day.rawValue] == nil {
                state.training!.days[day.rawValue] = DayWorkout(unit: state.training!.preferredUnit)
            }
            try add(id, in: &state, preserveExistingRows: true)
        }
    }
    @discardableResult public func addExercises(_ ids: [String]) -> Bool {
        guard let day = selectedDay, availableWorkoutExerciseIDs(ids, on: day).count == ids.count else { return false }
        return addExercises(ids, plansFrom: nil)
    }
    private func addExercises(_ ids: [String], plansFrom source: [String: ExercisePlan]?, supersets: [SupersetPlan] = [],
                              preserveExistingRows: Bool = false, on destination: TrainingDay? = nil) -> Bool {
        guard ids.allSatisfy({ id in exercises.contains { $0.id == id } }) else { return false }
        var seen = Set<String>()
        let ordered = ids.filter { seen.insert($0).inserted }
        let openingDay = destination != nil && destination != selectedDay
        return commit(onSuccess: { [weak self] in if openingDay { self?.revealRowID = nil } }) { state in
            try finalize(&state)
            guard let day = destination ?? state.training!.selectedDay else { throw TrainingError.invalidDay }
            if openingDay {
                state.training!.selectedDay = day
                state.training!.visibleWeek = try day.week()[0]
            }
            var workout = state.training!.days[day.rawValue] ?? DayWorkout(unit: state.training!.preferredUnit)
            var firstNew: String?
            for id in ordered {
                if !workout.exerciseIDs.contains(id) {
                    workout.showTabs(for: id)
                    if firstNew == nil { firstNew = id }
                }
                if !preserveExistingRows || workout.rows[id] == nil {
                    ensureRows(for: id, on: day, in: &workout, workspace: state.training!, plansFrom: source)
                }
            }
            for plan in supersets where plan.exerciseIDs.allSatisfy(ordered.contains) {
                let occupied = Set((workout.supersets ?? []).flatMap { $0.plan.exerciseIDs })
                if occupied.isDisjoint(with: plan.exerciseIDs) { try workout.pair(plan) }
            }
            if let firstNew { workout.selectedExerciseID = firstNew }
            state.training!.days[day.rawValue] = workout; state.training!.undo = nil
        }
    }
    @discardableResult public func createExercise(named name: String, group: MuscleGroup, equipment: ExerciseEquipment,
                                                  customSetup: CustomExerciseSetup = .init(), customMuscleTags: [MuscleRegion] = []) -> Bool {
        commit { state in
            let created = try ExerciseLibrary.custom(named: name, existing: exercises, muscleGroup: group,
                                                     equipment: equipment, customSetup: customSetup, customMuscleTags: customMuscleTags)
            try finalize(&state)
            state.customExercises = (state.customExercises ?? []) + [created]
            try add(created.id, in: &state)
        }
    }

    @discardableResult public func updateCustomExerciseSetup(_ setup: CustomExerciseSetup, for id: String) -> Bool {
        guard canManageCustomExercise(id), let index = snapshot.customExercises?.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Choose a custom exercise to edit its gym and equipment."
            return false
        }
        return commit(synchronizeInput: false) { state in
            state.customExercises?[index].customSetup = setup
        }
    }

    @discardableResult public func createLibraryExercise(named name: String, group: MuscleGroup,
            equipment: ExerciseEquipment, customSetup: CustomExerciseSetup = .init(), customMuscleTags: [MuscleRegion] = []) -> Bool {
        commit(synchronizeInput: false) { state in
            let created = try ExerciseLibrary.custom(named: name, existing: exercises, muscleGroup: group,
                                                      equipment: equipment, customSetup: customSetup, customMuscleTags: customMuscleTags)
            state.customExercises = (state.customExercises ?? []) + [created]
        }
    }

    @discardableResult public func updateCustomExercise(_ id: String, named name: String, group: MuscleGroup,
            equipment: ExerciseEquipment, customSetup: CustomExerciseSetup = .init(), customMuscleTags: [MuscleRegion]? = nil) -> Bool {
        guard canManageCustomExercise(id), let index = snapshot.customExercises?.firstIndex(where: { $0.id == id }),
              let stored = snapshot.customExercises?[index] else {
            errorMessage = "Choose a custom exercise to edit."
            return false
        }
        return commit(synchronizeInput: false) { state in
            state.customExercises?[index] = try ExerciseLibrary.editCustom(stored, named: name,
                existing: exercises, muscleGroup: group, equipment: equipment, customSetup: customSetup, customMuscleTags: customMuscleTags)
        }
    }

    @discardableResult public func archiveCustomExercise(_ id: String) -> Bool {
        guard canManageCustomExercise(id), let index = snapshot.customExercises?.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Choose a custom exercise to remove."
            return false
        }
        return commit(synchronizeInput: false) { state in state.customExercises?[index].isArchived = true }
    }

    private func add(_ id: String, in state: inout JournalSnapshot, preserveExistingRows: Bool = false) throws {
        guard let day = state.training!.selectedDay, var workout = state.training!.days[day.rawValue] else { throw TrainingError.invalidDay }
        workout.showTabs(for: id)
        if !preserveExistingRows || workout.rows[id] == nil {
            ensureRows(for: id, on: day, in: &workout, workspace: state.training!)
        }
        workout.selectedExerciseID = id
        state.training!.days[day.rawValue] = workout; state.training!.undo = nil
    }
    private func ensureRows(for id: String, on day: TrainingDay, in workout: inout DayWorkout,
                            workspace: TrainingWorkspace, plansFrom source: [String: ExercisePlan]? = nil) {
        let firstAddition = workout.rows[id] == nil
        if workout.rows[id]?.isEmpty ?? true { workout.rows[id] = [TrainingRow(unit: workout.unit, kind: .working)] }
        guard firstAddition else { return }
        let plan: ExercisePlan?
        if let source {
            plan = source[id]
        } else {
            // An unplanned latest workout is authoritative: do not resurrect an older plan.
            let latest = workspace.days.keys.sorted(by: >).first {
                $0 < day.rawValue && workspace.days[$0]?.rows[id] != nil
            }
            plan = latest.flatMap { workspace.days[$0]?.exercisePlans?[id] }
        }
        if let plan {
            var plans = workout.exercisePlans ?? [:]
            plans[id] = plan; workout.exercisePlans = plans
        }
    }
    @discardableResult public func selectExercise(_ id: String) -> Bool {
        commit { state in
            try finalize(&state)
            guard let day = state.training!.selectedDay, state.training!.days[day.rawValue]!.exerciseIDs.contains(id) else { throw TrainingError.missingRow }
            state.training!.days[day.rawValue]!.selectedExerciseID = id; state.training!.undo = nil
        }
    }
    @discardableResult public func setExerciseOrder(_ ids: [String], on day: TrainingDay) -> Bool {
        guard selectedDay == day, let current = workout?.exerciseIDs,
              ids.count == current.count, Set(ids) == Set(current) else { return false }
        return commit(synchronizeInput: false) { state in
            state.training!.days[day.rawValue]!.exerciseIDs = ids
        }
    }

    @discardableResult public func removeExercise(_ id: String) -> Bool {
        commit { state in
            try finalize(&state)
            guard let day = state.training!.selectedDay, var workout = state.training!.days[day.rawValue] else { throw TrainingError.invalidDay }
            let pair = workout.supersets?.first { $0.plan.exerciseIDs.contains(id) }
            let members = pair?.plan.exerciseIDs ?? [id]
            var undo: TrainingUndo?
            if let pair, let index = workout.exerciseIDs.firstIndex(of: pair.plan.first), let selected = workout.selectedExerciseID {
                undo = .hidSuperset(day: day, id: pair.id, index: index, selected: selected)
            }
            workout.exerciseIDs.removeAll(where: members.contains)
            if let selected = workout.selectedExerciseID, members.contains(selected) {
                workout.selectedExerciseID = workout.exerciseIDs.first
            }
            state.training!.days[day.rawValue] = workout; state.training!.undo = undo
        }
    }
    @discardableResult public func deleteFromWorkout(_ target: TrainingWorkoutRemoval, on day: TrainingDay) -> Bool {
        guard selectedDay == day else { return false }
        return commit(onSuccess: { [weak self] in self?.revealRowID = nil }) { state in
            try finalize(&state)
            guard let original = state.training!.days[day.rawValue] else { throw TrainingError.invalidDay }
            let remaining = try target.remainingWorkout(from: original)
            let removedSets = original.rows.filter { remaining.rows[$0.key] == nil }.values
                .flatMap { $0.compactMap(\.performedSetID) }
            let removal = try state.journal.removeSets(removedSets)
            state.training!.days[day.rawValue] = remaining
            state.training!.undo = .removedFromWorkout(day: day, target: target, original: original, removal: removal)
        }
    }

    @discardableResult public func newSet(keyboard: Bool? = nil) -> Bool {
        commit { state in
            try finalize(&state)
            let (day, id) = try context(state)
            let existing = state.training!.days[day.rawValue]!.rows[id]?.last
            let row: TrainingRow
            if let existing, existing.dropGroupID == nil, existing.kind != .dropSet,
               existing.performedSetID == nil, existing.weight.isEmpty, existing.reps.isEmpty,
               existing.canonicalWeight == nil, !existing.weightIsDirty {
                row = existing
            } else {
                row = TrainingRow(unit: state.training!.days[day.rawValue]!.unit, kind: .working)
                state.training!.days[day.rawValue]!.rows[id, default: []].append(row)
            }
            let field: NumericField = exercise(id).requiresWeight ? .weight : .reps
            state.training!.focus = TrainingFocus(day: day, exerciseID: id, rowID: row.id,
                                                  field: field, keyboard: keyboard ?? (field == .reps))
            state.training!.undo = nil
        }
    }
    @discardableResult public func addDropStage(to rowID: UUID) -> Bool {
        commit { state in
            try finalize(&state)
            let (day, id) = try context(state)
            var rows = state.training!.days[day.rawValue]!.rows[id]!
            guard let index = rows.firstIndex(where: { $0.id == rowID }), rows[index].kind == .dropSet else { throw TrainingError.missingRow }
            let group = rows[index].dropGroupID ?? UUID()
            rows[index].dropGroupID = group
            let members = rows.indices.filter { rows[$0].dropGroupID == group }
            let last = members.last!
            let next: TrainingRow
            if members.count > 1, rows[last].performedSetID == nil, rows[last].weight.isEmpty,
               rows[last].reps.isEmpty, rows[last].canonicalWeight == nil, !rows[last].weightIsDirty {
                next = rows[last]
            } else {
                next = TrainingRow(unit: state.training!.days[day.rawValue]!.unit, kind: .dropSet, dropGroupID: group)
                rows.insert(next, at: last + 1)
            }
            state.training!.days[day.rawValue]!.rows[id] = rows
            let field: NumericField = exercise(id).requiresWeight ? .weight : .reps
            state.training!.focus = TrainingFocus(day: day, exerciseID: id, rowID: next.id, field: field, keyboard: field == .reps)
            state.training!.undo = nil
        }
    }
    @discardableResult public func selectInput(_ rowID: UUID, field: NumericField, keyboard: Bool? = nil) -> Bool {
        guard field != .sets else { return false }
        return commit(onSuccess: { [weak self] in self?.revealRowID = nil }) { state in
            let (day, id) = try context(state)
            if state.training!.focus?.rowID != rowID { try finalize(&state) }
            guard state.training!.days[day.rawValue]!.rows[id]?.contains(where: { $0.id == rowID }) == true else { throw TrainingError.missingRow }
            state.training!.focus = TrainingFocus(day: day, exerciseID: id, rowID: rowID, field: field,
                                                 keyboard: keyboard ?? (field == .reps))
        }
    }
    public func inputText(for token: TrainingFocus) -> String {
        guard focus?.id == token.id, let row = focusedRow else { return "" }
        return token.field == .weight ? row.weight : row.reps
    }
    public var focusedRow: TrainingRow? {
        guard let focus else { return nil }
        return workspace.days[focus.day.rawValue]?.rows[focus.exerciseID]?.first { $0.id == focus.rowID }
    }
    public func typeInput(_ text: String, focus token: TrainingFocus) {
        guard focus?.id == token.id, String(text.prefix(64)) != inputText(for: token) else { return }
        _ = writeSet(token.rowID, recover: true) { state in
            guard state.training!.focus?.id == token.id else { return }
            var rows = state.training!.days[token.day.rawValue]!.rows[token.exerciseID]!
            let index = rows.firstIndex { $0.id == token.rowID }!
            if token.field == .weight {
                rows[index].weight = String(text.prefix(64))
                rows[index].weightIsDirty = true
                if let bar = rows[index].barbellWeight, bar > (rows[index].parsedWeight ?? 0) { rows[index].barbellWeight = nil }
            } else { rows[index].reps = String(text.prefix(64)) }
            updateCorrection(&rows[index], exerciseID: token.exerciseID, journal: state.journal)
            state.training!.days[token.day.rawValue]!.rows[token.exerciseID] = rows
            state.training!.undo = nil
        }
    }
    @discardableResult public func finishEditing() -> Bool { commit { try finalize(&$0) } }
    func finalize(_ state: inout JournalSnapshot) throws {
        try synchronizeFocusedSet(&state, normalizeText: true)
        state.training!.focus = nil
    }
    private func synchronizeFocusedSet(_ state: inout JournalSnapshot, normalizeText: Bool = false) throws {
        guard let focus = state.training!.focus,
              var rows = state.training!.days[focus.day.rawValue]?.rows[focus.exerciseID],
              let index = rows.firstIndex(where: { $0.id == focus.rowID }) else { state.training!.focus = nil; return }
        let before = state.journal
        var row = rows[index]
        if let value = row.parsed(for: exercise(focus.exerciseID)) {
            let set: PerformedSet
            if let id = row.performedSetID { set = try state.journal.updateSet(id, values: value) }
            else {
                let date = focus.day == today ? now() : focus.day.date(in: calendar)
                set = try state.journal.record(DraftBatch(actionID: row.actionID, exerciseID: focus.exerciseID, sets: [value]), at: date).sets[0]
            }
            if normalizeText {
                row.accept(value, setID: set.id)
            } else {
                row.performedSetID = set.id
                row.canonicalWeight = value.weight
                row.pendingCorrection = nil
            }
        } else {
            updateCorrection(&row, exerciseID: focus.exerciseID, journal: state.journal)
        }
        if rows[index].performedSetID == nil && row.performedSetID != nil {
            state.training!.days[focus.day.rawValue]!.beginReadySuperset(for: focus.exerciseID, recorded: row)
        }
        rows[index] = row
        state.training!.days[focus.day.rawValue]!.rows[focus.exerciseID] = rows
        if state.journal != before { state.training!.undo = nil }
    }
    private func updateCorrection(_ row: inout TrainingRow, exerciseID: String, journal: Journal) {
        guard let setID = row.performedSetID, let saved = journal.reference(to: setID)?.set.values else {
            row.pendingCorrection = nil
            return
        }
        row.pendingCorrection = row.parsed(for: exercise(exerciseID)) == saved ? nil : true
    }
    @discardableResult public func changeUnit(_ next: WeightUnit) -> Bool {
        commit { state in
            let (day, _) = try context(state)
            var workout = state.training!.days[day.rawValue]!
            if next != workout.unit, workout.programSession?.initialUnit == nil {
                workout.programSession?.initialUnit = workout.unit
            }
            for id in workout.rows.keys {
                var rows = workout.rows[id]!
                for index in rows.indices { guard rows[index].changeUnit(to: next) else { throw TrainingError.incompleteWeight } }
                workout.rows[id] = rows
            }
            workout.unit = next; state.training!.days[day.rawValue] = workout; state.training!.preferredUnit = next
            if let old = state.training!.focus {
                state.training!.focus = TrainingFocus(day: old.day, exerciseID: old.exerciseID, rowID: old.rowID, field: old.field, keyboard: false)
            }
        }
    }
    @discardableResult public func repeatLastSet(actionID: UUID = UUID()) -> Bool {
        if journal.hasConsumedAction(actionID) {
            return rows.contains { $0.actionID == actionID && $0.performedSetID != nil }
        }
        return commit { state in
            try finalize(&state)
            let (day, id) = try context(state)
            guard let previous = TrainingSetEntry.grouping(state.training!.days[day.rawValue]!.rows[id] ?? []).last else { throw TrainingError.missingRow }
            let values = try previous.rows.map { row in
                guard let values = row.parsed(for: exercise(id)) else { throw TrainingError.missingRow }
                return values
            }
            let date = day == today ? now() : day.date(in: calendar)
            let group = previous.isDropSet ? UUID() : nil
            var repeated: [TrainingRow] = []
            for (index, source) in previous.rows.enumerated() {
                let values = values[index], action = index == 0 ? actionID : UUID()
                let set = try state.journal.record(DraftBatch(actionID: action, exerciseID: id, sets: [values]), at: date).sets[0]
                var row = TrainingRow(actionID: action, weight: source.weight.isEmpty ? "" : source.unit.text(for: values.weight),
                    reps: String(values.reps), unit: source.unit, canonicalWeight: values.weight, kind: source.kind, dropGroupID: group)
                row.barbellWeight = source.barbellWeight
                row.performedSetID = set.id; repeated.append(row)
            }
            state.training!.days[day.rawValue]!.rows[id, default: []].append(contentsOf: repeated)
            if let first = repeated.first { state.training!.days[day.rawValue]!.beginReadySuperset(for: id, recorded: first) }
            state.training!.undo = group == nil
                ? .repeated(day: day, exerciseID: id, rowID: repeated[0].id)
                : .repeatedGroup(day: day, exerciseID: id, rowIDs: repeated.map(\.id))
        }
    }
    @discardableResult public func deleteSet(_ rowID: UUID) -> Bool {
        commit { state in
            try finalize(&state)
            let (day, id) = try context(state)
            var rows = state.training!.days[day.rawValue]!.rows[id]!
            guard let entry = TrainingSetEntry.grouping(rows).first(where: { $0.rows.contains { $0.id == rowID } }),
                  let index = rows.firstIndex(where: { $0.id == entry.rows[0].id }) else { throw TrainingError.missingRow }
            if entry.dropGroupID != nil {
                let ids = Set(entry.rows.map(\.id))
                let removal = try state.journal.removeSets(entry.rows.compactMap(\.performedSetID))
                rows.removeAll { ids.contains($0.id) }
                state.training!.days[day.rawValue]!.rows[id] = rows
                state.training!.undo = .deletedGroup(day: day, exerciseID: id, index: index, rows: entry.rows, removal: removal)
                return
            }
            let row = rows.remove(at: index)
            let removal = try row.performedSetID.map { try state.journal.removeSet($0) }
            state.training!.days[day.rawValue]!.rows[id] = rows
            if let group = state.training!.days[day.rawValue]!.supersets?.first(where: { $0.rowIDs.contains(rowID) }) {
                var workout = state.training!.days[day.rawValue]!
                workout.reconcileSupersetRows()
                let previousIDs = Set(rows.map(\.id))
                let generated = workout.rows[id]?.first { !previousIDs.contains($0.id) }
                let context = SupersetSetUndo(original: group, generatedRowID: generated?.id)
                state.training!.days[day.rawValue] = workout
                state.training!.undo = .deletedSupersetSet(day: day, exerciseID: id, index: index, row: row,
                                                          removal: removal, superset: context)
            } else {
                state.training!.undo = .deleted(day: day, exerciseID: id, index: index, row: row, removal: removal)
            }
        }
    }
    @discardableResult public func deleteDropStage(_ rowID: UUID) -> Bool {
        commit { state in
            try finalize(&state)
            let (day, id) = try context(state)
            var rows = state.training!.days[day.rawValue]!.rows[id]!
            guard let index = rows.firstIndex(where: { $0.id == rowID }), rows[index].kind == .dropSet else { throw TrainingError.missingRow }
            let row = rows.remove(at: index)
            let removal = try row.performedSetID.map { try state.journal.removeSet($0) }
            state.training!.days[day.rawValue]!.rows[id] = rows
            state.training!.undo = .deleted(day: day, exerciseID: id, index: index, row: row, removal: removal)
        }
    }
    @discardableResult public func undoChange() -> Bool {
        guard focus == nil, let undo = workspace.undo else { return false }
        return commit { state in
            switch undo {
            case .hidSuperset(let day, let id, let index, let selected):
                try state.training!.days[day.rawValue]!.restoreHiddenSuperset(id, at: index, selected: selected)
            case .unpaired(let day, let group, let index):
                var groups = state.training!.days[day.rawValue]!.supersets ?? []
                groups.insert(group, at: index)
                state.training!.days[day.rawValue]!.supersets = groups
            case .removedFromWorkout(let day, _, let original, let removal):
                _ = try state.journal.restoreSets(removal)
                state.training!.days[day.rawValue] = original
            case .repeated(let day, let id, let rowID):
                var rows = state.training!.days[day.rawValue]!.rows[id]!
                guard let index = rows.firstIndex(where: { $0.id == rowID }), let set = rows[index].performedSetID else { throw TrainingError.missingRow }
                _ = try state.journal.removeSet(set); rows.remove(at: index)
                state.training!.days[day.rawValue]!.rows[id] = rows
            case .deleted(let day, let id, let index, let row, let removal),
                 .deletedSupersetSet(let day, let id, let index, let row, let removal, _):
                if let removal { _ = try state.journal.restoreSet(removal) }
                var restored = row
                var workout = state.training!.days[day.rawValue]!
                if !restored.changeUnit(to: workout.unit) {
                    // An incomplete deleted weight keeps its original unit. Other
                    // values remain exact while restoring that input context.
                    for key in workout.rows.keys {
                        var current = workout.rows[key]!
                        for i in current.indices { guard current[i].changeUnit(to: row.unit) else { throw TrainingError.incompleteWeight } }
                        workout.rows[key] = current
                    }
                    workout.unit = row.unit
                }
                var rows = workout.rows[id]!
                rows.insert(restored, at: min(index, rows.count)); workout.rows[id] = rows
                if let context = undo.supersetSetUndo { try context.restore(in: &workout, exerciseID: id, rowID: row.id) }
                state.training!.days[day.rawValue] = workout
            case .repeatedGroup(let day, let id, let rowIDs):
                let selected = Set(rowIDs)
                var rows = state.training!.days[day.rawValue]!.rows[id]!
                let removed = rows.filter { selected.contains($0.id) }
                guard removed.count == rowIDs.count else { throw TrainingError.missingRow }
                _ = try state.journal.removeSets(removed.compactMap(\.performedSetID))
                rows.removeAll { selected.contains($0.id) }
                state.training!.days[day.rawValue]!.rows[id] = rows
            case .deletedGroup(let day, let id, let index, let deleted, let removal):
                _ = try state.journal.restoreSets(removal)
                var workout = state.training!.days[day.rawValue]!
                var restored = deleted
                let currentUnit = workout.unit
                if !restored.indices.allSatisfy({ restored[$0].changeUnit(to: currentUnit) }) {
                    let originalUnit = deleted[0].unit
                    for key in workout.rows.keys {
                        for position in workout.rows[key]!.indices {
                            guard workout.rows[key]![position].changeUnit(to: originalUnit) else { throw TrainingError.incompleteWeight }
                        }
                    }
                    workout.unit = originalUnit; restored = deleted
                }
                workout.rows[id]!.insert(contentsOf: restored, at: min(index, workout.rows[id]!.count))
                state.training!.days[day.rawValue] = workout
            }
            state.training!.undo = nil
        }
    }
    @discardableResult public func openReference(_ reference: TrainingPerformanceReference) -> Bool {
        guard let setID = workspace.days[reference.day.rawValue]?.rows[reference.exerciseID]?
            .first(where: { $0.id == reference.rowID })?.performedSetID else {
            errorMessage = "This recorded set is no longer available."
            return false
        }
        return openProgress(for: reference.exerciseID, on: reference.day, highlighting: setID)
    }
    @discardableResult public func editRecordedSession(for exerciseID: String, on day: TrainingDay,
                                                      setID: UUID? = nil) -> Bool {
        guard let session = snapshot.recordedSessions(for: exercise(exerciseID), calendar: calendar).first(where: { $0.day == day }),
              let set = setID.flatMap({ id in session.sets.first { $0.id == id } }) ?? (setID == nil ? session.sets.first : nil),
              let row = workspace.days[day.rawValue]?.rows[exerciseID]?.first(where: { $0.performedSetID == set.id }) else {
            errorMessage = "This recorded workout is no longer available."
            return false
        }
        let origin = historyReturnContext ?? HistoryReturnContext(day: selectedDay, week: workspace.visibleWeek, exerciseID: exercise?.id)
        let reference = TrainingPerformanceReference(day: day, exerciseID: exerciseID, rowID: row.id, values: set.values)
        let saved = open(reference, onSuccess: { [weak self] in
            self?.historyReturnContext = origin
            self?.section = .log
            self?.isProgressPresented = false
        })
        pendingProgressAction = !saved
        return saved
    }
    @discardableResult public func returnToWorkoutFromHistory() -> Bool {
        guard let origin = historyReturnContext else { return true }
        return commit(onSuccess: { [weak self] in
            self?.historyReturnContext = nil
            self?.revealRowID = nil
            self?.section = .log
        }) { state in
            try finalize(&state)
            state.training!.selectedDay = origin.day
            state.training!.visibleWeek = origin.week
            if let day = origin.day, let id = origin.exerciseID,
               state.training!.days[day.rawValue]?.exerciseIDs.contains(id) == true {
                state.training!.days[day.rawValue]!.selectedExerciseID = id
            }
            state.training!.undo = nil
        }
    }
    private func open(_ reference: TrainingPerformanceReference, onSuccess: (() -> Void)? = nil) -> Bool {
        commit(onSuccess: { [weak self] in
            self?.revealRowID = reference.rowID
            onSuccess?()
        }) { state in
            try finalize(&state)
            state.training!.selectedDay = reference.day; state.training!.visibleWeek = try reference.day.week()[0]
            try add(reference.exerciseID, in: &state)
        }
    }
    @discardableResult public func stepInput(increasing: Bool, focus token: TrainingFocus) -> Bool {
        guard focus?.id == token.id, let row = focusedRow else { return false }
        if token.field == .weight {
            guard let current = row.parsedWeight ?? (row.weight.isEmpty ? 0 : nil) else { return false }
            return setInputWeight(row.unit.stepped(current, increasing: increasing), focus: token)
        }
        guard let current = NumericField.reps.parse(row.reps) ?? (row.reps.isEmpty ? 0 : nil) else { return false }
        typeInput(String(min(999, max(1, current + (increasing ? 1 : -1)))), focus: token)
        return true
    }
    @discardableResult public func setInputWeight(_ weight: Int, focus token: TrainingFocus) -> Bool {
        let bar = focusedRow?.barbellWeight.flatMap { $0 <= weight ? $0 : nil }
        return writeInputWeight(weight, barbellWeight: bar, focus: token, recover: true)
    }
    private func writeInputWeight(_ weight: Int, barbellWeight: Int?, focus token: TrainingFocus, recover: Bool,
                                  onSuccess: (() -> Void)? = nil) -> Bool {
        guard focus == token, token.field == .weight, NumericField.weight.range.contains(weight) else { return false }
        return writeSet(token.rowID, recover: recover, onSuccess: onSuccess) { state in
            var rows = state.training!.days[token.day.rawValue]!.rows[token.exerciseID]!
            let index = rows.firstIndex { $0.id == token.rowID }!
            rows[index].barbellWeight = barbellWeight
            rows[index].canonicalWeight = weight; rows[index].weightIsDirty = false; rows[index].weight = rows[index].unit.text(for: weight)
            updateCorrection(&rows[index], exerciseID: token.exerciseID, journal: state.journal)
            state.training!.days[token.day.rawValue]!.rows[token.exerciseID] = rows; state.training!.undo = nil
        }
    }
    private func adjustedPlateWeight(_ size: Decimal, count: Int, focus token: TrainingFocus) -> Int? {
        guard !canRetrySave, !backupRecoveryRequired, focus == token, token.field == .weight,
              let row = focusedRow, [-2, -1, 1, 2].contains(count), row.unit.plateSizes.contains(size),
              let current = row.weight.isEmpty ? 0 : row.parsedWeight else { return nil }
        let change = size * Decimal(count)
        let target = row.unit.displayedAmount(for: current) + change
        if let bar = row.barbellWeight {
            let floor = row.unit.displayedAmount(for: bar)
            guard target >= floor else { return nil }
            if target == floor { return bar }
        }
        // A reverse move can recover extra precision from a prior lb-to-kg conversion.
        if target > 0, let undo = plateUndo, undo.matches(row),
           case let .plates(previousSize, previousCount) = undo.change,
           previousSize * Decimal(previousCount) == -change, let previous = undo.before.parsedWeight {
            return previous
        }
        return row.unit.canonicalValue(for: target)
    }
    public func canAdjustPlate(_ size: Decimal, count: Int, focus token: TrainingFocus) -> Bool {
        adjustedPlateWeight(size, count: count, focus: token) != nil
    }
    @discardableResult public func adjustPlate(_ size: Decimal, count: Int, focus token: TrainingFocus) -> Bool {
        guard let weight = adjustedPlateWeight(size, count: count, focus: token), let before = focusedRow else { return false }
        return writeLoadAdjustment(.plates(size: size, count: count), weight: weight, bar: before.barbellWeight, before: before, focus: token)
    }

    @discardableResult public func applyPlateLoad(totalWeight: Int, barbellWeight: Int, focus token: TrainingFocus) -> Bool {
        guard !canRetrySave, !backupRecoveryRequired, focus == token, token.field == .weight, let row = focusedRow,
              case let .exact(total, perSide)? = PlateLoading.calculate(totalWeight: totalWeight, barbellWeight: barbellWeight,
                                                                  unit: row.unit) else { return false }
        // Distinct stored loads can display as the same kg value after a unit change.
        if row.barbellWeight == barbellWeight, let current = row.parsedWeight,
           current == total || (!perSide.isEmpty && row.unit.displayedAmount(for: current) == row.unit.displayedAmount(for: total)) {
            return true
        }
        return writeLoadAdjustment(.plateLoad, weight: total, bar: barbellWeight, before: row, focus: token)
    }

    private func weightWithBarbell(_ bar: Int?, focus token: TrainingFocus) -> Int? {
        guard !canRetrySave, !backupRecoveryRequired, focus == token, token.field == .weight, let row = focusedRow,
              bar != row.barbellWeight, bar.map({ $0 > 0 && NumericField.weight.range.contains($0) }) ?? true,
              let current = row.weight.isEmpty ? 0 : row.parsedWeight else { return nil }
        let total = current - (row.barbellWeight ?? 0) + (bar ?? 0)
        return NumericField.weight.range.contains(total) ? total : nil
    }
    public func canSetBarbellWeight(_ bar: Int?, focus token: TrainingFocus) -> Bool {
        weightWithBarbell(bar, focus: token) != nil
    }
    @discardableResult public func setBarbellWeight(_ bar: Int?, focus token: TrainingFocus) -> Bool {
        guard let total = weightWithBarbell(bar, focus: token), let before = focusedRow else { return false }
        return writeLoadAdjustment(.barbell, weight: total, bar: bar, before: before, focus: token)
    }
    private func writeLoadAdjustment(_ change: TrainingLoadAdjustment, weight: Int, bar: Int?,
                                     before: TrainingRow, focus token: TrainingFocus) -> Bool {
        let recordedBefore = recordedValues(for: before)
        return writeInputWeight(weight, barbellWeight: bar, focus: token, recover: false) { [weak self] in
            guard let self, let after = self.focusedRow else { return }
            self.plateUndo = PlateUndo(day: token.day, exerciseID: token.exerciseID, change: change,
                                      before: before, recordedBefore: recordedBefore, after: after)
        }
    }
    public func lastPlateAdjustment(focus token: TrainingFocus) -> (size: Decimal, count: Int)? {
        guard case let .plates(size, count) = lastLoadAdjustment(focus: token) else { return nil }
        return (size, count)
    }
    public func lastLoadAdjustment(focus token: TrainingFocus) -> TrainingLoadAdjustment? {
        guard !canRetrySave, focus == token, token.field == .weight, let undo = plateUndo,
              undo.day == token.day, undo.exerciseID == token.exerciseID, undo.matches(focusedRow) else { return nil }
        return undo.change
    }
    @discardableResult public func undoPlateAdjustment(focus token: TrainingFocus) -> Bool {
        guard lastLoadAdjustment(focus: token) != nil, let undo = plateUndo else { return false }
        return commit(synchronizeInput: false, onSuccess: { [weak self] in self?.plateUndo = nil }) { state in
            guard var rows = state.training!.days[token.day.rawValue]?.rows[token.exerciseID],
                  let index = rows.firstIndex(where: { $0.id == token.rowID }) else { throw TrainingError.missingRow }
            var row = rows[index]
            if let performed = row.performedSetID {
                if let recorded = undo.recordedBefore {
                    _ = try state.journal.updateSet(performed, values: recorded)
                } else {
                    _ = try state.journal.removeSet(performed)
                    // The journal retains an undo receipt. The restored draft needs a fresh record action.
                    row.actionID = UUID()
                }
            }
            row.performedSetID = undo.before.performedSetID
            row.barbellWeight = undo.before.barbellWeight
            row.weight = undo.before.weight
            row.canonicalWeight = undo.before.canonicalWeight
            row.weightIsDirty = undo.before.weightIsDirty
            row.pendingCorrection = undo.before.pendingCorrection
            rows[index] = row
            state.training!.days[token.day.rawValue]!.rows[token.exerciseID] = rows
        }
    }
    public func dismissError() { errorMessage = nil }
    @discardableResult public func flushRecovery() -> Bool {
        pendingSave == nil ? commit { _ in } : retrySave()
    }
    private func context(_ state: JournalSnapshot) throws -> (TrainingDay, String) {
        guard let day = state.training!.selectedDay, let id = state.training!.days[day.rawValue]?.selectedExerciseID else { throw TrainingError.missingRow }
        return (day, id)
    }
    /// Publish only a direct numeric edit that reaches storage, including a successful retry.
    private func writeSet(_ rowID: UUID, recover: Bool = false, onSuccess: (() -> Void)? = nil,
                          _ update: (inout JournalSnapshot) throws -> Void) -> Bool {
        guard let selectedDay, let exerciseID = exercise?.id,
              let row = rows.first(where: { $0.id == rowID }) else { return false }
        let before = recordedValues(for: row)
        return commit(recover: recover, onSuccess: { [weak self] in
            onSuccess?()
            guard let self, let saved = self.workspace.days[selectedDay.rawValue]?.rows[exerciseID]?.first(where: { $0.id == rowID }),
                  let reference = self.recordedReference(saved, exerciseID: exerciseID, day: selectedDay),
                  reference.values != before else { return }
            self.latestWorkoutSetWrite = reference
        }, update)
    }

    func commit(recover: Bool = false, synchronizeInput: Bool = true, onSuccess: (() -> Void)? = nil,
                        _ update: (inout JournalSnapshot) throws -> Void) -> Bool {
        guard !backupRecoveryRequired else { errorMessage = NotebookBackupWorkflowError.recoveryRequired.localizedDescription; return false }
        var candidate = snapshot
        var recoveryCandidate = snapshot
        let checked: ValidatedJournalSnapshot
        do {
            try update(&candidate)
            // Failed numeric writes retain raw input over the last durable journal.
            // Their pending transaction includes the matching performed-set update.
            recoveryCandidate = candidate
            if synchronizeInput { try synchronizeFocusedSet(&candidate) }
            // A later edit to this day supersedes undo that would restore old workout or round state.
            if let day = candidate.training?.undo?.invalidatedByWorkoutEditOn,
               candidate.training?.undo == snapshot.training?.undo,
               candidate.training?.days[day.rawValue] != snapshot.training?.days[day.rawValue] {
                candidate.training?.undo = nil
                recoveryCandidate.training?.undo = nil
            }
            if let day = candidate.training?.selectedDay?.rawValue,
               candidate.training?.days[day]?.supersets?.isEmpty == false,
               candidate.training?.days[day]?.rows != snapshot.training?.days[day]?.rows {
                candidate.training?.days[day]?.reconcileSupersetRows()
            }
            if snapshot.training?.programEnrollments != nil, snapshot.training?.undo != candidate.training?.undo {
                candidate.training?.discardUnusedProgramEnrollments()
                recoveryCandidate.training?.discardUnusedProgramEnrollments()
            }
            checked = try ValidatedJournalSnapshot(candidate)
        }
        catch { errorMessage = error.localizedDescription; return false }
        // A new intentional transaction supersedes an obsolete failed action.
        // Recovery itself calls persist directly and never replaces that action.
        pendingSave = nil
        pendingProfileAction = nil
        pendingProgressAction = false
        let transaction = PendingSave(checked: checked, onSuccess: onSuccess)
        if candidate == lastWritten {
            snapshot = candidate; errorMessage = nil; onSuccess?()
            return true
        }
        let result = persist(transaction)
        if !result && recover && recoveryCandidate.journal == snapshot.journal { snapshot = recoveryCandidate }
        return result
    }
    private func persist(_ transaction: PendingSave) -> Bool {
        guard !backupRecoveryRequired else { errorMessage = NotebookBackupWorkflowError.recoveryRequired.localizedDescription; return false }
        do {
            // Retry always reaches storage, including while writes remain unavailable.
            try repository.saveValidatedSnapshot(transaction.checked)
            lastWritten = transaction.checked.snapshot; snapshot = transaction.checked.snapshot
            if let undo = plateUndo {
                let current = workspace.days[undo.day.rawValue]?.rows[undo.exerciseID]?.first { $0.id == undo.after.id }
                if !undo.matches(current) { plateUndo = nil }
            }
            if !hasSavedFirstSet && !transaction.checked.snapshot.journal.batches.isEmpty { hasSavedFirstSet = true }
            pendingSave = nil; pendingProfileAction = nil; pendingProgressAction = false; errorMessage = nil
            transaction.onSuccess?()
            return true
        } catch {
            pendingSave = transaction
            errorMessage = error.localizedDescription
            return false
        }
    }
}

public enum NotebookBackupWorkflowError: LocalizedError {
    case recoveryRequired, profileUnavailable
    public var errorDescription: String? {
        switch self {
        case .recoveryRequired: "Finish restoring the original files before using this notebook."
        case .profileUnavailable: "Your profile could not be read. Try opening it again before making a full backup. You can still export recorded sets as CSV."
        }
    }
}
