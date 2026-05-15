import Foundation

struct TemporalArcCandidate: Identifiable, Sendable {
    let id: UUID
    var titleHint: String
    var themeLabels: [String]
    var entityNames: [String]
    var recordIDs: [UUID]
    var artifactIDs: [UUID]
    var startDate: Date
    var endDate: Date
    var intensityScore: Double
    var clusterStrength: Double
    var dominantTheme: String?
    var dominantEntityName: String?

    init(
        id: UUID = UUID(),
        titleHint: String,
        themeLabels: [String],
        entityNames: [String],
        recordIDs: [UUID],
        artifactIDs: [UUID],
        startDate: Date,
        endDate: Date,
        intensityScore: Double,
        clusterStrength: Double,
        dominantTheme: String? = nil,
        dominantEntityName: String? = nil
    ) {
        self.id = id
        self.titleHint = titleHint
        self.themeLabels = themeLabels
        self.entityNames = entityNames
        self.recordIDs = recordIDs
        self.artifactIDs = artifactIDs
        self.startDate = startDate
        self.endDate = endDate
        self.intensityScore = intensityScore
        self.clusterStrength = clusterStrength
        self.dominantTheme = dominantTheme
        self.dominantEntityName = dominantEntityName
    }
}

struct TemporalArcCandidateBuilder {
    private let clusteringWindow: TimeInterval = 60 * 60 * 24 * 14
    private let maximumRecordGap: TimeInterval = 60 * 60 * 24 * 10
    private let minimumSeedSimilarity = 0.33
    private let minimumExpansionSimilarity = 0.22

    func buildCandidates(
        records: [RecordShell],
        analyses: [RecordAnalysisSnapshot],
        artifacts: [Artifact],
        artifactEntityLinks: [ArtifactEntityLink],
        entityNodes: [EntityNode],
        maxCandidates: Int
    ) -> [TemporalArcCandidate] {
        let artifactIndex = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        let analysisIndex = Dictionary(uniqueKeysWithValues: analyses.map { ($0.recordID, $0) })
        let entityIndex = Dictionary(uniqueKeysWithValues: entityNodes.map { ($0.id, $0) })

        let recordContexts = records
            .sorted { $0.updatedAt < $1.updatedAt }
            .map {
                buildContext(
                    record: $0,
                    analysis: analysisIndex[$0.id],
                    artifactEntityLinks: artifactEntityLinks,
                    entityIndex: entityIndex,
                    artifactIndex: artifactIndex
                )
            }

        guard !recordContexts.isEmpty else { return [] }

        var consumedRecordIDs = Set<UUID>()
        var candidates: [TemporalArcCandidate] = []

        for context in recordContexts {
            guard !consumedRecordIDs.contains(context.record.id) else { continue }
            var cluster = [context]
            consumedRecordIDs.insert(context.record.id)

            for candidate in recordContexts {
                guard !consumedRecordIDs.contains(candidate.record.id) else { continue }
                guard abs(candidate.record.updatedAt.timeIntervalSince(context.record.updatedAt)) <= clusteringWindow else { continue }
                guard isCloseEnough(candidate.record, toAnyOf: cluster.map(\.record)) else { continue }

                let similarity = similarityScore(between: cluster, and: candidate)
                if cluster.count == 1 {
                    guard similarity >= minimumSeedSimilarity else { continue }
                } else {
                    guard similarity >= minimumExpansionSimilarity else { continue }
                }

                cluster.append(candidate)
                consumedRecordIDs.insert(candidate.record.id)
            }

            if let fallback = bestAdjacentPair(for: context, within: recordContexts, excluding: consumedRecordIDs) {
                cluster.append(fallback)
                consumedRecordIDs.insert(fallback.record.id)
            }

            if let candidate = buildCandidate(from: cluster) {
                candidates.append(candidate)
            }
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.intensityScore == rhs.intensityScore {
                    return lhs.endDate > rhs.endDate
                }
                return lhs.intensityScore > rhs.intensityScore
            }
            .prefix(maxCandidates)
            .map { $0 }
    }

    private func buildContext(
        record: RecordShell,
        analysis: RecordAnalysisSnapshot?,
        artifactEntityLinks: [ArtifactEntityLink],
        entityIndex: [UUID: EntityNode],
        artifactIndex: [UUID: Artifact]
    ) -> RecordContext {
        let artifactIDs = Set(record.artifactIDs)
        let linkedEntityIDs = Set(
            artifactEntityLinks
                .filter { artifactIDs.contains($0.artifactID) }
                .map(\.entityID)
        )
        let entityNames = linkedEntityIDs.compactMap { entityIndex[$0]?.displayName }.sorted()
        let themeLabels = Array(Set(analysis?.themes ?? [])).sorted()
        let textBag = buildTextBag(
            recordText: record.rawText,
            artifactTexts: record.artifactIDs.compactMap { artifactIndex[$0]?.summary }
        )

        return RecordContext(
            record: record,
            artifactIDs: Array(artifactIDs),
            themeLabels: themeLabels,
            entityIDs: linkedEntityIDs,
            entityNames: entityNames,
            textBag: textBag,
            salienceScore: analysis?.salienceScore ?? 0.25
        )
    }

    private func buildCandidate(from cluster: [RecordContext]) -> TemporalArcCandidate? {
        let sortedCluster = cluster.sorted { $0.record.updatedAt < $1.record.updatedAt }
        guard let first = sortedCluster.first, let last = sortedCluster.last else { return nil }

        let recordIDs = sortedCluster.map(\.record.id)
        let artifactIDs = Array(Set(sortedCluster.flatMap(\.artifactIDs)))
        let themeFrequency = frequencyMap(for: sortedCluster.flatMap(\.themeLabels))
        let entityFrequency = frequencyMap(for: sortedCluster.flatMap(\.entityNames))
        let themeLabels = themeFrequency.keys.sorted {
            if themeFrequency[$0] == themeFrequency[$1] { return $0 < $1 }
            return (themeFrequency[$0] ?? 0) > (themeFrequency[$1] ?? 0)
        }
        let entityNames = entityFrequency.keys.sorted {
            if entityFrequency[$0] == entityFrequency[$1] { return $0 < $1 }
            return (entityFrequency[$0] ?? 0) > (entityFrequency[$1] ?? 0)
        }

        let clusterStrength = averageClusterStrength(for: sortedCluster)
        let averageSalience = sortedCluster.map(\.salienceScore).reduce(0, +) / Double(sortedCluster.count)
        let intensityScore = scoreCandidate(
            recordCount: sortedCluster.count,
            artifactCount: artifactIDs.count,
            entityCount: entityNames.count,
            themeCount: themeLabels.count,
            clusterStrength: clusterStrength,
            duration: last.record.updatedAt.timeIntervalSince(first.record.updatedAt),
            averageSalience: averageSalience
        )

        guard intensityScore > 0 else { return nil }

        return TemporalArcCandidate(
            titleHint: buildTitleHint(themeLabels: themeLabels, entityNames: entityNames),
            themeLabels: themeLabels,
            entityNames: entityNames,
            recordIDs: recordIDs,
            artifactIDs: artifactIDs,
            startDate: first.record.updatedAt,
            endDate: last.record.updatedAt,
            intensityScore: intensityScore,
            clusterStrength: clusterStrength,
            dominantTheme: themeLabels.first,
            dominantEntityName: entityNames.first
        )
    }

    private func bestAdjacentPair(
        for context: RecordContext,
        within contexts: [RecordContext],
        excluding consumedRecordIDs: Set<UUID>
    ) -> RecordContext? {
        contexts
            .filter {
                $0.record.id != context.record.id &&
                !consumedRecordIDs.contains($0.record.id) &&
                abs($0.record.updatedAt.timeIntervalSince(context.record.updatedAt)) <= maximumRecordGap
            }
            .map { ($0, pairSimilarity(between: context, and: $0)) }
            .filter { $0.1 >= 0.45 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0.record.updatedAt < rhs.0.record.updatedAt }
                return lhs.1 > rhs.1
            }
            .first?
            .0
    }

    private func similarityScore(between cluster: [RecordContext], and candidate: RecordContext) -> Double {
        let pairScores = cluster.map { pairSimilarity(between: $0, and: candidate) }
        guard !pairScores.isEmpty else { return 0 }
        return pairScores.reduce(0, +) / Double(pairScores.count)
    }

    private func pairSimilarity(between lhs: RecordContext, and rhs: RecordContext) -> Double {
        let themeOverlap = overlapScore(lhs.themeLabels, rhs.themeLabels)
        let entityOverlap = overlapScore(Array(lhs.entityIDs), Array(rhs.entityIDs))
        let textOverlap = overlapScore(Array(lhs.textBag), Array(rhs.textBag))
        let timeProximity = timeProximityScore(lhs.record.updatedAt, rhs.record.updatedAt)
        return themeOverlap * 0.35 + entityOverlap * 0.35 + textOverlap * 0.10 + timeProximity * 0.20
    }

    private func isCloseEnough(_ record: RecordShell, toAnyOf clusterRecords: [RecordShell]) -> Bool {
        clusterRecords.contains { abs(record.updatedAt.timeIntervalSince($0.updatedAt)) <= maximumRecordGap }
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

    private func timeProximityScore(_ lhs: Date, _ rhs: Date) -> Double {
        let gap = abs(lhs.timeIntervalSince(rhs))
        if gap >= clusteringWindow { return 0 }
        return max(0, 1 - gap / clusteringWindow)
    }

    private func averageClusterStrength(for cluster: [RecordContext]) -> Double {
        guard cluster.count > 1 else { return 0.35 }
        var scores: [Double] = []
        for leftIndex in cluster.indices {
            for rightIndex in cluster.indices where rightIndex > leftIndex {
                scores.append(pairSimilarity(between: cluster[leftIndex], and: cluster[rightIndex]))
            }
        }
        guard !scores.isEmpty else { return 0.35 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private func buildTextBag(recordText: String, artifactTexts: [String]) -> Set<String> {
        let corpus = ([recordText] + artifactTexts).joined(separator: " ").lowercased()
        let tokens = corpus
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }
        return Set(tokens)
    }

    private func frequencyMap(for values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { partialResult, value in
            partialResult[value, default: 0] += 1
        }
    }

    private func scoreCandidate(
        recordCount: Int,
        artifactCount: Int,
        entityCount: Int,
        themeCount: Int,
        clusterStrength: Double,
        duration: TimeInterval,
        averageSalience: Double
    ) -> Double {
        let durationDays = duration / (60 * 60 * 24)
        let durationScore = min(max(durationDays / 7, 0), 2.5)
        return Double(recordCount) * 1.4
            + Double(artifactCount) * 0.6
            + Double(entityCount) * 0.45
            + Double(themeCount) * 0.4
            + clusterStrength * 2.2
            + durationScore
            + averageSalience * 2.0
    }

    private func buildTitleHint(themeLabels: [String], entityNames: [String]) -> String {
        let themePart = themeLabels.prefix(2).joined(separator: " / ")
        let entityPart = entityNames.prefix(1).joined(separator: "")
        if !themePart.isEmpty && !entityPart.isEmpty { return "\(themePart) around \(entityPart)" }
        if !themePart.isEmpty { return themePart }
        if !entityPart.isEmpty { return entityPart }
        return "Emerging Phase"
    }
}

private struct RecordContext {
    var record: RecordShell
    var artifactIDs: [UUID]
    var themeLabels: [String]
    var entityIDs: Set<UUID>
    var entityNames: [String]
    var textBag: Set<String>
    var salienceScore: Double
}