import Foundation

@MainActor
struct MemoryCreationUseCase {
    let repository: MoryMemoryRepository
    let artifactBuilder: MemoryCaptureArtifactBuilder

    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary {
        let now = Date.now
        let recordID = UUID()
        let artifactResult = artifactBuilder.buildArtifactResult(from: draft, recordID: recordID, createdAt: now)
        let captureArtifacts = artifactResult.artifacts
        let semanticDigests = artifactBuilder.buildSemanticDigests(from: artifactResult, createdAt: now)
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
        let cardArrangement = artifactBuilder.buildCardArrangement(
            from: draft,
            record: recordShell,
            artifacts: captureArtifacts,
            artifactIDByDraftID: artifactResult.artifactIDByDraftID,
            createdAt: now
        )

        try repository.upsert(recordShell: recordShell)
        try captureArtifacts.forEach { try repository.upsert(artifact: $0) }
        try semanticDigests.forEach { try repository.upsert(artifactSemanticDigest: $0) }
        try repository.upsert(memoryCardArrangement: cardArrangement)
        try repository.makeAffectSnapshots(from: draft, recordID: recordID, createdAt: now).forEach {
            try repository.upsert(affectSnapshot: $0)
        }
        try repository.upsertNotScheduledPipelineStatus(recordID: recordID, updatedAt: now)
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
