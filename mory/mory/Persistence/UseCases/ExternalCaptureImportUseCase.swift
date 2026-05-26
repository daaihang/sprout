import Foundation

@MainActor
struct ExternalCaptureImportUseCase {
    let repository: MoryMemoryRepository
    let artifactBuilder: MemoryCaptureArtifactBuilder

    func enqueueExternalCapture(_ request: ExternalCaptureRequest, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        let item = try ExternalCaptureInboxCodec().makeItem(from: request, now: receivedAt)
        try repository.externalCaptureInboxStore.upsert(item)
        return item
    }

    func enqueueJournalingSuggestion(_ suggestion: JournalingSuggestionDraft, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        let item = try ExternalCaptureInboxCodec().makeItem(from: suggestion, now: receivedAt)
        try repository.externalCaptureInboxStore.upsert(item)
        return item
    }

    func fetchExternalCaptureInbox(status: ExternalCaptureInboxStatus?, limit: Int?) throws -> [ExternalCaptureInboxItem] {
        try repository.externalCaptureInboxStore.fetch(status: status, limit: limit)
    }

    func dismissExternalCaptureInboxItem(_ id: UUID) throws {
        guard var item = try repository.externalCaptureInboxStore.fetch(id: id) else {
            throw CocoaError(.fileNoSuchFile)
        }
        item.status = .dismissed
        item.dismissedAt = .now
        item.updatedAt = .now
        try repository.externalCaptureInboxStore.upsert(item)
    }

    func markExternalCaptureInboxItemImported(_ id: UUID, recordID: UUID) throws {
        guard var item = try repository.externalCaptureInboxStore.fetch(id: id) else {
            throw CocoaError(.fileNoSuchFile)
        }
        item.status = .imported
        item.importedRecordID = recordID
        item.updatedAt = .now
        try repository.externalCaptureInboxStore.upsert(item)
    }

    func createMemoryFromExternalCaptureInboxItem(_ id: UUID) async throws -> MemorySummary {
        guard let item = try repository.externalCaptureInboxStore.fetch(id: id) else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard item.status == .pending else {
            throw ExternalCaptureInboxError.itemIsNotPending
        }

        let draft = try ExternalCaptureInboxCodec().makeDraft(from: item)
        let memory = try await MemoryCreationUseCase(
            repository: repository,
            artifactBuilder: artifactBuilder
        ).createMemory(from: draft)

        try markExternalCaptureInboxItemImported(item.id, recordID: memory.record.id)
        return memory
    }
}
