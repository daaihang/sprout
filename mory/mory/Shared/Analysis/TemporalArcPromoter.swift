import Foundation

struct TemporalArcPromoter {
    func promote(
        candidate: TemporalArcCandidate,
        analyses: [RecordAnalysisSnapshot],
        artifactEntityLinks: [ArtifactEntityLink],
        entityNodes: [EntityNode],
        existingArcID: UUID? = nil,
        createdAt: Date = .now
    ) -> TemporalArc {
        let analysisIndex = Dictionary(uniqueKeysWithValues: analyses.map { ($0.recordID, $0) })
        let entityIndex = Dictionary(uniqueKeysWithValues: entityNodes.map { ($0.id, $0) })

        let sourceEntityIDs = Array(
            Set(
                artifactEntityLinks
                    .filter { candidate.artifactIDs.contains($0.artifactID) }
                    .map(\.entityID)
            )
        )
        .sorted { lhs, rhs in
            let left = entityIndex[lhs]?.displayName ?? ""
            let right = entityIndex[rhs]?.displayName ?? ""
            return left.localizedStandardCompare(right) == .orderedAscending
        }

        let emotionLabels = candidate.recordIDs.compactMap { analysisIndex[$0]?.emotionLabel }
        let dominantEmotion = mostFrequentValue(in: emotionLabels)
        let summary = buildSummary(candidate: candidate, dominantEmotion: dominantEmotion)

        return TemporalArc(
            id: existingArcID ?? UUID(),
            title: candidate.titleHint,
            summary: summary,
            status: .accepted,
            dominantTheme: candidate.dominantTheme,
            dominantEntityName: candidate.dominantEntityName,
            themeLabels: candidate.themeLabels,
            entityNames: candidate.entityNames,
            linkedReflectionID: nil,
            mergedFromArcIDs: [],
            mergedIntoArcID: nil,
            lastMergedAt: nil,
            sourceRecordIDs: candidate.recordIDs,
            sourceArtifactIDs: candidate.artifactIDs,
            sourceEntityIDs: sourceEntityIDs,
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            intensityScore: candidate.intensityScore,
            clusterStrength: candidate.clusterStrength,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private func buildSummary(candidate: TemporalArcCandidate, dominantEmotion: String?) -> String {
        let themeText = candidate.themeLabels.prefix(2).joined(separator: ", ")
        let entityText = candidate.entityNames.prefix(2).joined(separator: ", ")
        let emotionText = dominantEmotion ?? "mixed"

        if !themeText.isEmpty && !entityText.isEmpty {
            return "A \(emotionText) phase centered on \(themeText), anchored by \(entityText)."
        }
        if !themeText.isEmpty {
            return "A \(emotionText) phase centered on \(themeText)."
        }
        if !entityText.isEmpty {
            return "A \(emotionText) phase shaped by \(entityText)."
        }
        return "A recurring phase candidate promoted from clustered records."
    }

    private func mostFrequentValue(in values: [String]) -> String? {
        values
            .reduce(into: [:]) { partialResult, value in
                partialResult[value, default: 0] += 1
            }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .first?
            .key
    }
}
