import Foundation
import Observation
import SendaDomain
import SendaPersistence

public struct TrainingDaySummary: Equatable, Sendable {
    public let exercises: [String]
    public let muscleGroups: [MuscleGroup]
    public let setCount: Int
}
public struct TrainingPerformanceReference: Equatable, Sendable {
    public let day: TrainingDay
    public let exerciseID: String
    public let rowID: UUID
    public let values: SetValues
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
    public private(set) var errorMessage: String?
    public private(set) var revealRowID: UUID?
    public private(set) var section: TrainingSection = .log
    public var isProgressPresented = false
    public var progressExerciseID: String?
    public var progressRange: ExerciseProgressRange = .twelveWeeks
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
    public var learningQuery = ""
    public var learningExerciseID: String?
    private enum ProfileAction { case unit(WeightUnit), record(ExercisePersonalRecord) }
    private var pendingProfileAction: ProfileAction?
    public var canRetryProfileAction: Bool { pendingProfileAction != nil }
    public private(set) var backupErrorMessage: String?
    public private(set) var backupRecoveryRequired = false
    @ObservationIgnored private let restoreStore: any NotebookRestoreStore
    public let profile: ProfileModel
    public let isSample: Bool
    public let calendar: Calendar
    @ObservationIgnored private let repository: any JournalRepository
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var lastWritten: JournalSnapshot
    private struct PendingSave {
        let snapshot: JournalSnapshot
        let onSuccess: (() -> Void)?
    }
    private var pendingSave: PendingSave?

    public init(repository: any JournalRepository, isSample: Bool = false, calendar: Calendar = .current,
                now: @escaping () -> Date = Date.init, profileRepository: (any ProfileRepository)? = nil,
                restoreStore: (any NotebookRestoreStore)? = nil) throws {
        let profileRepository = profileRepository ?? MemoryProfileRepository()
        let restoreStore = restoreStore ?? MemoryNotebookRestoreStore(repository: repository, profileRepository: profileRepository)
        try restoreStore.recoverInterruptedRestore()
        self.restoreStore = restoreStore
        self.profile = ProfileModel(repository: profileRepository)
        self.repository = repository; self.isSample = isSample; self.calendar = calendar; self.now = now
        let saved = try repository.loadSnapshot().validated()
        lastWritten = saved
        let training = try TrainingWorkspace.migrate(saved, today: TrainingDay(now(), calendar: calendar), calendar: calendar)
        snapshot = try JournalSnapshot(journal: saved.journal, customExercises: saved.customExercises, training: training).validated()
    }
    public func backupData() throws -> Data {
        guard !backupRecoveryRequired else { throw NotebookBackupWorkflowError.recoveryRequired }
        guard profile.openingError == nil else { throw NotebookBackupWorkflowError.profileUnavailable }
        return try NotebookBackupCodec.encode(NotebookArchive(snapshot: snapshot, profile: profile.details, createdAt: now()))
    }
    public func csvData() throws -> Data {
        guard !backupRecoveryRequired else { throw NotebookBackupWorkflowError.recoveryRequired }
        return try NotebookBackupCodec.csv(snapshot: snapshot, calendar: calendar)
    }
    public func previousBackupData() throws -> Data? { try restoreStore.previousBackupData() }
    public func previousOriginalFilesData() throws -> Data? { try restoreStore.previousOriginalFilesData() }
    public func originalJournalData() throws -> Data? { try restoreStore.originalJournalData() }
    @discardableResult public func restoreBackup(_ archive: NotebookArchive) -> Bool {
        do {
            let checked = try archive.validated()
            let training = try TrainingWorkspace.migrate(checked.snapshot, today: today, calendar: calendar)
            let archive = try NotebookArchive(snapshot: JournalSnapshot(journal: checked.snapshot.journal,
                customExercises: checked.snapshot.customExercises, training: training), profile: checked.profile,
                createdAt: checked.createdAt).validated()
            try restoreStore.recoverInterruptedRestore()
            // A broken profile requires raw-file protection. Persist visible recovery
            // input first so that protected journal includes every current draft.
            if profile.openingError != nil {
                try repository.saveSnapshot(snapshot)
                lastWritten = snapshot
            }
            let current = profile.openingError == nil
                ? try NotebookArchive(snapshot: snapshot, profile: profile.details, createdAt: now()).validated() : nil
            try restoreStore.restore(archive, current: current)
            snapshot = archive.snapshot; lastWritten = archive.snapshot
            pendingSave = nil; pendingProfileAction = nil; revealRowID = nil
            errorMessage = nil; backupErrorMessage = nil; backupRecoveryRequired = false
            learningExerciseID = nil; learningQuery = ""
            isProgressPresented = false; progressExerciseID = nil; progressRange = .twelveWeeks; pendingProgressAction = false
            progressSessionDay = nil; progressSetID = nil; historyReturnContext = nil
            profile.reload()
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
            return true
        } catch { backupErrorMessage = error.localizedDescription; return false }
    }
    public var personalRecords: [ExercisePersonalRecord] {
        journal.personalRecords.sorted { exercise($0.exerciseID).name.localizedStandardCompare(exercise($1.exerciseID).name) == .orderedAscending }
    }
    public var bigThreeProgress: BigThreeProgress { journal.bigThreeProgress }
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
    public var today: TrainingDay { TrainingDay(now(), calendar: calendar) }
    public var selectedDay: TrainingDay? { workspace.selectedDay }
    public var focus: TrainingFocus? { workspace.focus }
    public var workout: DayWorkout? { selectedDay.flatMap { workspace.days[$0.rawValue] } }
    public var exercise: Exercise? { workout?.selectedExerciseID.map { exercise($0) } }
    public var exercises: [Exercise] {
        let known = Exercise.catalog + (snapshot.customExercises ?? [])
        let ids = Set(known.map(\.id))
        return known + (workspace.legacyExerciseIDs ?? []).filter { !ids.contains($0) }.map {
            Exercise(id: $0, name: $0, shortName: $0, startingWeight: 0)
        }
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
        case .repeated, .repeatedGroup: "Set repeated"
        case .deleted, .deletedGroup: "Set removed"
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
        guard let workout = workspace.days[day.rawValue] else { return TrainingDaySummary(exercises: [], muscleGroups: [], setCount: 0) }
        let order = workout.exerciseIDs + workout.rows.keys.sorted().filter { !workout.exerciseIDs.contains($0) }
        let performed = order.filter { id in workout.rows[id]?.contains { $0.performedSetID != nil } == true }
        let trained = Set(performed.map { exercise($0).group })
        return TrainingDaySummary(exercises: performed.map { exercise($0).name },
            muscleGroups: MuscleGroup.allCases.filter { trained.contains($0) },
            setCount: workout.rows.values.reduce(0) { count, rows in
                count + TrainingSetEntry.grouping(rows).filter { $0.rows.contains { $0.performedSetID != nil } }.count
            })
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
        return commit { state in
            if state.training!.focus?.rowID != rowID { try finalize(&state) }
            let (day, id) = try context(state)
            guard let index = state.training!.days[day.rawValue]!.rows[id]?.firstIndex(where: { $0.id == rowID }) else { throw TrainingError.missingRow }
            var row = state.training!.days[day.rawValue]!.rows[id]![index]
            row.weight = reference.values.weight == 0 && !exercise(id).requiresWeight ? "" : row.unit.text(for: reference.values.weight)
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
            result.append(exercise(batch.element.exerciseID))
            if result.count == limit { break }
        }
        return result
    }
    public func indexedExercises(on day: TrainingDay) -> [Exercise] {
        guard let workout = workspace.days[day.rawValue] else { return [] }
        let hidden = workout.rows.keys.sorted().filter { id in
            !workout.exerciseIDs.contains(id) && workout.rows[id]?.contains {
                $0.performedSetID != nil || !$0.weight.isEmpty || !$0.reps.isEmpty
            } == true
        }
        return (workout.exerciseIDs + hidden).map { exercise($0) }
    }
    public var reusableWorkouts: [TrainingWorkoutStructure] {
        guard let selectedDay else { return [] }
        return workspace.days.keys.sorted(by: >).compactMap { key in
            guard let day = try? TrainingDay(key), day < selectedDay else { return nil }
            let count = summary(for: day).setCount
            guard count > 0 else { return nil }
            return TrainingWorkoutStructure(day: day, exerciseIDs: indexedExercises(on: day).map(\.id), recordedSetCount: count)
        }
    }
    @discardableResult public func reuseWorkout(from day: TrainingDay) -> Bool {
        guard let structure = reusableWorkouts.first(where: { $0.day == day }),
              let source = workspace.days[day.rawValue] else { return false }
        return addExercises(structure.exerciseIDs, plansFrom: source)
    }
    public var personalBest: TrainingPerformanceReference? { best(references) }
    private var references: [TrainingPerformanceReference] {
        guard let exercise else { return [] }
        return workspace.days.keys.sorted().flatMap { key -> [TrainingPerformanceReference] in
            guard let day = try? TrainingDay(key) else { return [] }
            return (workspace.days[key]?.rows[exercise.id] ?? []).compactMap { row in
                guard let id = row.performedSetID, let set = journal.reference(to: id)?.set else { return nil }
                return TrainingPerformanceReference(day: day, exerciseID: exercise.id, rowID: row.id, values: set.values)
            }
        }
    }
    private func best(_ refs: [TrainingPerformanceReference]) -> TrainingPerformanceReference? {
        refs.enumerated().max {
            if $0.element.values.weight != $1.element.values.weight { return $0.element.values.weight < $1.element.values.weight }
            if $0.element.values.reps != $1.element.values.reps { return $0.element.values.reps < $1.element.values.reps }
            return $0.offset < $1.offset
        }?.element
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
        commit { state in
            try finalize(&state)
            state.training!.visibleWeek = try today.week()[0]
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
        guard exercises.contains(where: { $0.id == id }) else { return false }
        return commit { state in try finalize(&state); try add(id, in: &state) }
    }
    @discardableResult public func addExercises(_ ids: [String]) -> Bool {
        addExercises(ids, plansFrom: nil)
    }
    private func addExercises(_ ids: [String], plansFrom source: DayWorkout?) -> Bool {
        guard ids.allSatisfy({ id in exercises.contains { $0.id == id } }) else { return false }
        var seen = Set<String>()
        let ordered = ids.filter { seen.insert($0).inserted }
        return commit { state in
            try finalize(&state)
            guard let day = state.training!.selectedDay, var workout = state.training!.days[day.rawValue] else { throw TrainingError.invalidDay }
            var firstNew: String?
            for id in ordered {
                if !workout.exerciseIDs.contains(id) {
                    workout.exerciseIDs.append(id)
                    if firstNew == nil { firstNew = id }
                }
                ensureRows(for: id, on: day, in: &workout, workspace: state.training!, plansFrom: source)
            }
            if let firstNew { workout.selectedExerciseID = firstNew }
            state.training!.days[day.rawValue] = workout; state.training!.undo = nil
        }
    }
    @discardableResult public func createExercise(named name: String, group: MuscleGroup, equipment: ExerciseEquipment) -> Bool {
        commit { state in
            let created = try ExerciseLibrary.custom(named: name, existing: exercises, muscleGroup: group, equipment: equipment)
            try finalize(&state)
            state.customExercises = (state.customExercises ?? []) + [created]
            try add(created.id, in: &state)
        }
    }
    private func add(_ id: String, in state: inout JournalSnapshot) throws {
        guard let day = state.training!.selectedDay, var workout = state.training!.days[day.rawValue] else { throw TrainingError.invalidDay }
        if !workout.exerciseIDs.contains(id) { workout.exerciseIDs.append(id) }
        ensureRows(for: id, on: day, in: &workout, workspace: state.training!)
        workout.selectedExerciseID = id
        state.training!.days[day.rawValue] = workout; state.training!.undo = nil
    }
    private func ensureRows(for id: String, on day: TrainingDay, in workout: inout DayWorkout,
                            workspace: TrainingWorkspace, plansFrom source: DayWorkout? = nil) {
        let firstAddition = workout.rows[id] == nil
        if workout.rows[id]?.isEmpty ?? true { workout.rows[id] = [TrainingRow(unit: workout.unit, kind: .working)] }
        guard firstAddition else { return }
        let plan: ExercisePlan?
        if let source {
            plan = source.exercisePlans?[id]
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
    @discardableResult public func removeExercise(_ id: String) -> Bool {
        commit { state in
            try finalize(&state)
            guard let day = state.training!.selectedDay, var workout = state.training!.days[day.rawValue] else { throw TrainingError.invalidDay }
            workout.exerciseIDs.removeAll { $0 == id }
            if workout.selectedExerciseID == id { workout.selectedExerciseID = workout.exerciseIDs.first }
            state.training!.days[day.rawValue] = workout; state.training!.undo = nil
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
        _ = commit(recover: true) { state in
            guard state.training!.focus?.id == token.id else { return }
            var rows = state.training!.days[token.day.rawValue]!.rows[token.exerciseID]!
            let index = rows.firstIndex { $0.id == token.rowID }!
            if token.field == .weight { rows[index].weight = String(text.prefix(64)); rows[index].weightIsDirty = true }
            else { rows[index].reps = String(text.prefix(64)) }
            updateCorrection(&rows[index], exerciseID: token.exerciseID, journal: state.journal)
            state.training!.days[token.day.rawValue]!.rows[token.exerciseID] = rows
            state.training!.undo = nil
        }
    }
    @discardableResult public func finishEditing() -> Bool { commit { try finalize(&$0) } }
    private func finalize(_ state: inout JournalSnapshot) throws {
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
                row.performedSetID = set.id; repeated.append(row)
            }
            state.training!.days[day.rawValue]!.rows[id, default: []].append(contentsOf: repeated)
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
            state.training!.undo = .deleted(day: day, exerciseID: id, index: index, row: row, removal: removal)
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
            case .repeated(let day, let id, let rowID):
                var rows = state.training!.days[day.rawValue]!.rows[id]!
                guard let index = rows.firstIndex(where: { $0.id == rowID }), let set = rows[index].performedSetID else { throw TrainingError.missingRow }
                _ = try state.journal.removeSet(set); rows.remove(at: index)
                state.training!.days[day.rawValue]!.rows[id] = rows
            case .deleted(let day, let id, let index, let row, let removal):
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
        guard focus?.id == token.id, token.field == .weight, NumericField.weight.range.contains(weight) else { return false }
        return commit(recover: true) { state in
            var rows = state.training!.days[token.day.rawValue]!.rows[token.exerciseID]!
            let index = rows.firstIndex { $0.id == token.rowID }!
            rows[index].canonicalWeight = weight; rows[index].weightIsDirty = false; rows[index].weight = rows[index].unit.text(for: weight)
            updateCorrection(&rows[index], exerciseID: token.exerciseID, journal: state.journal)
            state.training!.days[token.day.rawValue]!.rows[token.exerciseID] = rows; state.training!.undo = nil
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
    private func commit(recover: Bool = false, onSuccess: (() -> Void)? = nil,
                        _ update: (inout JournalSnapshot) throws -> Void) -> Bool {
        guard !backupRecoveryRequired else { errorMessage = NotebookBackupWorkflowError.recoveryRequired.localizedDescription; return false }
        var candidate = snapshot
        var recoveryCandidate = snapshot
        do {
            try update(&candidate)
            // Failed numeric writes retain raw input over the last durable journal.
            // Their pending transaction includes the matching performed-set update.
            recoveryCandidate = candidate
            try synchronizeFocusedSet(&candidate)
            _ = try candidate.validated()
        }
        catch { errorMessage = error.localizedDescription; return false }
        // A new intentional transaction supersedes an obsolete failed action.
        // Recovery itself calls persist directly and never replaces that action.
        pendingSave = nil
        pendingProfileAction = nil
        pendingProgressAction = false
        let transaction = PendingSave(snapshot: candidate, onSuccess: onSuccess)
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
            try repository.saveSnapshot(transaction.snapshot)
            lastWritten = transaction.snapshot; snapshot = transaction.snapshot
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
