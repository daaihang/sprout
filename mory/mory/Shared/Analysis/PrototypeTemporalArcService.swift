import Foundation

struct PrototypeTemporalArcService {
    private let candidateBuilder = TemporalArcCandidateBuilder()
    private let promoter = TemporalArcPromoter()
    private let mergeEngine = TemporalArcMergeEngine()

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

        let reflection = ReflectionSnapshot(
            type: .phase,
            title: arc.title,
            body: arc.summary,
            linkedTemporalArcID: arc.id,
            sourceRecordIDs: arc.sourceRecordIDs,
            sourceArtifactIDs: arc.sourceArtifactIDs,
            sourceEntityIDs: arc.sourceEntityIDs,
            createdAt: arc.updatedAt
        )
        arc.linkedReflectionID = reflection.id

        return PromotionResult(arc: arc, reflection: reflection)
    }

    func mergePreview(
        sourceArcID: UUID,
        arcs: [TemporalArc]
    ) -> TemporalArcMergePreview? {
        guard let baseArc = arcs.first(where: { $0.id == sourceArcID }) else { return nil }

        return arcs
            .filter { $0.id != sourceArcID && $0.status == .accepted }
            .compactMap { candidateArc in
                mergeEngine.previewMerge(base: baseArc, candidate: candidateArc)
            }
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

    func merge(
        sourceArc: TemporalArc,
        candidateArc: TemporalArc,
        linkedReflection: ReflectionSnapshot?
    ) -> MergeResult {
        let mergedArc = mergeEngine.merge(base: sourceArc, candidate: candidateArc)

        var updatedReflection = linkedReflection
        if updatedReflection != nil {
            updatedReflection?.title = mergedArc.title
            updatedReflection?.body = mergedArc.summary
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
