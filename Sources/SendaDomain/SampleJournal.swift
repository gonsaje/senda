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
