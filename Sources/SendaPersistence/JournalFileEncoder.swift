import Foundation
import SendaDomain

/// Assemble the existing JSON format from encoded values. A numeric edit changes one day
/// and usually one recorded batch. Keep the other encodings for the next atomic write.
struct JournalFileEncoder {
    private var batches = EncodedArray<RecordedBatch>()
    private var receipts = EncodedArray<ActionReceipt>()
    private var days: [String: EncodedDay] = [:]
    private let encoder = JSONEncoder()

    private struct EncodedDay {
        let workout: DayWorkout
        let key: Data
        let value: Data
    }

    mutating func encode<Header: Encodable>(_ header: Header, journal: Journal,
                                            training: TrainingWorkspace?) throws -> Data {
        var file = JSONObject(header: try encoder.encode(header))
        var history = JSONObject()
        history.add(key: Data(#""batches""#.utf8), value: try batches.encode(journal.batches, with: encoder))
        history.add(key: Data(#""receipts""#.utf8), value: try receipts.encode(journal.receipts, with: encoder))
        file.add(key: Data(#""journal""#.utf8), value: history.finish())
        if let training {
            var workspace = JSONObject(header: try encoder.encode(training.storageHeader))
            workspace.add(key: Data(#""days""#.utf8), value: try encodeDays(training.days))
            file.add(key: Data(#""training""#.utf8), value: workspace.finish())
        } else {
            days.removeAll()
        }
        return file.finish()
    }

    private mutating func encodeDays(_ workouts: [String: DayWorkout]) throws -> Data {
        var updated: [String: EncodedDay] = [:]
        var object = JSONObject()
        for day in workouts.keys.sorted() {
            let workout = workouts[day]!
            let entry: EncodedDay
            if let cached = days[day], cached.workout == workout {
                entry = cached
            } else {
                entry = try EncodedDay(workout: workout, key: encoder.encode(day), value: encoder.encode(workout))
            }
            updated[day] = entry
            object.add(key: entry.key, value: entry.value)
        }
        days = updated
        return object.finish()
    }
}

private struct EncodedArray<Element: Encodable & Equatable> {
    private var previous: [Element] = []
    private var chunks: [Data] = []

    mutating func encode(_ values: [Element], with encoder: JSONEncoder) throws -> Data {
        let chunkSize = 64
        var updated: [Data] = []
        var result = Data([0x5b]) // [
        for start in stride(from: 0, to: values.count, by: chunkSize) {
            let end = min(start + chunkSize, values.count)
            let indices = start..<end
            let chunk: Data
            if start < previous.count, end == min(start + chunkSize, previous.count),
               values[indices].elementsEqual(previous[indices]) {
                chunk = chunks[start / chunkSize]
            } else {
                // The encoder supplies a standalone array. Only its outer brackets are omitted.
                chunk = try Data(encoder.encode(Array(values[indices])).dropFirst().dropLast())
            }
            if start > 0 { result.append(0x2c) }
            result.append(chunk)
            updated.append(chunk)
        }
        result.append(0x5d) // ]
        previous = values
        chunks = updated
        return result
    }
}

/// Keys, values and the optional object header have already been encoded by JSONEncoder.
/// Only JSON structural punctuation is written here.
private struct JSONObject {
    private var bytes: Data

    init(header: Data = Data("{}".utf8)) {
        bytes = header
        bytes.removeLast() // Closing brace of the encoded object.
    }

    mutating func add(key: Data, value: Data) {
        if bytes.count > 1 { bytes.append(0x2c) }
        bytes.append(key)
        bytes.append(0x3a)
        bytes.append(value)
    }

    mutating func finish() -> Data {
        bytes.append(0x7d)
        return bytes
    }
}
