import Foundation

struct AnalysisRequestBuilder {
    private let recordPayloadBuilder = AnalysisRecordPayloadBuilder()
    private let dateFormatter = ISO8601DateFormatter()

    func build(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference] = [],
        contextPack: AnalysisContextPack,
        affectSnapshots: [AffectSnapshot] = [],
        clientRequestID: UUID = UUID(),
        analysisReason: String = "capture_ingest_context"
    ) -> AnalysisRequestPayload {
        let contract = AnalysisInputContract(
            record: record,
            artifacts: artifacts,
            semanticDigests: []
        )
        return build(
            inputContract: contract,
            knownEntities: knownEntities,
            contextPack: contextPack,
            affectSnapshots: affectSnapshots,
            clientRequestID: clientRequestID,
            analysisReason: analysisReason
        )
    }

    func build(
        inputContract: AnalysisInputContract,
        knownEntities: [EntityReference] = [],
        contextPack: AnalysisContextPack,
        affectSnapshots: [AffectSnapshot] = [],
        clientRequestID: UUID = UUID(),
        analysisReason: String = "capture_ingest_context"
    ) -> AnalysisRequestPayload {
        let base = recordPayloadBuilder.build(
            record: inputContract.record,
            artifacts: inputContract.artifacts,
            knownEntities: knownEntities,
            analysisReason: analysisReason,
            schemaVersion: "analysis",
            clientVersion: "mory.analysis"
        )
        return AnalysisRequestPayload(
            clientRequestID: clientRequestID.uuidString,
            recordShell: base.recordShell,
            artifacts: base.artifacts,
            knownEntities: base.knownEntities,
            moodEvidence: affectSnapshots.map(moodEvidencePayload),
            contextPack: contextPayload(contextPack),
            clientCapabilities: .moryDefault,
            debugOptions: base.debugOptions
        )
    }

    private func moodEvidencePayload(_ snapshot: AffectSnapshot) -> AnalysisRequestPayload.MoodEvidencePayload {
        AnalysisRequestPayload.MoodEvidencePayload(
            id: snapshot.id.uuidString,
            recordID: snapshot.recordID.uuidString,
            valence: snapshot.valence,
            arousal: snapshot.arousal,
            dominance: snapshot.dominance,
            intensity: snapshot.intensity,
            labels: snapshot.labels.map(\.rawValue),
            toneHints: snapshot.toneHints.map(\.rawValue),
            sources: snapshot.sources.map(\.rawValue),
            confidence: snapshot.confidence,
            userConfirmed: snapshot.userConfirmed,
            evidence: snapshot.evidence.map {
                AnalysisRequestPayload.EvidencePayload(
                    recordID: snapshot.recordID.uuidString,
                    artifactID: nil,
                    snippet: $0.summary,
                    createdAt: dateFormatter.string(from: $0.createdAt)
                )
            }
        )
    }

    private func contextPayload(_ pack: AnalysisContextPack) -> AnalysisRequestPayload.ContextPackPayload {
        AnalysisRequestPayload.ContextPackPayload(
            packID: pack.packID.uuidString,
            targetRecordID: pack.targetRecordID.uuidString,
            selfBrief: pack.selfBrief.map { brief in
                AnalysisRequestPayload.SelfBriefPayload(
                    selfEntityID: brief.selfEntityID.uuidString,
                    displayName: brief.displayName,
                    aliases: brief.aliases,
                    roleLabels: brief.roleLabels,
                    goalTitles: brief.goalTitles,
                    expressionHints: brief.expressionHints,
                    privacyMode: brief.privacyMode.rawValue
                )
            },
            knownProfiles: pack.relatedProfiles.map {
                AnalysisRequestPayload.KnownProfilePayload(
                    entityID: $0.entityID.uuidString,
                    kind: $0.kind.rawValue,
                    displayName: $0.displayName,
                    relationshipToUser: $0.relationshipToUser?.rawValue,
                    mentionCount: $0.mentionCount,
                    commonContextLabels: $0.commonContextLabels,
                    confidence: $0.confidence,
                    inclusionReason: $0.inclusionReason
                )
            },
            relatedMemories: pack.relatedMemories.map {
                AnalysisRequestPayload.RelatedMemoryPayload(
                    recordID: $0.recordID.uuidString,
                    title: $0.title,
                    snippet: $0.snippet,
                    createdAt: dateFormatter.string(from: $0.createdAt),
                    userMood: $0.userMood,
                    score: $0.scoreBreakdown.total,
                    inclusionReasons: $0.inclusionReasons
                )
            },
            relatedArcs: pack.relatedArcs.map {
                AnalysisRequestPayload.RelatedArcPayload(
                    arcID: $0.arcID.uuidString,
                    title: $0.title,
                    summary: $0.summary,
                    status: $0.status.rawValue,
                    sourceRecordIDs: $0.sourceRecordIDs.map(\.uuidString),
                    score: $0.score
                )
            },
            priorReflections: pack.priorReflections.map {
                AnalysisRequestPayload.PriorReflectionPayload(
                    reflectionID: $0.reflectionID.uuidString,
                    title: $0.title,
                    evidenceSummary: $0.evidenceSummary,
                    status: $0.status.rawValue,
                    sourceRecordIDs: $0.sourceRecordIDs.map(\.uuidString),
                    confidence: $0.confidence
                )
            },
            correctionSignals: pack.correctionSignals.map {
                AnalysisRequestPayload.CorrectionSignalPayload(
                    id: $0.id.uuidString,
                    kind: $0.kind.rawValue,
                    targetType: $0.targetType.rawValue,
                    targetID: $0.targetID.uuidString,
                    status: $0.status.rawValue,
                    summary: $0.summary,
                    answeredAt: $0.answeredAt.map { dateFormatter.string(from: $0) }
                )
            },
            affectHistory: pack.affectHistory.map {
                AnalysisRequestPayload.AffectHistoryPayload(
                    mood: $0.mood,
                    count: $0.count,
                    latestRecordID: $0.latestRecordID.uuidString,
                    averageValence: $0.averageValence,
                    averageArousal: $0.averageArousal,
                    averageDominance: $0.averageDominance,
                    toneHints: $0.toneHints.map(\.rawValue),
                    sources: $0.sources.map(\.rawValue)
                )
            },
            privacyDecisions: pack.privacyDecisions.map {
                AnalysisRequestPayload.PrivacyDecisionPayload(
                    sourceType: $0.sourceType,
                    sourceID: $0.sourceID?.uuidString,
                    action: $0.action.rawValue,
                    reason: $0.reason
                )
            },
            budgetReport: AnalysisRequestPayload.BudgetReportPayload(
                maxProfiles: pack.budget.limits.maxProfiles,
                maxRelatedMemories: pack.budget.limits.maxRelatedMemories,
                maxArcs: pack.budget.limits.maxArcs,
                maxReflections: pack.budget.limits.maxReflections,
                maxCorrections: pack.budget.limits.maxCorrections,
                maxAffectHistory: pack.budget.limits.maxAffectHistory,
                selectedProfiles: pack.budget.selectedProfiles,
                selectedRelatedMemories: pack.budget.selectedRelatedMemories,
                selectedArcs: pack.budget.selectedArcs,
                selectedReflections: pack.budget.selectedReflections,
                selectedCorrections: pack.budget.selectedCorrections,
                selectedAffectHistory: pack.budget.selectedAffectHistory,
                droppedByBudget: pack.budget.droppedByBudget,
                droppedByPrivacy: pack.budget.droppedByPrivacy
            ),
            retrievalReport: AnalysisRequestPayload.RetrievalReportPayload(
                semanticSearchStatus: pack.retrieval.semanticSearchStatus,
                retrievalSources: pack.retrieval.retrievalSources,
                candidateMemoryCount: pack.retrieval.candidateMemoryCount,
                fallbackReason: pack.retrieval.fallbackReason
            ),
            builtAt: dateFormatter.string(from: pack.builtAt)
        )
    }
}
