import Foundation

extension MoryMemoryRepository {
    func fetchBackgroundOperationRuns(
        status: BackgroundOperationStatus?,
        limit: Int?
    ) throws -> [BackgroundOperationRun] {
        try backgroundOperationStore.fetchRuns(status: status, limit: limit)
    }

    func fetchBackgroundOperationEvents(
        runID: UUID?,
        limit: Int?
    ) throws -> [BackgroundOperationEvent] {
        try backgroundOperationStore.fetchEvents(runID: runID, limit: limit)
    }

    func upsertBackgroundOperationRun(_ run: BackgroundOperationRun) throws {
        try backgroundOperationStore.upsertRun(run)
    }

    func upsertBackgroundOperationEvent(_ event: BackgroundOperationEvent) throws {
        try backgroundOperationStore.upsertEvent(event)
    }
}
