import Foundation

public struct WeeklyMuscleTraining: Equatable, Sendable {
    public struct Lift: Identifiable, Equatable, Sendable {
        public let exerciseID: String
        public let count: Int
        public var id: String { exerciseID }
    }

    public struct Region: Identifiable, Equatable, Sendable {
        public let muscle: MuscleRegion
        public let count: Int
        public let dayCount: Int
        public let lifts: [Lift]
        public var id: MuscleRegion { muscle }
    }

    public let regions: [Region]
    public var counts: [MuscleRegion: Int] {
        Dictionary(regions.map { ($0.muscle, $0.count) }, uniquingKeysWith: +)
    }

    public init(regions: [Region] = []) { self.regions = regions }
}

public extension JournalSnapshot {
    /// Includes committed working and drop sets on the requested days through today.
    /// A set contributes once to each primary muscle of its exercise.
    func weeklyMuscleTraining(days: [TrainingDay], through today: TrainingDay,
                              calendar: Calendar = .current) -> WeeklyMuscleTraining {
        let elapsed = Set(days.filter { $0 <= today })
        guard !elapsed.isEmpty else { return WeeklyMuscleTraining() }

        var countsByLift: [String: [TrainingDay: Int]] = [:]
        if let training {
            let workouts = elapsed.compactMap { day in
                training.days[day.rawValue].map { (day, $0) }
            }
            guard !workouts.isEmpty else { return WeeklyMuscleTraining() }
            var performedExercise: [UUID: String] = [:]
            for batch in journal.batches {
                for set in batch.sets { performedExercise[set.id] = batch.exerciseID }
            }
            for (day, workout) in workouts {
                for (exerciseID, rows) in workout.rows {
                    let sets = TrainingSetEntry.grouping(rows).filter { entry in
                        entry.rows.contains { row in
                            guard row.kind != .warmup, let id = row.performedSetID else { return false }
                            return performedExercise[id] == exerciseID
                        }
                    }.count
                    if sets > 0 { countsByLift[exerciseID, default: [:]][day] = sets }
                }
            }
        } else {
            let history = progressHistory(through: today, calendar: calendar)
            for (exerciseID, dailySets) in history.byExercise {
                for day in elapsed {
                    if let sets = dailySets[day], !sets.isEmpty {
                        countsByLift[exerciseID, default: [:]][day] = sets.count
                    }
                }
            }
        }

        let library = Dictionary(exerciseLibrary.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var contributions: [MuscleRegion: (lifts: [WeeklyMuscleTraining.Lift], days: Set<TrainingDay>)] = [:]
        for (exerciseID, dailyCounts) in countsByLift {
            guard let map = library[exerciseID]?.muscleMap else { continue }
            let lift = WeeklyMuscleTraining.Lift(exerciseID: exerciseID, count: dailyCounts.values.reduce(0, +))
            for muscle in map.primary {
                contributions[muscle, default: ([], [])].lifts.append(lift)
                contributions[muscle, default: ([], [])].days.formUnion(dailyCounts.keys)
            }
        }
        var regions: [WeeklyMuscleTraining.Region] = []
        for (muscle, (lifts, days)) in contributions {
            let total = lifts.reduce(0) { $0 + $1.count }
            let ordered = lifts.sorted { $0.count == $1.count ? $0.exerciseID < $1.exerciseID : $0.count > $1.count }
            regions.append(WeeklyMuscleTraining.Region(muscle: muscle, count: total, dayCount: days.count, lifts: ordered))
        }
        regions.sort { $0.count == $1.count ? $0.muscle.name < $1.muscle.name : $0.count > $1.count }
        return WeeklyMuscleTraining(regions: regions)
    }
}
