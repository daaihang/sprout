import Foundation
import OSLog
import Sentry

private let captureLog = Logger(subsystem: "com.mory", category: "capture")

enum CapturePipelinePolicy: Hashable, Sendable {
    case saveOnly
    case runAfterSave
}

/// Orchestrates the capture flow by persisting the final user-confirmed snapshot.
@MainActor
struct CaptureOrchestrator {
    private let memoryRepository: any MemoryCaptureRepositorying
    private let pipelinePolicy: CapturePipelinePolicy

    init(
        memoryRepository: any MemoryCaptureRepositorying,
        pipelinePolicy: CapturePipelinePolicy = .saveOnly
    ) {
        self.memoryRepository = memoryRepository
        self.pipelinePolicy = pipelinePolicy
    }

    /// Captures a memory from the exact draft snapshot. Pipeline work is explicit.
    func capture(draft: MemoryCaptureDraft) async throws -> MemorySummary {
        let memory = try await memoryRepository.createMemory(from: draft)

        if pipelinePolicy == .runAfterSave {
            Task {
                do {
                    try await memoryRepository.refreshMemoryPipeline(recordID: memory.record.id)
                } catch {
                    captureLog.error("Pipeline trigger failed for record \(memory.record.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
                    SentrySDK.capture(error: error)
                }
            }
        }

        return memory
    }
}
