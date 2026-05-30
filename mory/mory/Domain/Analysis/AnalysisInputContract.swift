import Foundation

struct AnalysisInputContract: Hashable, Sendable {
    static let schemaVersion = "analysis_input.record_fact.v1"
    static let arrangementExclusionReason = "MemoryCardArrangement is a user-authored visual layout and is not part of the semantic analysis input."

    var schemaVersion: String
    var record: RecordShell
    var artifacts: [Artifact]
    var semanticDigests: [ArtifactSemanticDigest]

    init(
        schemaVersion: String = AnalysisInputContract.schemaVersion,
        record: RecordShell,
        artifacts: [Artifact],
        semanticDigests: [ArtifactSemanticDigest]
    ) {
        self.schemaVersion = schemaVersion
        self.record = record
        self.artifacts = artifacts
        self.semanticDigests = semanticDigests
    }
}

struct AnalysisInputContractBuilder {
    func build(from detail: MemoryDetailSnapshot) -> AnalysisInputContract {
        AnalysisInputContract(
            record: detail.record,
            artifacts: orderedArtifacts(in: detail),
            semanticDigests: orderedSemanticDigests(in: detail)
        )
    }

    private func orderedArtifacts(in detail: MemoryDetailSnapshot) -> [Artifact] {
        let artifactByID = Dictionary(uniqueKeysWithValues: detail.artifacts.map { ($0.id, $0) })
        let ordered = detail.record.artifactIDs.compactMap { artifactByID[$0] }
        let orderedIDs = Set(ordered.map(\.id))
        let remaining = detail.artifacts
            .filter { !orderedIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        return ordered + remaining
    }

    private func orderedSemanticDigests(in detail: MemoryDetailSnapshot) -> [ArtifactSemanticDigest] {
        let artifactOrder = Dictionary(uniqueKeysWithValues: orderedArtifacts(in: detail).enumerated().map { ($0.element.id, $0.offset) })
        return detail.artifactSemanticDigests.sorted { lhs, rhs in
            let lhsOrder = artifactOrder[lhs.artifactID] ?? Int.max
            let rhsOrder = artifactOrder[rhs.artifactID] ?? Int.max
            if lhsOrder == rhsOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhsOrder < rhsOrder
        }
    }
}
