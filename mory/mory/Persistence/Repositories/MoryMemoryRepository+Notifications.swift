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

    func fetchNotificationManagementEvents(
        kind: NotificationManagementEventKind?,
        limit: Int?
    ) throws -> [NotificationManagementEvent] {
        let stores = try modelContext.fetch(
            FetchDescriptor<NotificationManagementEventStore>(
                sortBy: [
                    SortDescriptor(\.createdAt, order: .reverse),
                ]
            )
        )
        let events = stores
            .map(\.domainModel)
            .filter { event in
                guard let kind else { return true }
                return event.eventKind == kind
            }
        return applyLimit(limit, to: events)
    }

    func upsertNotificationManagementEvent(_ event: NotificationManagementEvent) throws {
        let descriptor = FetchDescriptor<NotificationManagementEventStore>(
            predicate: #Predicate { $0.id == event.id }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.eventKindRawValue = event.eventKind.rawValue
            existing.intentID = event.intentID
            existing.dedupeKey = event.dedupeKey
            existing.triggerRawValue = event.trigger?.rawValue
            existing.kindRawValue = event.kind?.rawValue
            existing.targetTypeRawValue = event.targetType?.rawValue
            existing.targetID = event.targetID
            existing.message = event.message
            existing.createdAt = event.createdAt
        } else {
            modelContext.insert(NotificationManagementEventStore(domainModel: event))
        }
        try save()
    }

    func enqueueExternalCapture(_ request: ExternalCaptureRequest, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        try externalCaptureImportUseCase.enqueueExternalCapture(request, receivedAt: receivedAt)
    }

    func enqueueJournalingSuggestion(_ suggestion: JournalingSuggestionDraft, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        try externalCaptureImportUseCase.enqueueJournalingSuggestion(suggestion, receivedAt: receivedAt)
    }

    func fetchExternalCaptureInbox(status: ExternalCaptureInboxStatus?, limit: Int?) throws -> [ExternalCaptureInboxItem] {
        try externalCaptureImportUseCase.fetchExternalCaptureInbox(status: status, limit: limit)
    }

    func dismissExternalCaptureInboxItem(_ id: UUID) throws {
        try externalCaptureImportUseCase.dismissExternalCaptureInboxItem(id)
    }

    func markExternalCaptureInboxItemImported(_ id: UUID, recordID: UUID) throws {
        try externalCaptureImportUseCase.markExternalCaptureInboxItemImported(id, recordID: recordID)
    }

    func createMemoryFromExternalCaptureInboxItem(_ id: UUID) async throws -> MemorySummary {
        try await externalCaptureImportUseCase.createMemoryFromExternalCaptureInboxItem(id)
    }

    private var externalCaptureImportUseCase: ExternalCaptureImportUseCase {
        ExternalCaptureImportUseCase(
            repository: self,
            artifactBuilder: captureArtifactBuilder
        )
    }
}
