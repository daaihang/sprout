import Foundation

struct ReflectionBuilder {
    func build(record: RecordShell, artifacts: [Artifact], analysis: RecordAnalysisSnapshot) -> ReflectionSnapshot {
        ReflectionSnapshot(
            type: .record,
            title: "Record Reflection",
            body: analysis.summary,
            evidenceSummary: artifacts.map(\.summary).filter { !$0.isEmpty }.joined(separator: " | "),
            confidence: min(max(analysis.salienceScore ?? 0, 0), 1),
            status: .suggested,
            sourceRecordIDs: [record.id],
            sourceArtifactIDs: artifacts.map(\.id),
            sourceEntityIDs: analysis.entityMentions.map(\.id),
            createdAt: analysis.createdAt,
            savedAt: nil,
            dismissedAt: nil
        )
    }
}

struct AnalysisPipelineResult {
    var analyses: [RecordAnalysisSnapshot]
    var entityNodes: [EntityNode]
    var entityEdges: [EntityEdge]
    var artifactEntityLinks: [ArtifactEntityLink]
    var lastAnalyzedRecordID: UUID?
}

struct AnalysisPipeline {
    private let graphUpdater = GraphUpdater()

    func applyAnalysis(
        _ analysis: RecordAnalysisSnapshot,
        records: [RecordShell],
        analyses: [RecordAnalysisSnapshot],
        entityNodes: [EntityNode],
        entityEdges: [EntityEdge],
        artifactEntityLinks: [ArtifactEntityLink]
    ) -> AnalysisPipelineResult {
        var nextAnalyses = analyses
        nextAnalyses.removeAll { $0.recordID == analysis.recordID }
        nextAnalyses.append(analysis)

        let linkedArtifactIDs = records.first(where: { $0.id == analysis.recordID })?.artifactIDs ?? []
        let graphUpdate = graphUpdater.apply(
            analysis: analysis,
            linkedArtifactIDs: linkedArtifactIDs,
            linkedRecordIDs: [analysis.recordID],
            existingEntityNodes: entityNodes,
            existingEntityEdges: entityEdges,
            existingArtifactEntityLinks: artifactEntityLinks
        )

        return AnalysisPipelineResult(
            analyses: nextAnalyses,
            entityNodes: graphUpdate.entityNodes,
            entityEdges: graphUpdate.entityEdges,
            artifactEntityLinks: graphUpdate.artifactEntityLinks,
            lastAnalyzedRecordID: analysis.recordID
        )
    }
}

struct TemporalArcService {
    private let candidateBuilder = TemporalArcCandidateBuilder()
    private let promoter = TemporalArcPromoter()
    private let mergeEngine = TemporalArcMergeEngine()
    private let reflectionBuilder = ArcReflectionBuilder()

    func buildCandidates(
        records: [RecordShell],
        analyses: [RecordAnalysisSnapshot],
        artifacts: [Artifact],
        artifactEntityLinks: [ArtifactEntityLink],
        entityNodes: [EntityNode],
        limit: Int
    ) -> [TemporalArcCandidate] {
        candidateBuilder.buildCandidates(
            records: records,
            analyses: analyses,
            artifacts: artifacts,
            artifactEntityLinks: artifactEntityLinks,
            entityNodes: entityNodes,
            maxCandidates: limit
        )
    }

    struct PromotionResult {
        var arc: TemporalArc
        var reflection: ReflectionSnapshot
    }

    func promote(
        candidate: TemporalArcCandidate,
        analyses: [RecordAnalysisSnapshot],
        artifactEntityLinks: [ArtifactEntityLink],
        entityNodes: [EntityNode]
    ) -> PromotionResult {
        var arc = promoter.promote(
            candidate: candidate,
            analyses: analyses,
            artifactEntityLinks: artifactEntityLinks,
            entityNodes: entityNodes
        )

        let reflection = reflectionBuilder.build(for: arc)
        arc.linkedReflectionID = reflection.id
        return PromotionResult(arc: arc, reflection: reflection)
    }

    func mergePreview(sourceArcID: UUID, arcs: [TemporalArc]) -> TemporalArcMergePreview? {
        guard let baseArc = arcs.first(where: { $0.id == sourceArcID }) else { return nil }
        return arcs
            .filter { $0.id != sourceArcID && $0.status == .accepted }
            .compactMap { mergeEngine.previewMerge(base: baseArc, candidate: $0) }
            .sorted { lhs, rhs in
                if lhs.overlapScore == rhs.overlapScore {
                    return lhs.candidateArcID.uuidString < rhs.candidateArcID.uuidString
                }
                return lhs.overlapScore > rhs.overlapScore
            }
            .first
    }

    struct MergeResult {
        var sourceArc: TemporalArc
        var candidateArc: TemporalArc
        var updatedReflection: ReflectionSnapshot?
        var candidateReflectionIDToRemove: UUID?
    }

    func merge(sourceArc: TemporalArc, candidateArc: TemporalArc, linkedReflection: ReflectionSnapshot?) -> MergeResult {
        let mergedArc = mergeEngine.merge(base: sourceArc, candidate: candidateArc)
        var updatedReflection = linkedReflection
        if updatedReflection != nil {
            updatedReflection?.title = mergedArc.title
            updatedReflection?.body = mergedArc.summary
            updatedReflection?.evidenceSummary = mergedArc.themeLabels.joined(separator: ", ")
            updatedReflection?.linkedTemporalArcID = mergedArc.id
            updatedReflection?.sourceRecordIDs = mergedArc.sourceRecordIDs
            updatedReflection?.sourceArtifactIDs = mergedArc.sourceArtifactIDs
            updatedReflection?.sourceEntityIDs = mergedArc.sourceEntityIDs
        }

        var archivedCandidateArc = candidateArc
        archivedCandidateArc.status = .archived
        archivedCandidateArc.mergedIntoArcID = mergedArc.id
        archivedCandidateArc.lastMergedAt = mergedArc.updatedAt
        archivedCandidateArc.updatedAt = mergedArc.updatedAt

        return MergeResult(
            sourceArc: mergedArc,
            candidateArc: archivedCandidateArc,
            updatedReflection: updatedReflection,
            candidateReflectionIDToRemove: candidateArc.linkedReflectionID
        )
    }
}

private struct ArcReflectionBuilder {
    func build(for arc: TemporalArc) -> ReflectionSnapshot {
        ReflectionSnapshot(
            type: .phase,
            title: arc.title,
            body: arc.summary,
            evidenceSummary: arc.themeLabels.joined(separator: ", "),
            confidence: min(max(arc.clusterStrength, 0), 1),
            status: .suggested,
            linkedTemporalArcID: arc.id,
            sourceRecordIDs: arc.sourceRecordIDs,
            sourceArtifactIDs: arc.sourceArtifactIDs,
            sourceEntityIDs: arc.sourceEntityIDs,
            createdAt: arc.updatedAt,
            savedAt: nil,
            dismissedAt: nil
        )
    }
}