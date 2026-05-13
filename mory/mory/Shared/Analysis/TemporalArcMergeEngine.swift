import Foundation

struct TemporalArcMergePreview: Sendable {
    var sourceArcID: UUID
    var candidateArcID: UUID
    var overlapScore: Double
}

struct TemporalArcMergeEngine {
    private let maximumMergeWindow: TimeInterval = 60 * 60 * 24 * 21
    private let minimumMergeScore = 0.42

    func previewMerge(base: TemporalArc, candidate: TemporalArc) -> TemporalArcMergePreview? {
        let overlap = overlapScore(base: base, candidate: candidate)
        guard overlap >= minimumMergeScore else { return nil }

        return TemporalArcMergePreview(
            sourceArcID: base.id,
            candidateArcID: candidate.id,
            overlapScore: overlap
        )
    }

    func merge(base: TemporalArc, candidate: TemporalArc, mergedAt: Date = .now) -> TemporalArc {
        let mergedThemeLabels = mergeOrderedValues(base.themeLabels, candidate.themeLabels)
        let mergedEntityNames = mergeOrderedValues(base.entityNames, candidate.entityNames)
        let mergedRecordIDs = mergeUniqueIDs(base.sourceRecordIDs, candidate.sourceRecordIDs)
        let mergedArtifactIDs = mergeUniqueIDs(base.sourceArtifactIDs, candidate.sourceArtifactIDs)
        let mergedEntityIDs = mergeUniqueIDs(base.sourceEntityIDs, candidate.sourceEntityIDs)

        let dominantTheme = mergedThemeLabels.first ?? base.dominantTheme ?? candidate.dominantTheme
        let dominantEntity = mergedEntityNames.first ?? base.dominantEntityName ?? candidate.dominantEntityName
        let mergedTitle = buildMergedTitle(
            base: base,
            candidate: candidate,
            dominantTheme: dominantTheme,
            dominantEntity: dominantEntity
        )
        let mergedSummary = buildMergedSummary(
            dominantTheme: dominantTheme,
            dominantEntity: dominantEntity,
            recordCount: mergedRecordIDs.count,
            startDate: min(base.startDate, candidate.startDate),
            endDate: max(base.endDate, candidate.endDate)
        )

        return TemporalArc(
            id: base.id,
            title: mergedTitle,
            summary: mergedSummary,
            status: .accepted,
            dominantTheme: dominantTheme,
            dominantEntityName: dominantEntity,
            themeLabels: mergedThemeLabels,
            entityNames: mergedEntityNames,
            linkedReflectionID: base.linkedReflectionID,
            mergedFromArcIDs: mergeUniqueIDs(base.mergedFromArcIDs + [candidate.id], candidate.mergedFromArcIDs),
            mergedIntoArcID: nil,
            lastMergedAt: mergedAt,
            sourceRecordIDs: mergedRecordIDs,
            sourceArtifactIDs: mergedArtifactIDs,
            sourceEntityIDs: mergedEntityIDs,
            startDate: min(base.startDate, candidate.startDate),
            endDate: max(base.endDate, candidate.endDate),
            intensityScore: max(base.intensityScore, candidate.intensityScore) + overlapScore(base: base, candidate: candidate),
            clusterStrength: max(base.clusterStrength, candidate.clusterStrength),
            createdAt: min(base.createdAt, candidate.createdAt),
            updatedAt: mergedAt
        )
    }

    func overlapScore(base: TemporalArc, candidate: TemporalArc) -> Double {
        let recordOverlap = overlapScore(base.sourceRecordIDs, candidate.sourceRecordIDs)
        let themeOverlap = overlapScore(base.themeLabels, candidate.themeLabels)
        let entityOverlap = overlapScore(base.entityNames, candidate.entityNames)
        let timeOverlap = timeProximityScore(base: base, candidate: candidate)

        return recordOverlap * 0.40
            + themeOverlap * 0.25
            + entityOverlap * 0.20
            + timeOverlap * 0.15
    }

    private func overlapScore<T: Hashable>(_ lhs: [T], _ rhs: [T]) -> Double {
        let left = Set(lhs)
        let right = Set(rhs)
        guard !left.isEmpty || !right.isEmpty else { return 0 }
        let intersection = left.intersection(right).count
        let union = left.union(right).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }

    private func timeProximityScore(base: TemporalArc, candidate: TemporalArc) -> Double {
        let earliest = min(base.startDate, candidate.startDate)
        let latest = max(base.endDate, candidate.endDate)
        let span = latest.timeIntervalSince(earliest)
        if span >= maximumMergeWindow { return 0 }
        return max(0, 1 - span / maximumMergeWindow)
    }

    private func mergeOrderedValues(_ lhs: [String], _ rhs: [String]) -> [String] {
        Array(NSOrderedSet(array: lhs + rhs)) as? [String] ?? Array(Set(lhs + rhs)).sorted()
    }

    private func mergeUniqueIDs(_ lhs: [UUID], _ rhs: [UUID]) -> [UUID] {
        Array(NSOrderedSet(array: lhs + rhs)) as? [UUID] ?? Array(Set(lhs + rhs))
    }

    private func buildMergedTitle(
        base: TemporalArc,
        candidate: TemporalArc,
        dominantTheme: String?,
        dominantEntity: String?
    ) -> String {
        if let dominantTheme, let dominantEntity {
            return "\(dominantTheme) around \(dominantEntity)"
        }
        if let dominantTheme {
            return dominantTheme
        }
        if let dominantEntity {
            return dominantEntity
        }
        return base.title.count >= candidate.title.count ? base.title : candidate.title
    }

    private func buildMergedSummary(
        dominantTheme: String?,
        dominantEntity: String?,
        recordCount: Int,
        startDate: Date,
        endDate: Date
    ) -> String {
        let rangeText = "\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))"
        if let dominantTheme, let dominantEntity {
            return "Merged phase across \(recordCount) records, centered on \(dominantTheme) and anchored by \(dominantEntity) (\(rangeText))."
        }
        if let dominantTheme {
            return "Merged phase across \(recordCount) records, centered on \(dominantTheme) (\(rangeText))."
        }
        return "Merged phase across \(recordCount) records (\(rangeText))."
    }
}
