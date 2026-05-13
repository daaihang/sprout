import Foundation

struct PrototypeAnalysisService {
    private let graphUpdater = GraphUpdater()

    struct Result {
        var analyses: [RecordAnalysisSnapshot]
        var entityNodes: [EntityNode]
        var entityEdges: [EntityEdge]
        var artifactEntityLinks: [ArtifactEntityLink]
        var artifacts: [Artifact]
        var lastAnalyzedRecordID: UUID?
    }

    func applyAnalysis(
        _ analysis: RecordAnalysisSnapshot,
        records: [RecordShell],
        analyses: [RecordAnalysisSnapshot],
        artifacts: [Artifact],
        entityNodes: [EntityNode],
        entityEdges: [EntityEdge],
        artifactEntityLinks: [ArtifactEntityLink]
    ) -> Result {
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

        var nextArtifacts = artifacts
        for artifactID in linkedArtifactIDs {
            guard let index = nextArtifacts.firstIndex(where: { $0.id == artifactID }) else { continue }
            nextArtifacts[index].entities = analysis.entities
        }

        return Result(
            analyses: nextAnalyses,
            entityNodes: graphUpdate.entityNodes,
            entityEdges: graphUpdate.entityEdges,
            artifactEntityLinks: graphUpdate.artifactEntityLinks,
            artifacts: nextArtifacts,
            lastAnalyzedRecordID: analysis.recordID
        )
    }
}
