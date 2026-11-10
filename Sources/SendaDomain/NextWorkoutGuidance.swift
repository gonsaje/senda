import Foundation

public enum NextWorkoutStatus: Equatable, Sendable {
    case noPlan, noHistory, needsClassification, incomplete, reviewPlan, repeatLoad, buildReps, reviewLoad
}

public enum NextWorkoutReason: Equatable, Sendable {
    case noPlan, noWorkingHistory, unclassifiedSets, incompleteWorkingSets, planChanged, extraWorkingSets
    case dropSets, mixedLoads, missingEffort, lowReserve, belowRange, moreReps, oneQualifyingSession, twoQualifyingSessions
}

public struct NextWorkoutGuidance: Equatable, Sendable {
    public let plan: ExercisePlan?
    public let status: NextWorkoutStatus
    public let reason: NextWorkoutReason
    public let referenceDay: TrainingDay?
    public let referenceWeight: Int?
    public let workingSetCount: Int
    /// Consecutive complete sessions under this plan and load, capped at two.
    public let comparableSessionCount: Int

    public init(plan: ExercisePlan?, status: NextWorkoutStatus, reason: NextWorkoutReason,
                referenceDay: TrainingDay? = nil, referenceWeight: Int? = nil,
                workingSetCount: Int = 0, comparableSessionCount: Int = 0) {
        self.plan = plan; self.status = status; self.reason = reason
        self.referenceDay = referenceDay; self.referenceWeight = referenceWeight
        self.workingSetCount = workingSetCount; self.comparableSessionCount = comparableSessionCount
    }
}

public extension JournalSnapshot {
    func nextWorkout(for exercise: Exercise, on day: TrainingDay, through today: TrainingDay,
                     calendar: Calendar = .current) -> NextWorkoutGuidance {
        guard let savedPlan = training?.days[day.rawValue]?.exercisePlans?[exercise.id],
              let plan = try? savedPlan.validated() else {
            return NextWorkoutGuidance(plan: nil, status: .noPlan, reason: .noPlan)
        }
        let sessions = nextWorkoutSessions(for: exercise.id, through: min(day, today))
        guard let latest = sessions.last else {
            return NextWorkoutGuidance(plan: plan, status: .noHistory, reason: .noWorkingHistory)
        }
        let weight = latest.commonWeight
        func result(_ status: NextWorkoutStatus, _ reason: NextWorkoutReason,
                    comparable: Int = 0) -> NextWorkoutGuidance {
            NextWorkoutGuidance(plan: plan, status: status, reason: reason,
                referenceDay: latest.day, referenceWeight: weight,
                workingSetCount: latest.workingSets.count, comparableSessionCount: comparable)
        }
        // The latest regular, working, drop or unknown day is authoritative. Do not search older days
        // for a more favorable count, plan, load or effort report.
        guard !latest.hasUnclassifiedSets else { return result(.needsClassification, .unclassifiedSets) }
        // Drop sequences remain in history, but this progression rule compares standard sets.
        guard !latest.hasDropSets else { return result(.reviewPlan, .dropSets) }
        guard latest.plan == plan else { return result(.reviewPlan, .planChanged) }
        guard latest.workingSets.count >= plan.workingSets else { return result(.incomplete, .incompleteWorkingSets) }
        guard latest.workingSets.count == plan.workingSets else { return result(.reviewPlan, .extraWorkingSets) }
        guard let weight else { return result(.reviewPlan, .mixedLoads) }

        let previous = sessions.dropLast().last
        let comparable = previous.map { $0.isComparable(to: plan, weight: weight) } == true ? 2 : 1
        guard latest.workingSets.allSatisfy({ $0.values.reps >= plan.minimumReps }) else {
            return result(.reviewPlan, .belowRange, comparable: comparable)
        }
        guard latest.workingSets.allSatisfy({ $0.repsInReserve != nil }) else {
            return result(.repeatLoad, .missingEffort, comparable: comparable)
        }
        guard latest.workingSets.allSatisfy({ ($0.repsInReserve ?? 0) >= 2 }) else {
            return result(.repeatLoad, .lowReserve, comparable: comparable)
        }
        guard latest.workingSets.allSatisfy({ $0.values.reps >= plan.maximumReps }) else {
            return result(.buildReps, .moreReps, comparable: comparable)
        }
        guard let previous, previous.isComparable(to: plan, weight: weight), previous.qualifies(for: plan) else {
            return result(.repeatLoad, .oneQualifyingSession, comparable: comparable)
        }
        return result(.reviewLoad, .twoQualifyingSessions, comparable: comparable)
    }
}

private struct NextWorkoutSet {
    let values: SetValues
    let repsInReserve: Int?
}

private struct NextWorkoutSession {
    let day: TrainingDay
    let plan: ExercisePlan?
    var workingSets: [NextWorkoutSet] = []
    var hasUnclassifiedSets = false
    var hasDropSets = false

    var commonWeight: Int? {
        guard let weight = workingSets.first?.values.weight,
              workingSets.allSatisfy({ $0.values.weight == weight }) else { return nil }
        return weight
    }
    func isComparable(to plan: ExercisePlan, weight: Int) -> Bool {
        !hasUnclassifiedSets && !hasDropSets && self.plan == plan && workingSets.count == plan.workingSets && commonWeight == weight
    }
    func qualifies(for plan: ExercisePlan) -> Bool {
        workingSets.allSatisfy { $0.values.reps >= plan.maximumReps && ($0.repsInReserve ?? 0) >= 2 }
    }
}

private extension JournalSnapshot {
    func nextWorkoutSessions(for exerciseID: String, through endDay: TrainingDay) -> [NextWorkoutSession] {
        guard let training else { return [] }
        var performed: [UUID: SetValues] = [:]
        for batch in journal.batches where batch.exerciseID == exerciseID {
            for set in batch.sets where performed[set.id] == nil { performed[set.id] = set.values }
        }
        var included = Set<UUID>()
        var sessions: [NextWorkoutSession] = []
        // Civil-day links survive timezone changes; journal values remain authoritative
        // while row text may hold a draft correction. Warmup-only days add no session.
        for key in training.days.keys.sorted() {
            guard let day = TrainingDay(rawValue: key), day <= endDay,
                  let workout = training.days[key] else { continue }
            var session = NextWorkoutSession(day: day, plan: workout.exercisePlans?[exerciseID])
            for row in workout.rows[exerciseID] ?? [] {
                guard let id = row.performedSetID, let values = performed[id], included.insert(id).inserted else { continue }
                if row.kind?.countsTowardWorkingPlan == true {
                    session.workingSets.append(NextWorkoutSet(values: values, repsInReserve: row.repsInReserve))
                } else if row.kind == .dropSet {
                    session.hasDropSets = true
                } else if row.kind == nil {
                    session.hasUnclassifiedSets = true
                }
            }
            if !session.workingSets.isEmpty || session.hasUnclassifiedSets || session.hasDropSets { sessions.append(session) }
        }
        return sessions
    }
}
