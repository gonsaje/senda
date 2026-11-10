import Foundation

public enum ExerciseProgressRange: Int, CaseIterable, Sendable {
    case eightWeeks = 8, twelveWeeks = 12
}

public enum ExerciseProgressMetric: Equatable, Sendable {
    case weight, reps
}

public struct ExerciseProgressSet: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let batchID: UUID
    public let values: SetValues
    public let position: Int
    public let recordedAt: Date
    public let dropGroupID: UUID?
    public init(id: UUID, batchID: UUID, values: SetValues, position: Int, recordedAt: Date, dropGroupID: UUID? = nil) {
        self.id = id; self.batchID = batchID; self.values = values
        self.position = position; self.recordedAt = recordedAt; self.dropGroupID = dropGroupID
    }
}

public struct ExerciseProgressSession: Identifiable, Equatable, Sendable {
    public var id: String { day.rawValue }
    public let day: TrainingDay
    public let exerciseID: String
    public let sets: [ExerciseProgressSet]
    public let bestSet: ExerciseProgressSet
    public var setCount: Int { Set(sets.map { $0.dropGroupID ?? $0.id }).count }
    public init(day: TrainingDay, exerciseID: String, sets: [ExerciseProgressSet], bestSet: ExerciseProgressSet) {
        self.day = day; self.exerciseID = exerciseID; self.sets = sets; self.bestSet = bestSet
    }
}

public struct ExerciseProgressWeek: Identifiable, Equatable, Sendable {
    public var id: String { startDay.rawValue }
    public let startDay: TrainingDay
    public let endDay: TrainingDay
    public let trainingDayCount: Int
    public let setCount: Int
    public init(startDay: TrainingDay, endDay: TrainingDay, trainingDayCount: Int, setCount: Int) {
        self.startDay = startDay; self.endDay = endDay
        self.trainingDayCount = trainingDayCount; self.setCount = setCount
    }
}

public struct ExerciseProgress: Equatable, Sendable {
    public let exerciseID: String
    public let range: ExerciseProgressRange
    public let startDay: TrainingDay
    public let endDay: TrainingDay
    public let metric: ExerciseProgressMetric
    public let sessions: [ExerciseProgressSession]
    public let weeks: [ExerciseProgressWeek]
    public let setCount: Int
    public let trainingDayCount: Int
    public let latestSession: ExerciseProgressSession?
    public let bestSet: ExerciseProgressSet?
    public init(exerciseID: String, range: ExerciseProgressRange, startDay: TrainingDay, endDay: TrainingDay,
                metric: ExerciseProgressMetric, sessions: [ExerciseProgressSession], weeks: [ExerciseProgressWeek],
                setCount: Int, trainingDayCount: Int, latestSession: ExerciseProgressSession?, bestSet: ExerciseProgressSet?) {
        self.exerciseID = exerciseID; self.range = range; self.startDay = startDay; self.endDay = endDay
        self.metric = metric; self.sessions = sessions; self.weeks = weeks; self.setCount = setCount
        self.trainingDayCount = trainingDayCount; self.latestSession = latestSession; self.bestSet = bestSet
    }
}

public extension JournalSnapshot {
    /// Every saved training day, independent of the recent chart window. Future-dated
    /// entries remain inspectable because they are explicit notebook records.
    func recordedSessions(for exercise: Exercise, calendar: Calendar = .current) -> [ExerciseProgressSession] {
        let history = progressHistory(through: TrainingDay(rawValue: "9999-12-31")!, calendar: calendar, exerciseID: exercise.id)
        let sets = history.sets(for: exercise.id, from: TrainingDay(rawValue: "0001-01-01")!)
        return progressSessions(for: exercise.id, setsByDay: sets, metric: .weight)
    }

    func progress(for exercise: Exercise, range: ExerciseProgressRange = .twelveWeeks,
                  through today: TrainingDay, calendar: Calendar = .current) -> ExerciseProgress {
        let window = ExerciseProgressWindow(range: range, through: today)
        let history = progressHistory(through: today, calendar: calendar, exerciseID: exercise.id)
        return makeExerciseProgress(for: exercise, window: window,
                                    setsByDay: history.sets(for: exercise.id, from: window.startDay))
    }
}

/// Shared civil-date bounds for the per-exercise and overall views.
struct ExerciseProgressWindow {
    let range: ExerciseProgressRange
    let today: TrainingDay
    let starts: [TrainingDay]
    var startDay: TrainingDay { starts.first ?? today }

    init(range: ExerciseProgressRange, through today: TrainingDay) {
        self.range = range
        self.today = today
        var dayCalendar = Calendar(identifier: .gregorian)
        dayCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let weekday = dayCalendar.component(.weekday, from: today.date(in: dayCalendar))
        let earliest = TrainingDay(rawValue: "0001-01-01")!
        let precedingMonday = try? today.adding(days: -(weekday == 1 ? 6 : weekday - 2))
        let currentMonday = precedingMonday.flatMap { $0 <= today ? $0 : nil } ?? earliest
        // TrainingDay keys have no BCE era. Reject a subtraction that wraps past year 1,
        // retaining the representable part of that oldest partial week instead.
        var starts: [TrainingDay] = (0..<range.rawValue).reversed().compactMap {
            guard let start = try? currentMonday.adding(days: -7 * $0), start <= currentMonday else { return nil }
            return start
        }
        if starts.count < range.rawValue, let first = starts.first, earliest < first {
            starts.insert(earliest, at: 0)
        }
        self.starts = starts
    }
}

/// Resolved journal values retain every saved link so duplicate IDs can be removed
/// after selecting a window, just as the original per-exercise query did.
struct ExerciseProgressHistory {
    var byExercise: [String: [TrainingDay: [ExerciseProgressSet]]] = [:]
    let usesSavedRows: Bool

    func sets(for exerciseID: String, from startDay: TrainingDay) -> [TrainingDay: [ExerciseProgressSet]] {
        var setsByDay: [TrainingDay: [ExerciseProgressSet]] = [:]
        var included = Set<UUID>()
        let source = byExercise[exerciseID] ?? [:]
        for day in source.keys.sorted() where startDay <= day {
            for set in source[day] ?? [] {
                guard !usesSavedRows || included.insert(set.id).inserted else { continue }
                setsByDay[day, default: []].append(set)
            }
        }
        return setsByDay
    }
}

extension JournalSnapshot {
    func progressHistory(through today: TrainingDay, calendar: Calendar,
                         exerciseID: String? = nil) -> ExerciseProgressHistory {
        let batches = journal.batches.enumerated().filter { exerciseID == nil || $0.element.exerciseID == exerciseID }
        var history = ExerciseProgressHistory(usesSavedRows: training != nil)
        if let training {
            // A saved row's civil day and position survive later timezone and unit changes.
            // Only journal values are recorded; a row can contain an unfinished correction.
            var performed: [UUID: (exerciseID: String, set: ExerciseProgressSet)] = [:]
            for (_, batch) in batches {
                for set in batch.sets {
                    performed[set.id] = (batch.exerciseID, ExerciseProgressSet(
                        id: set.id, batchID: batch.id, values: set.values,
                        position: set.position, recordedAt: batch.recordedAt))
                }
            }
            for key in training.days.keys.sorted() {
                guard let day = TrainingDay(rawValue: key), day <= today,
                      let workout = training.days[key] else { continue }
                for rowExerciseID in workout.rows.keys.sorted() {
                    guard exerciseID == nil || rowExerciseID == exerciseID else { continue }
                    for (index, row) in (workout.rows[rowExerciseID] ?? []).enumerated() {
                        guard let id = row.performedSetID, let source = performed[id],
                              source.exerciseID == rowExerciseID else { continue }
                        history.byExercise[rowExerciseID, default: [:]][day, default: []].append(ExerciseProgressSet(
                            id: source.set.id, batchID: source.set.batchID, values: source.set.values,
                            position: index + 1, recordedAt: source.set.recordedAt, dropGroupID: row.dropGroupID))
                    }
                }
            }
        } else {
            // Pre-notebook snapshots have no saved day links. Preserve chronological batch
            // insertion order for equal timestamps, then the performed order within a batch.
            let supportedDates: ClosedRange<TimeInterval> = -62_135_596_800...253_402_300_799
            var legacyCalendar = Calendar(identifier: .gregorian)
            legacyCalendar.timeZone = calendar.timeZone
            let chronological = batches.filter {
                let interval = $0.element.recordedAt.timeIntervalSince1970
                return interval.isFinite && supportedDates.contains(interval)
            }.sorted {
                if $0.element.recordedAt == $1.element.recordedAt { return $0.offset < $1.offset }
                return $0.element.recordedAt < $1.element.recordedAt
            }
            for (_, batch) in chronological {
                let components = legacyCalendar.dateComponents([.era, .year], from: batch.recordedAt)
                guard components.era == 1, let year = components.year, (1...9999).contains(year) else { continue }
                let day = TrainingDay(batch.recordedAt, calendar: calendar)
                guard day <= today else { continue }
                for set in batch.sets.sorted(by: { $0.position < $1.position }) {
                    let position = (history.byExercise[batch.exerciseID]?[day]?.count ?? 0) + 1
                    history.byExercise[batch.exerciseID, default: [:]][day, default: []].append(ExerciseProgressSet(
                        id: set.id, batchID: batch.id, values: set.values,
                        position: position, recordedAt: batch.recordedAt))
                }
            }
        }
        return history
    }
}

func makeExerciseProgress(for exercise: Exercise, window: ExerciseProgressWindow,
                          setsByDay: [TrainingDay: [ExerciseProgressSet]]) -> ExerciseProgress {
    let metric: ExerciseProgressMetric = !exercise.requiresWeight
        && setsByDay.values.allSatisfy({ $0.allSatisfy { $0.values.weight == 0 } }) ? .reps : .weight
    let sessions = progressSessions(for: exercise.id, setsByDay: setsByDay, metric: metric)
    let weeks = progressWeeks(starts: window.starts, through: window.today,
                              setCountsByDay: setsByDay.mapValues { Set($0.map { $0.dropGroupID ?? $0.id }).count })
    return ExerciseProgress(exerciseID: exercise.id, range: window.range, startDay: window.startDay,
                            endDay: window.today, metric: metric, sessions: sessions, weeks: weeks,
                            setCount: weeks.reduce(0) { $0 + $1.setCount }, trainingDayCount: sessions.count,
                            latestSession: sessions.last,
                            bestSet: progressBestSet(in: sessions.map(\.bestSet), metric: metric))
}

private func progressSessions(for exerciseID: String, setsByDay: [TrainingDay: [ExerciseProgressSet]],
                              metric: ExerciseProgressMetric) -> [ExerciseProgressSession] {
    setsByDay.keys.sorted().compactMap { day in
        guard let sets = setsByDay[day], let best = progressBestSet(in: sets, metric: metric) else { return nil }
        return ExerciseProgressSession(day: day, exerciseID: exerciseID, sets: sets, bestSet: best)
    }
}

func progressWeeks(starts: [TrainingDay], through today: TrainingDay,
                   setCountsByDay: [TrainingDay: Int]) -> [ExerciseProgressWeek] {
    var weeklyDays = Array(repeating: 0, count: starts.count)
    var weeklySets = Array(repeating: 0, count: starts.count)
    var weekIndex = 0
    for day in setCountsByDay.keys.sorted() {
        guard let count = setCountsByDay[day], count > 0 else { continue }
        while weekIndex + 1 < starts.count, starts[weekIndex + 1] <= day { weekIndex += 1 }
        weeklyDays[weekIndex] += 1
        weeklySets[weekIndex] += count
    }
    return starts.enumerated().map { index, start in
        let end = index + 1 < starts.count
            ? (try? starts[index + 1].adding(days: -1)) ?? today
            : (try? start.adding(days: 6)) ?? today
        return ExerciseProgressWeek(startDay: start, endDay: min(end, today),
                                    trainingDayCount: weeklyDays[index], setCount: weeklySets[index])
    }
}

func progressBestSet(in sets: [ExerciseProgressSet], metric: ExerciseProgressMetric) -> ExerciseProgressSet? {
    sets.reduce(nil) { best, candidate in
        guard let best else { return candidate }
        if metric == .weight, best.values.weight != candidate.values.weight {
            return best.values.weight > candidate.values.weight ? best : candidate
        }
        // The later row/session wins an exact tie, keeping the reference deterministic.
        return best.values.reps > candidate.values.reps ? best : candidate
    }
}
