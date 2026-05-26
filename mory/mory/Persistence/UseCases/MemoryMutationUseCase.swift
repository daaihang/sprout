import Foundation
import SwiftData

@MainActor
struct MemoryMutationUseCase {
    let repository: MoryMemoryRepository

    func applyMemoryMutation(
        recordID: UUID,
        mutation: MemoryMutationDraft,
        refreshPolicy: MemoryMutationRefreshPolicy
    ) async throws -> MemoryMutationResult {
        let mutationID = UUID()
        guard mutation.hasChanges else {
            let detail = try repository.fetchMemoryDetail(recordID: recordID)
            let pipelineStatus = if let detail {
                detail.pipelineStatus
            } else {
                try repository.fetchPipelineStatus(recordID: recordID)
            }
            return MemoryMutationResult(
                mutationID: mutationID,
                detail: detail,
                addedArtifactIDs: [],
                updatedArtifactIDs: [],
                deletedArtifactIDs: [],
                reorderedArtifactIDs: [],
                invalidatedDerivedData: false,
                pipelineStatus: pipelineStatus
            )
        }

        guard let recordStore = try repository.modelContext.fetch(
            FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let now = Date.now
        var updatedRecord = recordStore.domainModel
        let existingArtifactIDs = Set(updatedRecord.artifactIDs)
        let deletedArtifactIDs = repository.orderedUniqueUUIDs(mutation.deletedArtifactIDs)

        switch mutation.recordPatch.rawText {
        case .unchanged:
            break
        case let .set(rawText):
            updatedRecord.rawText = rawText?.trimmedOrNil ?? updatedRecord.rawText
        }

        switch mutation.recordPatch.userMood {
        case .unchanged:
            break
        case let .set(userMood):
            updatedRecord.userMood = userMood?.trimmedOrNil
        }

        switch mutation.recordPatch.inputContext {
        case .unchanged:
            break
        case let .set(inputContext):
            updatedRecord.inputContext = inputContext?.trimmedOrNil
        }

        switch mutation.recordPatch.captureSource {
        case .unchanged:
            break
        case let .set(captureSource):
            if let captureSource {
                updatedRecord.captureSource = captureSource
            }
        }

        let addedArtifacts = mutation.addedArtifacts.isEmpty
            ? []
            : repository.captureArtifactBuilder.buildArtifacts(
                from: MemoryCaptureDraft(rawText: "", artifacts: mutation.addedArtifacts),
                recordID: recordID,
                createdAt: now
            )

        var updatedArtifactIDs: [UUID] = []
        var normalizedUpdatedArtifacts: [Artifact] = []
        for var artifact in mutation.updatedArtifacts {
            guard artifact.recordID == recordID else {
                throw CocoaError(.fileNoSuchFile)
            }
            guard try repository.fetchArtifact(id: artifact.id)?.recordID == recordID else {
                throw CocoaError(.fileNoSuchFile)
            }
            artifact.updatedAt = now
            normalizedUpdatedArtifacts.append(artifact)
            updatedArtifactIDs.append(artifact.id)
        }
        updatedArtifactIDs = repository.orderedUniqueUUIDs(updatedArtifactIDs)

        for artifactID in deletedArtifactIDs {
            let belongsToRecord: Bool
            if existingArtifactIDs.contains(artifactID) {
                belongsToRecord = true
            } else {
                belongsToRecord = try repository.fetchArtifact(id: artifactID)?.recordID == recordID
            }
            guard belongsToRecord else {
                throw CocoaError(.fileNoSuchFile)
            }
        }

        var artifactIDs = updatedRecord.artifactIDs
        artifactIDs.removeAll { deletedArtifactIDs.contains($0) }
        artifactIDs.append(contentsOf: addedArtifacts.map(\.id))
        artifactIDs = repository.orderedUniqueUUIDs(artifactIDs)

        var reorderedArtifactIDs: [UUID] = []
        if let requestedOrder = mutation.artifactOrder {
            let uniqueRequestedOrder = repository.orderedUniqueUUIDs(requestedOrder)
            let requestedSet = Set(uniqueRequestedOrder)
            let knownSet = Set(artifactIDs)
            guard requestedSet.isSubset(of: knownSet) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let remaining = artifactIDs.filter { !requestedSet.contains($0) }
            artifactIDs = uniqueRequestedOrder + remaining
            reorderedArtifactIDs = uniqueRequestedOrder
        }

        try repository.purgeDerivedDataForRefresh(recordID: recordID)

        for artifact in addedArtifacts {
            try repository.upsert(artifact: artifact)
        }
        for artifact in normalizedUpdatedArtifacts {
            try repository.upsert(artifact: artifact)
        }
        for artifactID in deletedArtifactIDs {
            if let store = try repository.modelContext.fetch(
                FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.id == artifactID })
            ).first {
                repository.modelContext.delete(store)
            }
        }

        updatedRecord.artifactIDs = artifactIDs
        updatedRecord.updatedAt = now
        recordStore.apply(domainModel: updatedRecord)
        if mutation.recordPatch.userMood.shouldUpdate {
            try repository.replaceUserAffectSnapshot(recordID: recordID, rawMood: updatedRecord.userMood, now: now)
        }

        try repository.upsertPendingPipelineStatus(recordID: recordID, updatedAt: now)
        try repository.save()

        var detail = try repository.fetchMemoryDetail(recordID: recordID)
        if let detail {
            await repository.indexMemoryIfPossible(
                repository.makeMemorySummary(
                    record: detail.record,
                    artifacts: detail.artifacts,
                    pipelineStatus: detail.pipelineStatus
                )
            )
        }

        if refreshPolicy == .runImmediately {
            try await refreshMemoryPipeline(recordID: recordID)
            detail = try repository.fetchMemoryDetail(recordID: recordID)
        }

        let pipelineStatus = if let detail {
            detail.pipelineStatus
        } else {
            try repository.fetchPipelineStatus(recordID: recordID)
        }

        return MemoryMutationResult(
            mutationID: mutationID,
            detail: detail,
            addedArtifactIDs: addedArtifacts.map(\.id),
            updatedArtifactIDs: updatedArtifactIDs,
            deletedArtifactIDs: deletedArtifactIDs,
            reorderedArtifactIDs: reorderedArtifactIDs,
            invalidatedDerivedData: true,
            pipelineStatus: pipelineStatus
        )
    }

    func appendArtifacts(recordID: UUID, drafts: [CaptureArtifactDraft]) async throws -> MemorySummary? {
        guard !drafts.isEmpty else {
            guard let record = try repository.fetchRecordShell(id: recordID) else { return nil }
            return try repository.makeMemorySummary(
                record: record,
                artifacts: repository.fetchArtifacts(recordID: recordID),
                pipelineStatus: repository.fetchPipelineStatus(recordID: recordID)
            )
        }

        let result = try await applyMemoryMutation(
            recordID: recordID,
            mutation: MemoryMutationDraft(addedArtifacts: drafts),
            refreshPolicy: .markPending
        )
        guard let detail = result.detail else { return nil }
        return repository.makeMemorySummary(
            record: detail.record,
            artifacts: detail.artifacts,
            pipelineStatus: detail.pipelineStatus
        )
    }

    func deleteMemory(recordID: UUID) throws {
        try repository.purgeDerivedData(forRecordIDs: [recordID], includePipelineStatus: true)
        try repository.deleteMemoryDetailPresentationPreference(recordID: recordID, saveAfterDelete: false)
        if let record = try repository.modelContext.fetch(
            FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })
        ).first {
            repository.modelContext.delete(record)
        }
        let affectSnapshots = try repository.modelContext.fetch(
            FetchDescriptor<AffectSnapshotStore>(predicate: #Predicate { $0.recordID == recordID })
        )
        affectSnapshots.forEach { repository.modelContext.delete($0) }
        let artifacts = try repository.modelContext.fetch(
            FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.recordID == recordID })
        )
        artifacts.forEach { repository.modelContext.delete($0) }
        try repository.save()

        let spotlightIndexService = repository.spotlightIndexService
        let spotlightItemBuilder = repository.spotlightItemBuilder
        Task { @MainActor in
            try? await spotlightIndexService.deleteItems(
                identifiers: [spotlightItemBuilder.memoryIdentifier(recordID)]
            )
        }
    }

    func updateMemory(recordID: UUID, draft: MemoryEditDraft) async throws -> MemoryDetailSnapshot? {
        let addedArtifacts: [CaptureArtifactDraft]
        if let appendedArtifactText = draft.appendedArtifactText?.trimmedOrNil {
            addedArtifacts = [.text(title: appendedArtifactText.firstMeaningfulLine ?? "Added Note", body: appendedArtifactText)]
        } else {
            addedArtifacts = []
        }

        let result = try await applyMemoryMutation(
            recordID: recordID,
            mutation: MemoryMutationDraft(
                recordPatch: MemoryMutationRecordPatch(
                    rawText: .set(draft.rawText),
                    userMood: .set(draft.userMood),
                    inputContext: .set(draft.inputContext)
                ),
                addedArtifacts: addedArtifacts
            ),
            refreshPolicy: .markPending
        )
        return result.detail
    }

    func refreshMemoryPipeline(recordID: UUID) async throws {
        guard let record = try repository.fetchRecordShell(id: recordID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let artifacts = try repository.fetchArtifacts(recordID: recordID)
        let attemptAt = Date.now
        let previousStatus = try repository.fetchPipelineStatus(recordID: recordID)

        try repository.purgeDerivedDataForRefresh(recordID: recordID)

        try repository.upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .running,
                requestID: previousStatus?.requestID,
                lastError: nil,
                requestBody: previousStatus?.requestBody,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: nil,
                failedStage: nil,
                lastAttemptAt: attemptAt,
                completedAt: nil,
                updatedAt: attemptAt
            )
        )
        try repository.save()

        do {
            try await repository.runArchitecturePipeline(record: record, artifacts: artifacts)
            do {
                try repository.applyAnalysisFollowups(record: record, artifacts: artifacts)
            } catch {
                try repository.markLatestPostAnalysisJobFailed(recordID: recordID, error: error)
            }
            let trace = repository.latestAnalysisTrace
            let completedAt = Date.now
            try repository.upsertPipelineStatus(
                MemoryPipelineStatusSnapshot(
                    recordID: recordID,
                    stage: .completed,
                    requestID: trace?.requestID,
                    lastError: nil,
                    requestBody: trace?.requestBody,
                    responseBody: trace?.responseBody,
                    rawErrorBody: nil,
                    lastHTTPStatusCode: trace?.statusCode,
                    failedStage: nil,
                    lastAttemptAt: attemptAt,
                    completedAt: completedAt,
                    updatedAt: completedAt
                )
            )
            try repository.save()
            if let summary = try? repository.makeMemorySummary(
                record: record,
                artifacts: artifacts,
                pipelineStatus: repository.fetchPipelineStatus(recordID: recordID)
            ) {
                await repository.indexMemoryIfPossible(summary)
            }
            _ = await repository.backgroundTriggerDispatcher?.handle(
                trigger: BackgroundTrigger(
                    kind: .pipelineCompleted,
                    targetID: recordID,
                    source: "MemoryMutationUseCase.refreshMemoryPipeline"
                ),
                repository: repository,
                now: completedAt
            )
            NotificationCenter.default.post(
                name: .pipelineDidComplete,
                object: nil,
                userInfo: ["recordID": recordID]
            )
        } catch {
            let trace = repository.latestAnalysisTrace
            let failedAt = Date.now
            try repository.upsertPipelineStatus(
                MemoryPipelineStatusSnapshot(
                    recordID: recordID,
                    stage: .failed,
                    requestID: trace?.requestID,
                    lastError: error.localizedDescription,
                    requestBody: trace?.requestBody,
                    responseBody: trace?.responseBody,
                    rawErrorBody: trace?.rawErrorBody,
                    lastHTTPStatusCode: trace?.statusCode,
                    failedStage: trace?.failedStage,
                    lastAttemptAt: attemptAt,
                    completedAt: nil,
                    updatedAt: failedAt
                )
            )
            try repository.save()
            NotificationCenter.default.post(
                name: .pipelineDidComplete,
                object: nil,
                userInfo: ["recordID": recordID]
            )
            throw error
        }
    }
}
