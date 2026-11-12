import Foundation

public enum SampleJournal {
    public static func make(relativeTo date: Date = Date()) throws -> Journal {
        var journal = Journal()
        for (id, days, weight, reps, count) in [
            ("squat", -6, 18_500, 8, 3),
            ("deadlift", -5, 22_500, 5, 3),
            ("bench", -3, 13_500, 10, 4)
        ] {
            let performed = Calendar.current.date(byAdding: .day, value: days, to: date)
                ?? date.addingTimeInterval(Double(days) * 86_400)
            _ = try journal.record(DraftBatch(exerciseID: id,
                sets: Array(repeating: SetValues(weight: weight, reps: reps), count: count)), at: performed)
        }
        return journal
    }
}

public extension SampleJournal {
    static func makeWeek(relativeTo date: Date = Date(), calendar: Calendar = .current) throws -> Journal {
        let today = TrainingDay(date, calendar: calendar)
        let week = try today.week()
        var journal = Journal()
        for (index, id, weight, reps, count) in [
            (0, "bench", 13_500, 10, 4), (0, "overhead-press", 6_500, 8, 4),
            (2, "deadlift", 22_500, 5, 3), (2, "cable-row", 9_000, 10, 4),
            (4, "squat", 18_500, 8, 3), (4, "calf-raise", 9_000, 12, 3)
        ] where week[index] < today {
            _ = try journal.record(DraftBatch(exerciseID: id, sets: Array(repeating: SetValues(weight: weight, reps: reps), count: count)), at: week[index].date(in: calendar))
        }
        if journal.entries(for: "bench").isEmpty {
            _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10)]), at: today.adding(days: -3).date(in: calendar))
        }
        _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13_500, reps: 10), SetValues(weight: 13_500, reps: 10), SetValues(weight: 14_500, reps: 8), SetValues(weight: 14_500, reps: 8)]), at: date)
        return journal
    }
}

public extension SampleJournal {
    /// Eleven complete weeks plus the current sample week, all held in memory by the sample app.
    static func makeTwelveWeeks(relativeTo date: Date = Date(), calendar: Calendar = .current) throws -> Journal {
        var journal = try makeWeek(relativeTo: date, calendar: calendar)
        let monday = try TrainingDay(date, calendar: calendar).week()[0]
        // Loads are hundredths of a pound. Plateaus and two lighter weeks break up the progression.
        let sessions: [(day: Int, id: String, loads: [Int], reps: Int, sets: Int)] = [
            (0, "bench", [115, 115, 120, 120, 105, 125, 125, 130, 115, 135, 135], 8, 4),
            (0, "overhead-press", [45, 45, 50, 50, 40, 55, 55, 60, 50, 60, 65], 8, 3),
            (2, "deadlift", [185, 190, 195, 195, 170, 200, 205, 210, 185, 215, 220], 5, 3),
            (2, "cable-row", [70, 70, 75, 75, 65, 80, 80, 85, 75, 85, 90], 10, 3),
            (4, "squat", [145, 150, 155, 155, 135, 160, 165, 170, 150, 175, 180], 8, 3),
            (4, "calf-raise", [70, 70, 75, 75, 65, 80, 80, 85, 75, 85, 90], 12, 3)
        ]
        for week in 0..<11 {
            let start = try monday.adding(days: (week - 11) * 7)
            let lighterWeek = week == 4 || week == 8
            for session in sessions {
                // A missed midweek or Friday workout leaves a visible, plausible gap.
                if (week == 2 && session.day == 2) || (week == 7 && session.day == 4) { continue }
                let day = try start.adding(days: session.day)
                let topWeight = session.loads[week] * 100
                let topReps = session.reps + (week % 3 == 1 ? 1 : 0)
                let count = lighterWeek ? 2 : session.sets
                let sets = (0..<count).map { index in
                    SetValues(weight: index == 0 ? topWeight : topWeight - 500,
                              reps: topReps - (index == count - 1 ? 1 : 0))
                }
                _ = try journal.record(DraftBatch(exerciseID: session.id, sets: sets),
                                       at: day.date(in: calendar))
            }
        }
        return journal
    }
}
