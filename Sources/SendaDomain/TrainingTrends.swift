import Foundation

public enum TrainingTrendComparison: Equatable, Sendable {
    case insufficientHistory
    case repsAtSameWeight(delta: Int, weight: Int)
    case weightAtSameReps(delta: Int, reps: Int)
    case matched
    case differentSets
}

public struct ExerciseTrendSummary: Identifiable, Equatable, Sendable {
    public var id: String { exerciseID }
    public let exerciseID: String
    public let progress: ExerciseProgress
    public let latestSession: ExerciseProgressSession
    public let previousSession: ExerciseProgressSession?
    public let comparison: TrainingTrendComparison

    public init(exerciseID: String, progress: ExerciseProgress, latestSession: ExerciseProgressSession,
                previousSession: ExerciseProgressSession?, comparison: TrainingTrendComparison) {
        self.exerciseID = exerciseID; self.progress = progress; self.latestSession = latestSession
        self.previousSession = previousSession; self.comparison = comparison
    }
}

public struct TrainingTrendBest: Identifiable, Equatable, Sendable {
    public var id: UUID { setID }
    public let exerciseID: String
    public let day: TrainingDay
    public let values: SetValues
    public let previousValues: SetValues
    public let setID: UUID

    public init(exerciseID: String, day: TrainingDay, values: SetValues, previousValues: SetValues, setID: UUID) {
        self.exerciseID = exerciseID; self.day = day; self.values = values
        self.previousValues = previousValues; self.setID = setID
    }
}

public struct TrainingTrends: Equatable, Sendable {
    public let range: ExerciseProgressRange
    public let startDay: TrainingDay
    public let endDay: TrainingDay
    public let weeks: [ExerciseProgressWeek]
    public let trainingDayCount: Int
    public let setCount: Int
    public let activeExerciseCount: Int
    public let thisWeek: ExerciseProgressWeek
    public let lastWeekComparable: ExerciseProgressWeek?
    public let exerciseSummaries: [ExerciseTrendSummary]
    public let recentBests: [TrainingTrendBest]

    public init(range: ExerciseProgressRange, startDay: TrainingDay, endDay: TrainingDay,
                weeks: [ExerciseProgressWeek], trainingDayCount: Int, setCount: Int, activeExerciseCount: Int,
                thisWeek: ExerciseProgressWeek, lastWeekComparable: ExerciseProgressWeek?,
                exerciseSummaries: [ExerciseTrendSummary], recentBests: [TrainingTrendBest]) {
        self.range = range; self.startDay = startDay; self.endDay = endDay; self.weeks = weeks
        self.trainingDayCount = trainingDayCount; self.setCount = setCount; self.activeExerciseCount = activeExerciseCount
        self.thisWeek = thisWeek; self.lastWeekComparable = lastWeekComparable
        self.exerciseSummaries = exerciseSummaries; self.recentBests = recentBests
    }
}

public extension JournalSnapshot {
    func trends(range: ExerciseProgressRange = .twelveWeeks, through today: TrainingDay,
                calendar: Calendar = .current, exercises: [Exercise] = Exercise.catalog) -> TrainingTrends {
        let window = ExerciseProgressWindow(range: range, through: today)
        let history = progressHistory(through: today, calendar: calendar)
        var library: [String: Exercise] = [:]
        for exercise in exercises { library[exercise.id] = exercise }
        for exercise in customExercises ?? [] where library[exercise.id] == nil {
            library[exercise.id] = exercise
        }

        var summaries: [ExerciseTrendSummary] = []
        var recentBests: [TrainingTrendBest] = []
        var setCountsByDay: [TrainingDay: Int] = [:]
        let earliest = TrainingDay(rawValue: "0001-01-01")!
        for exerciseID in history.byExercise.keys.sorted() {
            let setsByDay = history.sets(for: exerciseID, from: window.startDay)
            guard !setsByDay.isEmpty else { continue }
            // Retired or hidden library entries remain part of recorded training.
            let exercise = library[exerciseID] ?? Exercise(id: exerciseID, name: exerciseID,
                                                         shortName: exerciseID, startingWeight: 0)
            let progress = makeExerciseProgress(for: exercise, window: window, setsByDay: setsByDay)
            guard let latest = progress.latestSession else { continue }
            let previous = progress.sessions.dropLast().last
            summaries.append(ExerciseTrendSummary(exerciseID: exerciseID, progress: progress,
                latestSession: latest, previousSession: previous,
                comparison: trendComparison(latest: latest.bestSet.values, previous: previous?.bestSet.values)))
            for session in progress.sessions {
                setCountsByDay[session.day, default: 0] += session.setCount
            }

            // Record events use a full-history baseline, with one top set per civil
            // day. A first observation and an exact tie are never improvements.
            let allDays = history.sets(for: exerciseID, from: earliest)
            var priorBest: SetValues?
            var latestRecord: TrainingTrendBest?
            for day in allDays.keys.sorted() {
                guard let sets = allDays[day], let top = progressBestSet(in: sets, metric: .weight) else { continue }
                if let previousBest = priorBest, isStrictTrendBest(top.values, over: previousBest) {
                    if window.startDay <= day {
                        latestRecord = TrainingTrendBest(exerciseID: exerciseID, day: day, values: top.values,
                                                         previousValues: previousBest, setID: top.id)
                    }
                    priorBest = top.values
                } else if priorBest == nil {
                    priorBest = top.values
                }
            }
            if let latestRecord { recentBests.append(latestRecord) }
        }
        summaries.sort {
            $0.latestSession.day == $1.latestSession.day
                ? $0.exerciseID < $1.exerciseID : $0.latestSession.day > $1.latestSession.day
        }
        recentBests.sort { $0.day == $1.day ? $0.exerciseID < $1.exerciseID : $0.day > $1.day }
        let weeks = progressWeeks(starts: window.starts, through: today, setCountsByDay: setCountsByDay)
        let thisWeek = weeks.last!
        var lastWeekComparable: ExerciseProgressWeek?
        if let start = try? thisWeek.startDay.adding(days: -7), start < thisWeek.startDay,
           let end = try? today.adding(days: -7), end < today, start <= end {
            let days = setCountsByDay.filter { start <= $0.key && $0.key <= end }
            lastWeekComparable = ExerciseProgressWeek(startDay: start, endDay: end,
                trainingDayCount: days.count, setCount: days.values.reduce(0, +))
        }
        return TrainingTrends(range: range, startDay: window.startDay, endDay: today, weeks: weeks,
            trainingDayCount: setCountsByDay.count, setCount: setCountsByDay.values.reduce(0, +),
            activeExerciseCount: summaries.count, thisWeek: thisWeek, lastWeekComparable: lastWeekComparable,
            exerciseSummaries: summaries, recentBests: recentBests)
    }
}

private func trendComparison(latest: SetValues, previous: SetValues?) -> TrainingTrendComparison {
    guard let previous else { return .insufficientHistory }
    if latest == previous { return .matched }
    if latest.weight == previous.weight {
        return .repsAtSameWeight(delta: latest.reps - previous.reps, weight: latest.weight)
    }
    if latest.reps == previous.reps {
        return .weightAtSameReps(delta: latest.weight - previous.weight, reps: latest.reps)
    }
    return .differentSets
}

private func isStrictTrendBest(_ candidate: SetValues, over previous: SetValues) -> Bool {
    candidate.weight == previous.weight ? candidate.reps > previous.reps : candidate.weight > previous.weight
}

