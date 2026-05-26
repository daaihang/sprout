import Foundation

@MainActor
struct MemoryCreationUseCase {
    let repository: MoryMemoryRepository
    let artifactBuilder: MemoryCaptureArtifactBuilder

    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary {
        let now = Date.now
        let recordID = UUID()
        let captureArtifacts = artifactBuilder.buildArtifacts(from: draft, recordID: recordID, createdAt: now)
        let normalizedText = artifactBuilder.resolvedRecordRawText(from: draft, artifacts: captureArtifacts)

        let recordShell = RecordShell(
            id: recordID,
            createdAt: now,
            updatedAt: now,
            captureSource: draft.provenance.derivedCaptureSource,
            rawText: normalizedText,
            userMood: draft.mood?.trimmedOrNil,
            userIntensity: nil,
            inputContext: draft.inputContext?.trimmedOrNil,
            artifactIDs: captureArtifacts.map(\.id),
            captureProvenance: draft.provenance,
            debugFixtureSeededAt: draft.inputContext?.hasPrefix("debug fixture seed") == true ? now : nil
        )

        try repository.upsert(recordShell: recordShell)
        try captureArtifacts.forEach { try repository.upsert(artifact: $0) }
        try repository.makeAffectSnapshots(from: draft, recordID: recordID, createdAt: now).forEach {
            try repository.upsert(affectSnapshot: $0)
        }
        try repository.upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .pending,
                requestID: nil,
                lastError: nil,
                requestBody: nil,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: nil,
                failedStage: nil,
                lastAttemptAt: nil,
                completedAt: nil,
                updatedAt: now
            )
        )
        try repository.save()

        let summary = repository.makeMemorySummary(
            record: recordShell,
            artifacts: captureArtifacts,
            pipelineStatus: try repository.fetchPipelineStatus(recordID: recordID)
        )
        await repository.indexMemoryIfPossible(summary)
        return summary
    }
}
