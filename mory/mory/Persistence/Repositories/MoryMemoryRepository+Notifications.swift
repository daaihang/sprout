import Foundation
import SwiftData

extension MoryMemoryRepository {
    // MARK: - Notifications & External Capture

    func fetchNotificationIntents(status: NotificationIntentStatus?, limit: Int?) throws -> [NotificationIntent] {
        let stores = try modelContext.fetch(
            FetchDescriptor<NotificationIntentStore>(
                sortBy: [
                    SortDescriptor(\.scheduledAt, order: .forward),
                    SortDescriptor(\.createdAt, order: .reverse),
                ]
            )
        )
        let intents = stores
            .map(\.domainModel)
            .filter { intent in
                guard let status else { return true }
                return intent.status == status
            }
        return applyLimit(limit, to: intents)
    }

    func upsertNotificationIntent(_ intent: NotificationIntent) throws {
        try upsert(notificationIntent: intent)
        try save()
    }

    func enqueueExternalCapture(_ request: ExternalCaptureRequest, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        let item = try ExternalCaptureInboxCodec().makeItem(from: request, now: receivedAt)
        try externalCaptureInboxStore.upsert(item)
        return item
    }

    func enqueueJournalingSuggestion(_ suggestion: JournalingSuggestionDraft, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        let item = try ExternalCaptureInboxCodec().makeItem(from: suggestion, now: receivedAt)
        try externalCaptureInboxStore.upsert(item)
        return item
    }

    func fetchExternalCaptureInbox(status: ExternalCaptureInboxStatus?, limit: Int?) throws -> [ExternalCaptureInboxItem] {
        try externalCaptureInboxStore.fetch(status: status, limit: limit)
    }

    func dismissExternalCaptureInboxItem(_ id: UUID) throws {
        guard var item = try externalCaptureInboxStore.fetch(id: id) else {
            throw CocoaError(.fileNoSuchFile)
        }
        item.status = .dismissed
        item.dismissedAt = .now
        item.updatedAt = .now
        try externalCaptureInboxStore.upsert(item)
    }

    func markExternalCaptureInboxItemImported(_ id: UUID, recordID: UUID) throws {
        guard var item = try externalCaptureInboxStore.fetch(id: id) else {
            throw CocoaError(.fileNoSuchFile)
        }
        item.status = .imported
        item.importedRecordID = recordID
        item.updatedAt = .now
        try externalCaptureInboxStore.upsert(item)
    }

    func createMemoryFromExternalCaptureInboxItem(_ id: UUID) async throws -> MemorySummary {
        guard let item = try externalCaptureInboxStore.fetch(id: id) else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard item.status == .pending else {
            throw ExternalCaptureInboxError.itemIsNotPending
        }

        let draft = try ExternalCaptureInboxCodec().makeDraft(from: item)
        let memory = try await createMemory(from: draft)

        try markExternalCaptureInboxItemImported(item.id, recordID: memory.record.id)
        return memory
    }

}
