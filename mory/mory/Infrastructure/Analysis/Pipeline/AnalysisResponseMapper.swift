import Foundation

struct AnalysisMappedResult: Sendable {
    var analysis: RecordAnalysisSnapshot
    var affectProposals: [AffectSnapshot]
    var graphDeltaProposals: [GraphDelta]
    var arcProposals: [TemporalArc]
    var reflectionProposals: [ReflectionSnapshot]
    var questionProposals: [ClarificationQuestion]
    var mergeSplitQuestions: [ClarificationQuestion]
    var quality: AnalysisResponseEnvelope.Quality
}

struct AnalysisResponseMapper {
    private let recordSnapshotMapper = RecordAnalysisSnapshotMapper()

    func map(recordID: UUID, response: AnalysisResponseEnvelope, createdAt: Date = .now) -> AnalysisMappedResult {
        AnalysisMappedResult(
            analysis: recordSnapshotMapper.map(recordID: recordID, response: response.analysis, createdAt: createdAt),
            affectProposals: mapAffectProposals(recordID: recordID, response.affectProposals, createdAt: createdAt),
            graphDeltaProposals: mapGraphDeltaProposals(response.graphDeltaProposals, createdAt: createdAt)
                + mapProfileUpdateProposals(response.profileUpdateProposals, createdAt: createdAt),
            arcProposals: mapArcCandidates(response.arcCandidates, createdAt: createdAt),
            reflectionProposals: mapReflectionCandidates(response.reflectionCandidates, createdAt: createdAt),
            questionProposals: mapQuestionCandidates(recordID: recordID, response.questionCandidates, createdAt: createdAt),
            mergeSplitQuestions: mapMergeSplitCandidates(recordID: recordID, response.mergeSplitCandidates, createdAt: createdAt),
            quality: response.quality
        )
    }

    private func mapAffectProposals(
        recordID: UUID,
        _ proposals: [AnalysisResponseEnvelope.AffectProposal],
        createdAt: Date
    ) -> [AffectSnapshot] {
        proposals.map { proposal in
            AffectSnapshot(
                id: proposal.proposalID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                recordID: recordID,
                valence: proposal.valence,
                arousal: proposal.arousal,
                dominance: proposal.dominance,
                intensity: proposal.intensity,
                labels: proposal.labels.compactMap(AffectLabel.init(rawValue:)),
                toneHints: proposal.toneHints.compactMap(ToneHint.init(rawValue:)),
                appraisal: proposal.appraisal,
                sources: [.aiInferredText],
                confidence: proposal.confidence,
                evidence: proposal.evidence.map {
                    AffectEvidence(
                        source: .aiInferredText,
                        summary: $0.snippet,
                        confidence: proposal.confidence,
                        createdAt: createdAt
                    )
                },
                userConfirmed: false,
                needsUserCheck: proposal.requiresConfirmation,
                rawInput: proposal.rawInput,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    private func mapGraphDeltaProposals(
        _ proposals: [AnalysisResponseEnvelope.GraphDeltaProposal],
        createdAt: Date
    ) -> [GraphDelta] {
        proposals.compactMap { proposal in
            let operations = proposal.operations.compactMap(mapOperation)
            guard !operations.isEmpty else { return nil }
            return GraphDelta(
                id: proposal.proposalID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                source: .cloudAI,
                operations: operations,
                confidence: proposal.confidence,
                requiresUserConfirmation: proposal.requiresConfirmation,
                appliedAt: nil,
                createdAt: createdAt
            )
        }
    }

    private func mapProfileUpdateProposals(
        _ proposals: [AnalysisResponseEnvelope.ProfileUpdateProposal],
        createdAt: Date
    ) -> [GraphDelta] {
        proposals.compactMap { proposal in
            guard
                proposal.field == "relationshipToUser",
                let entityID = UUID(uuidString: proposal.targetEntityID)
            else { return nil }
            return GraphDelta(
                id: proposal.proposalID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                source: .cloudAI,
                operations: [
                    GraphDeltaOperation(
                        kind: .setRelationship,
                        targetType: .entity,
                        targetID: entityID,
                        stringValue: proposal.proposedValue,
                        metadata: [
                            "profile_kind": proposal.profileKind,
                            "field": proposal.field,
                            "proposal_source": "analysis"
                        ]
                    )
                ],
                confidence: proposal.confidence,
                requiresUserConfirmation: proposal.requiresConfirmation,
                createdAt: createdAt
            )
        }
    }

    private func mapOperation(_ operation: AnalysisResponseEnvelope.GraphDeltaProposal.Operation) -> GraphDeltaOperation? {
        guard
            let kind = GraphDeltaOperationKind(rawValue: operation.kind),
            let targetType = ClarificationTargetType(rawValue: operation.targetType),
            let targetID = UUID(uuidString: operation.targetID)
        else { return nil }
        return GraphDeltaOperation(
            kind: kind,
            targetType: targetType,
            targetID: targetID,
            relatedID: operation.relatedID.flatMap(UUID.init(uuidString:)),
            stringValue: operation.stringValue,
            numericValue: operation.numericValue,
            metadata: operation.metadata
        )
    }

    private func mapReflectionCandidates(
        _ candidates: [AnalysisResponseEnvelope.ReflectionCandidate],
        createdAt: Date
    ) -> [ReflectionSnapshot] {
        candidates.map { candidate in
            ReflectionSnapshot(
                id: candidate.candidateID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                type: .record,
                title: candidate.title,
                body: candidate.body,
                evidenceSummary: candidate.evidenceSummary,
                confidence: candidate.confidence,
                status: .suggested,
                linkedTemporalArcID: nil,
                sourceRecordIDs: candidate.sourceRecordIDs.compactMap(UUID.init(uuidString:)),
                sourceArtifactIDs: candidate.sourceArtifactIDs.compactMap(UUID.init(uuidString:)),
                sourceEntityIDs: candidate.sourceEntityIDs.compactMap(UUID.init(uuidString:)),
                createdAt: createdAt
            )
        }
    }

    private func mapArcCandidates(
        _ candidates: [AnalysisResponseEnvelope.ArcCandidate],
        createdAt: Date
    ) -> [TemporalArc] {
        candidates.compactMap { candidate in
            let sourceRecordIDs = candidate.sourceRecordIDs.compactMap(UUID.init(uuidString:))
            guard !sourceRecordIDs.isEmpty else { return nil }
            return TemporalArc(
                id: candidate.candidateID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                title: candidate.title,
                summary: candidate.summary,
                status: .candidate,
                sourceRecordIDs: sourceRecordIDs,
                sourceArtifactIDs: [],
                sourceEntityIDs: [],
                startDate: createdAt,
                endDate: createdAt,
                intensityScore: candidate.confidence ?? 0,
                clusterStrength: candidate.confidence ?? 0,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    private func mapQuestionCandidates(
        recordID: UUID,
        _ candidates: [AnalysisResponseEnvelope.QuestionCandidate],
        createdAt: Date
    ) -> [ClarificationQuestion] {
        candidates.map { candidate in
            makeQuestion(
                recordID: recordID,
                kind: ClarificationQuestionKind(rawValue: candidate.kind) ?? .dailyReflection,
                prompt: candidate.prompt,
                reason: candidate.reason,
                targetType: candidate.targetType.flatMap(ClarificationTargetType.init(rawValue:)) ?? .record,
                targetID: candidate.targetID.flatMap(UUID.init(uuidString:)) ?? recordID,
                sourceRecordIDs: candidate.sourceRecordIDs.compactMap(UUID.init(uuidString:)),
                sourceArtifactIDs: candidate.sourceArtifactIDs.compactMap(UUID.init(uuidString:)),
                candidateAnswers: candidate.candidateAnswers,
                priority: candidate.confidence,
                sensitivity: QuestionSensitivity(rawValue: candidate.sensitivity) ?? .normal,
                createdAt: createdAt
            )
        }
    }

    private func mapMergeSplitCandidates(
        recordID: UUID,
        _ candidates: [AnalysisResponseEnvelope.MergeSplitCandidate],
        createdAt: Date
    ) -> [ClarificationQuestion] {
        candidates.compactMap { candidate in
            guard let prompt = candidate.question?.trimmedOrNil else { return nil }
            let targetID = candidate.targetEntityID.flatMap(UUID.init(uuidString:))
                ?? candidate.sourceEntityIDs.compactMap(UUID.init(uuidString:)).first
                ?? recordID
            return makeQuestion(
                recordID: recordID,
                kind: candidate.kind.contains("split") ? .entityAlias : .entityMerge,
                prompt: prompt,
                reason: "Analysis identity candidate with confidence \(candidate.confidence ?? 0).",
                targetType: .entity,
                targetID: targetID,
                sourceRecordIDs: [recordID],
                sourceArtifactIDs: [],
                candidateAnswers: ["same person", "not the same", "not sure"],
                priority: candidate.confidence ?? 0,
                sensitivity: .personal,
                createdAt: createdAt
            )
        }
    }

    private func makeQuestion(
        recordID: UUID,
        kind: ClarificationQuestionKind,
        prompt: String,
        reason: String,
        targetType: ClarificationTargetType,
        targetID: UUID,
        sourceRecordIDs: [UUID],
        sourceArtifactIDs: [UUID],
        candidateAnswers: [String],
        priority: Double,
        sensitivity: QuestionSensitivity,
        createdAt: Date
    ) -> ClarificationQuestion {
        ClarificationQuestion(
            kind: kind,
            prompt: prompt,
            targetType: targetType,
            targetID: targetID,
            sourceRecordIDs: sourceRecordIDs.isEmpty ? [recordID] : sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            candidateAnswers: candidateAnswers.map { ClarificationAnswerOption(label: $0) },
            priority: priority,
            reason: reason,
            sensitivity: sensitivity,
            createdAt: createdAt
        )
    }
}
