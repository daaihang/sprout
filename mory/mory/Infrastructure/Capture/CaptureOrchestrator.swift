import Foundation
import OSLog
import Sentry

private let captureLog = Logger(subsystem: "com.mory", category: "capture")

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
            do {
                try await memoryRepository.refreshMemoryPipeline(recordID: memory.record.id)
            } catch {
                captureLog.error("Pipeline trigger failed for record \(memory.record.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
                SentrySDK.capture(error: error)
            }
        }

        return memory
    }
}
