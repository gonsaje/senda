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
