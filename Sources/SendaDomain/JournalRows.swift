import Foundation

public struct TrainingSetReference: Equatable, Sendable {
    public let batch: RecordedBatch
    public let set: PerformedSet
}
public struct RemovedTrainingSet: Codable, Equatable, Sendable {
    public let batch: RecordedBatch
    public let set: PerformedSet
    public let batchIndex: Int
}
public extension Journal {
    func reference(to id: UUID) -> TrainingSetReference? {
        for batch in batches {
            if let set = batch.sets.first(where: { $0.id == id }) { return TrainingSetReference(batch: batch, set: set) }
        }
        return nil
    }
}
