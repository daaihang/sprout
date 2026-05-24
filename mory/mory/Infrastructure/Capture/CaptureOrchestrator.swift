import Foundation

/// Orchestrates the capture flow: persists the final snapshot and triggers pipeline.
@MainActor
struct CaptureOrchestrator {
    private let memoryRepository: any MemoryCaptureRepositorying

    init(
        memoryRepository: any MemoryCaptureRepositorying
    ) {
        self.memoryRepository = memoryRepository
    }

    /// Captures a memory from the exact draft snapshot, then runs analysis once.
    func capture(draft: MemoryCaptureDraft) async throws -> MemorySummary {
        let memory = try await memoryRepository.createMemory(from: draft)

        Task {
            try? await memoryRepository.refreshMemoryPipeline(recordID: memory.record.id)
        }

        return memory
    }
}
