import Foundation

extension Notification.Name {
    static let pipelineDidComplete = Notification.Name("mory.pipelineDidComplete")
}

struct AnalysisExecutor {
    private let graphUpdater = GraphUpdater()
    private let placeProfileResolver = PlaceProfileResolver()
    private let candidateBuilder = TemporalArcCandidateBuilder()
    private let temporalArcService = TemporalArcService()
    private let arcQualityPolicy = ArcQualityPolicy()

    @MainActor
    func run(
        record: RecordShell,
        artifacts: [Artifact],
        inputContract: AnalysisInputContract? = nil,
        dependencies: AnalysisPipelineDependencies
    ) async throws {
        // Step 1: Fetch known entities for compact compatibility context.
        let activeRecordScope = dependencies.runtimeScope.activeRecordScope
        let preContext = try dependencies.query.loadPreAnalysisContext(recordScope: activeRecordScope)
        let existingEntityNodes = preContext.entityNodes
        let knownEntities = existingEntityNodes
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(20)
            .map {
                EntityReference(
                    id: $0.id,
                    kind: $0.kind,
                    name: $0.displayName,
                    aliases: $0.aliases,
                    confidence: $0.confidence
                )
            }

        // Step 2: Build a bounded context pack and send the production Analysis request.
        let contextPack = try await dependencies.contextProvider.buildContextPack(targetRecordID: record.id)
        let affectSnapshots = (try? dependencies.contextProvider.fetchAffectSnapshots(recordID: record.id, limit: 10)) ?? []
        let payload = AnalysisRequestBuilder().build(
            inputContract: inputContract ?? AnalysisInputContract(
                record: record,
                artifacts: artifacts,
                semanticDigests: [],
                excludedCardArrangementID: nil
            ),
            knownEntities: Array(knownEntities),
            contextPack: contextPack,
            affectSnapshots: affectSnapshots
        )
        let requestBody = String(data: (try? JSONEncoder().encode(payload)) ?? Data(), encoding: .utf8)
        let envelope: AnalysisResponseEnvelope
        do {
            envelope = try await dependencies.cloudIntelligenceService.analyzeMemory(payload)
            let responseBody = String(data: (try? JSONEncoder().encode(envelope)) ?? Data(), encoding: .utf8)
            let requestID: String?
            if let debugging = dependencies.cloudIntelligenceService as? any CloudIntelligenceDebugging {
                requestID = await debugging.latestCloudDebugRequestID()
            } else {
                requestID = payload.clientRequestID
            }
            dependencies.tracing.setDebugTrace(
                DebugPipelineTraceSnapshot(
                    requestID: requestID,
                    requestBody: requestBody,
                    responseBody: responseBody,
                    rawErrorBody: nil,
                    statusCode: 200,
                    failedStage: nil
                )
            )
        } catch {
            let debugError: MoryAPIClient.DebugErrorSnapshot?
            let requestID: String?
            if let debugging = dependencies.cloudIntelligenceService as? any CloudIntelligenceDebugging {
                debugError = await debugging.latestCloudDebugError()
                requestID = await debugging.latestCloudDebugRequestID()
            } else {
                debugError = nil
                requestID = payload.clientRequestID
            }
            dependencies.tracing.setDebugTrace(
                DebugPipelineTraceSnapshot(
                    requestID: debugError?.requestID ?? requestID,
                    requestBody: requestBody,
                    responseBody: debugError?.responseBody,
                    rawErrorBody: debugError?.rawErrorBody,
                    statusCode: debugError?.statusCode,
                    failedStage: "analysis"
                )
            )
            throw error
        }
        let mapped = AnalysisResponseMapper().map(
            recordID: record.id,
            response: envelope,
            createdAt: Date.now
        )
        let analysis = mapped.analysis

        // Step 3: Compute entity graph updates after analysis and before reflection.
        let graphUpdate = graphUpdater.apply(
            analysis: analysis,
            linkedArtifactIDs: record.artifactIDs,
            linkedRecordIDs: [record.id],
            existingEntityNodes: existingEntityNodes,
            existingEntityEdges: preContext.entityEdges,
            existingArtifactEntityLinks: preContext.artifactEntityLinks
        )
        let placeResolution = placeProfileResolver.resolve(
            locationArtifacts: artifacts.filter { $0.kind == .location },
            recordID: record.id,
            existingProfiles: preContext.placeProfiles,
            existingEntityNodes: graphUpdate.entityNodes,
            existingArtifactEntityLinks: graphUpdate.artifactEntityLinks,
            timestamp: analysis.createdAt
        )
        let completeEntityNodes = mergedEntityNodes(graphUpdate.entityNodes, placeResolution.entityNodes)
        let completeArtifactEntityLinks = mergedArtifactEntityLinks(graphUpdate.artifactEntityLinks, placeResolution.artifactEntityLinks)

        // Step 4: Build deterministic local TemporalArcCandidates from the analysis.
        let postContext = try dependencies.query.loadPostAnalysisContext(
            replacingWith: analysis,
            recordScope: activeRecordScope
        )
        let candidateRecords = postContext.records
        let candidateAnalyses = postContext.analyses
        let candidateArtifacts = postContext.artifacts
        let existingArcs = postContext.temporalArcs
        let candidates = candidateBuilder.buildCandidates(
            records: candidateRecords,
            analyses: candidateAnalyses,
            artifacts: candidateArtifacts,
            artifactEntityLinks: completeArtifactEntityLinks,
            entityNodes: completeEntityNodes,
            focusRecordID: record.id,
            maxCandidates: 3
        )

        // Step 5: Accept local candidate arcs via promoter.
        var localTemporalArcs: [TemporalArc] = []
        var localReflections: [ReflectionSnapshot] = []
        for candidate in candidates {
            guard candidate.recordIDs.contains(record.id) else { continue }
            guard arcQualityPolicy.evaluate(candidate).passed else { continue }
            guard !hasExistingArc(for: candidate, existingArcs: existingArcs) else { continue }
            let promotionResult = temporalArcService.promote(
                candidate: candidate,
                analyses: candidateAnalyses,
                artifactEntityLinks: completeArtifactEntityLinks,
                entityNodes: completeEntityNodes
            )
            localTemporalArcs.append(promotionResult.arc)
            localReflections.append(promotionResult.reflection)
        }

        // Step 6: Materialize one explicit AnalysisOutput, then persist in a fixed order.
        let output = AnalysisOutput(
            recordAnalysis: analysis,
            graphProjection: AnalysisGraphProjection(
                placeProfiles: placeResolution.profiles,
                entityNodes: completeEntityNodes,
                entityEdges: graphUpdate.entityEdges,
                artifactEntityLinks: completeArtifactEntityLinks
            ),
            proposals: AnalysisProposals(
                affectSnapshots: mapped.affectProposals,
                graphDeltas: mapped.graphDeltaProposals,
                temporalArcs: mapped.arcProposals + localTemporalArcs,
                reflections: mapped.reflectionProposals + localReflections,
                questions: mapped.questionProposals + mapped.mergeSplitQuestions
            ),
            quality: mapped.quality,
            followupPlan: AnalysisFollowupPlan()
        )
        try AnalysisOutputPersister().persist(output, using: dependencies.persist)
    }

    private func hasExistingArc(for candidate: TemporalArcCandidate, existingArcs: [TemporalArc]) -> Bool {
        let candidateRecordIDs = Set(candidate.recordIDs)
        return existingArcs.contains {
            $0.status != .archived && Set($0.sourceRecordIDs) == candidateRecordIDs
        }
    }

    private func mergedEntityNodes(_ primary: [EntityNode], _ secondary: [EntityNode]) -> [EntityNode] {
        var seen = Set<UUID>()
        var result: [EntityNode] = []
        for node in secondary + primary where !seen.contains(node.id) {
            seen.insert(node.id)
            result.append(node)
        }
        return result
    }

    private func mergedArtifactEntityLinks(
        _ primary: [ArtifactEntityLink],
        _ secondary: [ArtifactEntityLink]
    ) -> [ArtifactEntityLink] {
        var result: [ArtifactEntityLink] = []
        var indexByPair: [ArtifactEntityLinkPair: Int] = [:]

        for link in primary + secondary {
            let pair = ArtifactEntityLinkPair(artifactID: link.artifactID, entityID: link.entityID)
            if let index = indexByPair[pair] {
                result[index] = preferredArtifactEntityLink(existing: result[index], incoming: link)
            } else {
                indexByPair[pair] = result.count
                result.append(link)
            }
        }

        return result
    }

    private func preferredArtifactEntityLink(
        existing: ArtifactEntityLink,
        incoming: ArtifactEntityLink
    ) -> ArtifactEntityLink {
        var merged = (incoming.confidence ?? 0) >= (existing.confidence ?? 0) ? incoming : existing
        merged.sourceRecordID = merged.sourceRecordID ?? existing.sourceRecordID ?? incoming.sourceRecordID
        merged.sourceAnalysisRecordID = merged.sourceAnalysisRecordID ?? existing.sourceAnalysisRecordID ?? incoming.sourceAnalysisRecordID
        if merged.evidenceSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.evidenceSummary = existing.evidenceSummary.trimmedOrNil ?? incoming.evidenceSummary
        }
        return merged
    }

    private struct ArtifactEntityLinkPair: Hashable {
        var artifactID: UUID
        var entityID: UUID
    }

}
