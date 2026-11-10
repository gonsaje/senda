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
public struct RemovedTrainingBatch: Codable, Equatable, Sendable {
    public let batch: RecordedBatch
    public let batchIndex: Int
    public let removedSetIDs: [UUID]
    public init(batch: RecordedBatch, batchIndex: Int, removedSetIDs: [UUID]) {
        self.batch = batch; self.batchIndex = batchIndex; self.removedSetIDs = removedSetIDs
    }
}
public struct RemovedTrainingSets: Codable, Equatable, Sendable {
    public let batches: [RemovedTrainingBatch]
    public init(batches: [RemovedTrainingBatch]) { self.batches = batches }
}
public extension Journal {
    func reference(to id: UUID) -> TrainingSetReference? {
        for batch in batches {
            if let set = batch.sets.first(where: { $0.id == id }) { return TrainingSetReference(batch: batch, set: set) }
        }
        return nil
    }
}
