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
        try ExternalCaptureImportUseCase(repository: self).enqueueExternalCapture(request, receivedAt: receivedAt)
    }

    func enqueueJournalingSuggestion(_ suggestion: JournalingSuggestionDraft, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        try ExternalCaptureImportUseCase(repository: self).enqueueJournalingSuggestion(suggestion, receivedAt: receivedAt)
    }

    func fetchExternalCaptureInbox(status: ExternalCaptureInboxStatus?, limit: Int?) throws -> [ExternalCaptureInboxItem] {
        try ExternalCaptureImportUseCase(repository: self).fetchExternalCaptureInbox(status: status, limit: limit)
    }

    func dismissExternalCaptureInboxItem(_ id: UUID) throws {
        try ExternalCaptureImportUseCase(repository: self).dismissExternalCaptureInboxItem(id)
    }

    func markExternalCaptureInboxItemImported(_ id: UUID, recordID: UUID) throws {
        try ExternalCaptureImportUseCase(repository: self).markExternalCaptureInboxItemImported(id, recordID: recordID)
    }

    func createMemoryFromExternalCaptureInboxItem(_ id: UUID) async throws -> MemorySummary {
        try await ExternalCaptureImportUseCase(repository: self).createMemoryFromExternalCaptureInboxItem(id)
    }

}
