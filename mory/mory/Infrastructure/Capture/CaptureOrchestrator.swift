import Foundation

/// Orchestrates the capture flow: collects context, enriches draft, persists, and triggers pipeline.
@MainActor
struct CaptureOrchestrator {
    private let memoryRepository: any MoryMemoryRepositorying
    private let contextCollector: ContextAutoCollecting

    init(
        memoryRepository: any MoryMemoryRepositorying,
        contextCollector: ContextAutoCollecting? = nil
    ) {
        self.memoryRepository = memoryRepository
        self.contextCollector = contextCollector ?? ContextAutoCollector()
    }

    /// Captures a memory immediately, then enriches it with automatic context before analysis.
    func capture(draft: MemoryCaptureDraft) async throws -> MemorySummary {
        let memory = try await memoryRepository.createMemory(from: draft)

        Task {
            let contextDrafts = await contextCollector.collectContextDrafts()
            if !contextDrafts.isEmpty {
                _ = try? await memoryRepository.appendArtifacts(recordID: memory.record.id, drafts: contextDrafts)
            }
            try? await memoryRepository.refreshMemoryPipeline(recordID: memory.record.id)
        }

        return memory
    }
}
