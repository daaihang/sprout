import Foundation
import SwiftData

struct DebugDiagnosticsService {
    private let graphQueryService = MemoryGraphQueryService()

    // MARK: - Main Entry Point

    func fetchDiagnostics(
        targetType: DebugAnalysisTarget,
        targetID: UUID?,
        modelContext: ModelContext,
        memories: [MemorySummary],
        pipelineStatusFetcher: (UUID) throws -> MemoryPipelineStatusSnapshot?,
        recordAnalysisFetcher: (UUID) throws -> RecordAnalysisSnapshot?,
        artifactsFetcher: (UUID) throws -> [Artifact],
        latestReflectionTrace: DebugPipelineTraceSnapshot?
    ) throws -> DebugDiagnosticsSnapshot {
        let graphContext = try graphQueryService.load(modelContext: modelContext, memories: memories)
        let target = try resolveTarget(targetType: targetType, targetID: targetID, memories: memories, graphContext: graphContext)

        let fixture: DebugMemoryFixtureSnapshot?
        if let target {
            switch target.targetType {
            case .memory:
                if let memory = target.memory {
                    fixture = try fetchFixtureSnapshot(
                        recordID: memory.record.id,
                        modelContext: modelContext,
                        artifactsFetcher: artifactsFetcher,
                        recordAnalysisFetcher: recordAnalysisFetcher,
                        pipelineStatusFetcher: pipelineStatusFetcher
                    )
                } else {
                    fixture = nil
                }
            case .arc, .reflection:
                fixture = nil
            }
        } else {
            fixture = nil
        }

        let provenance = try fetchProvenance(
            targetType: targetType,
            targetID: targetID,
            memories: memories,
            graphContext: graphContext
        )
        let analyzePayload = try buildAnalyzePayload(
            for: target,
            pipelineStatusFetcher: pipelineStatusFetcher,
            artifactsFetcher: artifactsFetcher,
            recordAnalysisFetcher: recordAnalysisFetcher
        )
        let reflectionPayload = try buildReflectionPayload(
            for: target,
            latestReflectionTrace: latestReflectionTrace,
            artifactsFetcher: artifactsFetcher
        )
        let pipelineTrace = try resolveRecordID(targetType: targetType, targetID: targetID, memories: memories, graphContext: graphContext)
            .flatMap { try pipelineStatusFetcher($0) }
            .map {
                DebugPipelineTraceSnapshot(
                    requestID: $0.requestID,
                    requestBody: $0.requestBody,
                    responseBody: $0.responseBody,
                    rawErrorBody: $0.rawErrorBody,
                    statusCode: $0.lastHTTPStatusCode,
                    failedStage: $0.failedStage
                )
            }

        return DebugDiagnosticsSnapshot(
            target: target,
            analyzePayload: analyzePayload,
            reflectionPayload: reflectionPayload,
            provenance: provenance,
            fixture: fixture,
            pipelineTrace: pipelineTrace
        )
    }

    // MARK: - Debug Fixture Snapshot

    func fetchFixtureSnapshot(
        recordID: UUID,
        modelContext: ModelContext,
        artifactsFetcher: (UUID) throws -> [Artifact],
        recordAnalysisFetcher: (UUID) throws -> RecordAnalysisSnapshot?,
        pipelineStatusFetcher: (UUID) throws -> MemoryPipelineStatusSnapshot?
    ) throws -> DebugMemoryFixtureSnapshot? {
        guard let record = try modelContext.fetch(FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })).first?.domainModel else {
            return nil
        }

        let artifacts = try artifactsFetcher(recordID)
        let analysis = try recordAnalysisFetcher(recordID)
        let pipelineStatus = try pipelineStatusFetcher(recordID)
        let links = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>()).map(\.domainModel)
            .filter { link in artifacts.contains(where: { $0.id == link.artifactID }) }
        let entityIDs = Set(links.map(\.entityID))
        let entities = try modelContext.fetch(FetchDescriptor<EntityNodeStore>()).map(\.domainModel)
            .filter { entityIDs.contains($0.id) }
        let edges = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>()).map(\.domainModel)
            .filter { $0.sourceRecordIDs.contains(recordID) }
        let arcs = try modelContext.fetch(FetchDescriptor<TemporalArcStore>()).map(\.domainModel)
            .filter { $0.sourceRecordIDs.contains(recordID) }
        let reflections = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>()).map(\.domainModel)
            .filter { reflection in
                reflection.sourceRecordIDs.contains(recordID)
                    || arcs.contains(where: { $0.id == reflection.linkedTemporalArcID })
            }

        return DebugMemoryFixtureSnapshot(
            recordID: record.id,
            recordTitle: record.rawText.firstMeaningfulLine ?? "Debug Fixture",
            chain: DebugMemoryChainSnapshot(
                record: record,
                artifacts: artifacts,
                analysis: analysis,
                pipelineStatus: pipelineStatus,
                entities: entities,
                edges: edges,
                links: links,
                arcs: arcs,
                reflections: reflections
            )
        )
    }

    // MARK: - Resolve Target

    private func resolveTarget(
        targetType: DebugAnalysisTarget,
        targetID: UUID?,
        memories: [MemorySummary],
        graphContext: MemoryGraphContext
    ) throws -> DebugTargetSnapshot? {
        switch targetType {
        case .memory:
            let memory: MemorySummary?
            if let targetID {
                memory = memories.first(where: { $0.record.id == targetID })
            } else {
                memory = memories.first
            }
            guard let memory else { return nil }
            return DebugTargetSnapshot(targetType: .memory, memory: memory, arc: nil, reflection: nil)
        case .arc:
            let arc = graphContext.arcs.first(where: { $0.id == targetID }) ?? graphContext.arcs.first
            guard let arc else { return nil }
            let summary = TemporalArcSummarySnapshot(
                arc: arc,
                relatedMemories: graphContext.relatedMemories(recordIDs: arc.sourceRecordIDs, limit: 3),
                linkedReflection: graphContext.reflections.first(where: { $0.linkedTemporalArcID == arc.id })
            )
            return DebugTargetSnapshot(targetType: .arc, memory: nil, arc: summary, reflection: nil)
        case .reflection:
            let reflection = graphContext.reflections.first(where: { $0.id == targetID }) ?? graphContext.reflections.first
            guard let reflection else { return nil }
            let linkedArc = reflection.linkedTemporalArcID.flatMap { linkedArcID in
                graphContext.arcs.first(where: { $0.id == linkedArcID })
            }
            let summary = ReflectionSummarySnapshot(
                reflection: reflection,
                linkedArc: linkedArc,
                relatedMemories: graphContext.relatedMemories(recordIDs: reflection.sourceRecordIDs, limit: 3)
            )
            return DebugTargetSnapshot(targetType: .reflection, memory: nil, arc: nil, reflection: summary)
        }
    }

    // MARK: - Resolve Record ID

    private func resolveRecordID(
        targetType: DebugAnalysisTarget,
        targetID: UUID?,
        memories: [MemorySummary],
        graphContext: MemoryGraphContext
    ) throws -> UUID? {
        let target = try resolveTarget(targetType: targetType, targetID: targetID, memories: memories, graphContext: graphContext)
        switch target?.targetType {
        case .memory:
            return target?.memory?.record.id
        case .arc:
            return target?.arc?.arc.sourceRecordIDs.first
        case .reflection:
            return target?.reflection?.reflection.sourceRecordIDs.first
        case nil:
            return nil
        }
    }

    // MARK: - Build Analyze Payload

    private func buildAnalyzePayload(
        for target: DebugTargetSnapshot?,
        pipelineStatusFetcher: (UUID) throws -> MemoryPipelineStatusSnapshot?,
        artifactsFetcher: (UUID) throws -> [Artifact],
        recordAnalysisFetcher: (UUID) throws -> RecordAnalysisSnapshot?
    ) throws -> DebugAnalyzePayloadSnapshot? {
        guard let target, let memory = target.memory else { return nil }
        let pipelineStatus = try pipelineStatusFetcher(memory.record.id)
        let artifacts = try artifactsFetcher(memory.record.id)
        let request = AnalyzeRequestBuilder().build(
            record: memory.record,
            artifacts: artifacts,
            knownEntities: []
        )
        let encoded = pipelineStatus?.requestBody ?? String(data: (try? JSONEncoder().encode(request)) ?? Data(), encoding: .utf8) ?? ""
        let response = try recordAnalysisFetcher(memory.record.id)
        let responseEncoded = pipelineStatus?.responseBody ?? response.flatMap { String(data: (try? JSONEncoder().encode($0)) ?? Data(), encoding: .utf8) } ?? ""
        return DebugAnalyzePayloadSnapshot(
            recordID: memory.record.id,
            requestBody: encoded,
            responseBody: responseEncoded,
            lastError: pipelineStatus?.lastError,
            rawErrorBody: pipelineStatus?.rawErrorBody
        )
    }

    // MARK: - Build Reflection Payload

    private func buildReflectionPayload(
        for target: DebugTargetSnapshot?,
        latestReflectionTrace: DebugPipelineTraceSnapshot?,
        artifactsFetcher: (UUID) throws -> [Artifact]
    ) throws -> DebugReflectionPayloadSnapshot? {
        guard let target else { return nil }
        switch target.targetType {
        case .memory:
            guard let memory = target.memory else { return nil }
            let artifacts = try artifactsFetcher(memory.record.id)
            let analyzePayload = AnalyzeRequestBuilder().build(record: memory.record, artifacts: artifacts)
            let payload = MoryAPIClient.ReflectionPayload(
                recordShell: analyzePayload.recordShell,
                artifacts: analyzePayload.artifacts,
                linkedArcID: nil,
                knownEntities: [],
                prompt: memory.record.rawText
            )
            let requestBody = String(data: (try? JSONEncoder().encode(payload)) ?? Data(), encoding: .utf8) ?? ""
            return DebugReflectionPayloadSnapshot(
                recordID: memory.record.id,
                arcID: nil,
                requestBody: latestReflectionTrace?.requestBody ?? requestBody,
                responseBody: latestReflectionTrace?.responseBody ?? "",
                lastError: latestReflectionTrace?.failedStage,
                rawErrorBody: latestReflectionTrace?.rawErrorBody
            )
        case .arc:
            guard let arc = target.arc else { return nil }
            let payload = MoryAPIClient.ReflectionPayload(
                recordShell: AnalyzeRequestBuilder().build(
                    record: RecordShell(createdAt: .now, updatedAt: .now, captureSource: .manual, rawText: arc.arc.summary),
                    artifacts: []
                ).recordShell,
                artifacts: [],
                linkedArcID: arc.arc.id.uuidString,
                knownEntities: [],
                prompt: arc.arc.summary
            )
            let requestBody = String(data: (try? JSONEncoder().encode(payload)) ?? Data(), encoding: .utf8) ?? ""
            return DebugReflectionPayloadSnapshot(
                recordID: arc.arc.sourceRecordIDs.first,
                arcID: arc.arc.id,
                requestBody: latestReflectionTrace?.requestBody ?? requestBody,
                responseBody: latestReflectionTrace?.responseBody ?? "",
                lastError: latestReflectionTrace?.failedStage,
                rawErrorBody: latestReflectionTrace?.rawErrorBody
            )
        case .reflection:
            guard let reflection = target.reflection else { return nil }
            struct ReflectionReplayDebugRequest: Encodable {
                let reflectionID: String
                let linkedArcID: String?

                enum CodingKeys: String, CodingKey {
                    case reflectionID = "reflection_id"
                    case linkedArcID = "linked_arc_id"
                }
            }
            let request = ReflectionReplayDebugRequest(
                reflectionID: reflection.reflection.id.uuidString,
                linkedArcID: reflection.linkedArc?.id.uuidString
            )
            let requestBody = latestReflectionTrace?.requestBody ?? String(data: (try? JSONEncoder().encode(request)) ?? Data(), encoding: .utf8) ?? ""
            return DebugReflectionPayloadSnapshot(
                recordID: reflection.reflection.sourceRecordIDs.first,
                arcID: reflection.linkedArc?.id,
                requestBody: requestBody,
                responseBody: latestReflectionTrace?.responseBody ?? reflection.reflection.body,
                lastError: latestReflectionTrace?.failedStage,
                rawErrorBody: latestReflectionTrace?.rawErrorBody
            )
        }
    }

    // MARK: - Fetch Provenance

    private func fetchProvenance(
        targetType: DebugAnalysisTarget,
        targetID: UUID?,
        memories: [MemorySummary],
        graphContext: MemoryGraphContext
    ) throws -> [DebugProvenanceSnapshot] {
        switch targetType {
        case .memory:
            let fallbackMemoryID = memories.first?.record.id
            let memoryID = targetID ?? fallbackMemoryID
            guard let memoryID else { return [] }
            return graphContext.entities
                .filter { $0.provenanceRecordIDs.contains(memoryID) }
                .map { entity in
                    DebugProvenanceSnapshot(
                        entityID: entity.id,
                        aliasCount: entity.aliases.count,
                        provenanceRecordIDs: entity.provenanceRecordIDs,
                        linkedArtifactIDs: graphContext.links.filter { $0.entityID == entity.id }.map(\.artifactID),
                        linkedAnalysisRecordIDs: graphContext.links.filter { $0.entityID == entity.id }.compactMap(\.sourceAnalysisRecordID),
                        evidenceSummary: graphContext.links.filter { $0.entityID == entity.id }.map(\.evidenceSummary).joined(separator: " | ")
                    )
                }
        case .arc, .reflection:
            return graphContext.entities.map { entity in
                DebugProvenanceSnapshot(
                    entityID: entity.id,
                    aliasCount: entity.aliases.count,
                    provenanceRecordIDs: entity.provenanceRecordIDs,
                    linkedArtifactIDs: graphContext.links.filter { $0.entityID == entity.id }.map(\.artifactID),
                    linkedAnalysisRecordIDs: graphContext.links.filter { $0.entityID == entity.id }.compactMap(\.sourceAnalysisRecordID),
                    evidenceSummary: graphContext.links.filter { $0.entityID == entity.id }.map(\.evidenceSummary).joined(separator: " | ")
                )
            }
        }
    }

    // MARK: - Linked Entity References

    func linkedEntityReferences(
        recordID: UUID?,
        arcID: UUID?,
        reflectionID: UUID?,
        modelContext: ModelContext,
        memories: [MemorySummary]
    ) throws -> [EntityReference] {
        let graphContext = try graphQueryService.load(modelContext: modelContext, memories: memories)
        let recordIDs = [recordID]
            + graphContext.arcs.filter { $0.id == arcID }.flatMap(\.sourceRecordIDs)
            + graphContext.reflections.filter { $0.id == reflectionID }.flatMap(\.sourceRecordIDs)
        let targetRecordIDs = Set(recordIDs.compactMap { $0 })

        return graphContext.entities
            .filter { !Set($0.provenanceRecordIDs).isDisjoint(with: targetRecordIDs) }
            .map {
                EntityReference(
                    id: $0.id,
                    kind: $0.kind,
                    name: $0.displayName,
                    aliases: $0.aliases,
                    confidence: $0.confidence
                )
            }
    }

    // MARK: - Delete Record

    func deleteRecord(recordID: UUID, modelContext: ModelContext) throws {
        if let record = try modelContext.fetch(FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })).first {
            modelContext.delete(record)
        }
        let artifactStores = try modelContext.fetch(FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.recordID == recordID }))
        artifactStores.forEach { modelContext.delete($0) }
        let pipelineStores = try modelContext.fetch(FetchDescriptor<MemoryPipelineStatusStore>(predicate: #Predicate { $0.recordID == recordID }))
        pipelineStores.forEach { modelContext.delete($0) }
        let analysisStores = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>(predicate: #Predicate { $0.recordID == recordID }))
        analysisStores.forEach { modelContext.delete($0) }
    }

    // MARK: - Replay Reflection

    func replayReflection(
        reflectionID: UUID,
        modelContext: ModelContext,
        memories: [MemorySummary],
        analysisService: any RecordAnalysisServing
    ) async throws -> DebugPipelineTraceSnapshot? {
        guard let reflection = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(predicate: #Predicate { $0.id == reflectionID })
        ).first?.domainModel else {
            throw CocoaError(.fileNoSuchFile)
        }
        let linkedArc = reflection.linkedTemporalArcID.flatMap { arcID in
            try? modelContext.fetch(
                FetchDescriptor<TemporalArcStore>(predicate: #Predicate { $0.id == arcID })
            ).first?.domainModel
        } ?? nil
        let record = try reflection.sourceRecordIDs.first.flatMap { recordID in
            try modelContext.fetch(FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })).first?.domainModel
        }
        let artifacts: [Artifact]
        if let recordID = record?.id {
            artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.recordID == recordID })).map(\.domainModel)
        } else {
            artifacts = []
        }
        let knownEntities = try linkedEntityReferences(
            recordID: record?.id,
            arcID: linkedArc?.id,
            reflectionID: reflection.id,
            modelContext: modelContext,
            memories: memories
        )

        let result = try await analysisService.replayReflection(
            reflection: reflection,
            linkedArc: linkedArc,
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities,
            prompt: reflection.body
        )
        return result.debugTrace
    }
}
