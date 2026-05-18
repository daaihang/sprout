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
    var averageSalience: Double
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
        averageSalience: Double,
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
        self.averageSalience = averageSalience
        self.dominantTheme = dominantTheme
        self.dominantEntityName = dominantEntityName
    }
}

struct TemporalArcCandidateBuilder {
    private let clusteringWindow: TimeInterval = 60 * 60 * 24 * 14
    private let maximumRecordGap: TimeInterval = 60 * 60 * 24 * 10
    private let minimumSeedSimilarity = 0.33
    private let minimumExpansionSimilarity = 0.22
    private let minimumFallbackSalience = 0.5
    private let entityQualityPolicy = EntityQualityPolicy()
    private let stopwords: Set<String> = [
        "about", "after", "again", "around", "before", "current", "during", "first", "from",
        "have", "into", "keep", "landed", "later", "need", "note", "notes", "same",
        "that", "their", "there", "this", "three", "told", "with", "work"
    ]

    func buildCandidates(
        records: [RecordShell],
        analyses: [RecordAnalysisSnapshot],
        artifacts: [Artifact],
        artifactEntityLinks: [ArtifactEntityLink],
        entityNodes: [EntityNode],
        focusRecordID: UUID? = nil,
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

        if let focusRecordID, let focus = recordContexts.first(where: { $0.record.id == focusRecordID }) {
            var cluster = [focus]
            for candidate in recordContexts where candidate.record.id != focusRecordID {
                guard abs(candidate.record.updatedAt.timeIntervalSince(focus.record.updatedAt)) <= clusteringWindow else { continue }
                guard isCloseEnough(candidate.record, toAnyOf: [focus.record]) else { continue }

                let similarity = similarityScore(between: cluster, and: candidate)
                if cluster.count == 1 {
                    guard similarity >= minimumSeedSimilarity else { continue }
                } else {
                    guard similarity >= minimumExpansionSimilarity else { continue }
                }
                cluster.append(candidate)
            }

            if cluster.count == 1,
               let fallback = bestAdjacentPair(for: focus, within: recordContexts, excluding: [focus.record.id]) {
                cluster.append(fallback)
            }

            if cluster.count == 1 {
                let fallbackCluster = recurringFallbackCluster(for: focus, within: recordContexts)
                cluster.append(contentsOf: fallbackCluster)
            }

            if cluster.count < 3 {
                let existingIDs = Set(cluster.map(\.record.id))
                let semanticCluster = semanticRecurringCluster(for: focus, within: recordContexts, excluding: existingIDs)
                cluster.append(contentsOf: semanticCluster)
            }

            return buildCandidate(from: cluster).map { [$0] } ?? []
        }

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
        let themeLabels = Array(Set((analysis?.themes ?? []).filter(entityQualityPolicy.usefulThemeLabel))).sorted()
        let textBag = buildTextBag(
            recordText: record.rawText,
            artifactTexts: record.artifactIDs.compactMap { artifactIndex[$0]?.summary }
        )

        let rawSalienceScore = analysis?.salienceScore ?? 0.25

        return RecordContext(
            record: record,
            artifactIDs: Array(artifactIDs),
            themeLabels: themeLabels,
            entityIDs: linkedEntityIDs,
            entityNames: entityNames,
            textBag: textBag,
            salienceScore: adjustedSalienceScore(
                rawSalienceScore,
                entityNames: entityNames,
                textBag: textBag
            )
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

        let clusterStrength = adjustedClusterStrength(for: sortedCluster)
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
            averageSalience: averageSalience,
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
        let entityIDOverlap = overlapScore(Array(lhs.entityIDs), Array(rhs.entityIDs))
        let entityNameOverlap = overlapScore(lhs.entityNames.map(normalizeAnchor), rhs.entityNames.map(normalizeAnchor))
        let entityOverlap = max(entityIDOverlap, entityNameOverlap)
        let textOverlap = overlapScore(Array(lhs.textBag), Array(rhs.textBag))
        let timeProximity = timeProximityScore(lhs.record.updatedAt, rhs.record.updatedAt)
        return themeOverlap * 0.35 + entityOverlap * 0.35 + textOverlap * 0.10 + timeProximity * 0.20
    }

    private func recurringFallbackCluster(for focus: RecordContext, within contexts: [RecordContext]) -> [RecordContext] {
        contexts
            .filter {
                $0.record.id != focus.record.id &&
                    abs($0.record.updatedAt.timeIntervalSince(focus.record.updatedAt)) <= maximumRecordGap &&
                    hasRecurringAnchor(between: focus, and: $0)
            }
            .sorted { lhs, rhs in
                let leftSimilarity = pairSimilarity(between: focus, and: lhs)
                let rightSimilarity = pairSimilarity(between: focus, and: rhs)
                if leftSimilarity == rightSimilarity {
                    return lhs.record.updatedAt > rhs.record.updatedAt
                }
                return leftSimilarity > rightSimilarity
            }
            .prefix(4)
            .map { $0 }
    }

    private func semanticRecurringCluster(
        for focus: RecordContext,
        within contexts: [RecordContext],
        excluding excludedIDs: Set<UUID>
    ) -> [RecordContext] {
        contexts
            .filter {
                $0.record.id != focus.record.id &&
                    !excludedIDs.contains($0.record.id) &&
                    focus.salienceScore >= 0.65 &&
                    $0.salienceScore >= 0.35 &&
                    recurringAnchorCount(between: focus, and: $0) >= 2
            }
            .sorted { lhs, rhs in
                let leftCount = recurringAnchorCount(between: focus, and: lhs)
                let rightCount = recurringAnchorCount(between: focus, and: rhs)
                if leftCount == rightCount {
                    return lhs.salienceScore > rhs.salienceScore
                }
                return leftCount > rightCount
            }
            .prefix(4)
            .map { $0 }
    }

    private func hasRecurringAnchor(between lhs: RecordContext, and rhs: RecordContext) -> Bool {
        guard lhs.salienceScore >= minimumFallbackSalience, rhs.salienceScore >= minimumFallbackSalience else { return false }

        let sharedThemes = Set(lhs.themeLabels.map(normalizeAnchor)).intersection(Set(rhs.themeLabels.map(normalizeAnchor)))
        if !sharedThemes.isEmpty { return true }

        let sharedEntities = Set(lhs.entityNames.map(normalizeAnchor)).intersection(Set(rhs.entityNames.map(normalizeAnchor)))
        if !sharedEntities.isEmpty { return true }

        return lhs.textBag.intersection(rhs.textBag).count >= 2
    }

    private func recurringAnchorCount(between lhs: RecordContext, and rhs: RecordContext) -> Int {
        let leftAnchors = semanticAnchors(for: lhs)
        let rightAnchors = semanticAnchors(for: rhs)
        return leftAnchors.intersection(rightAnchors).count
    }

    private func recurringAnchorFrequency(in cluster: [RecordContext]) -> [String: Int] {
        cluster.reduce(into: [:]) { partialResult, context in
            for anchor in semanticAnchors(for: context) {
                partialResult[anchor, default: 0] += 1
            }
        }
    }

    private func semanticAnchors(for context: RecordContext) -> Set<String> {
        let themeAnchors = context.themeLabels.flatMap { anchorTokens(from: $0) }
        let entityAnchors = context.entityNames.flatMap { anchorTokens(from: $0) }
        return Set(themeAnchors + entityAnchors).union(context.textBag)
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

    private func adjustedClusterStrength(for cluster: [RecordContext]) -> Double {
        let baseStrength = averageClusterStrength(for: cluster)
        guard cluster.count >= 3 else { return baseStrength }
        let averageSalience = cluster.map(\.salienceScore).reduce(0, +) / Double(cluster.count)
        guard averageSalience >= 0.55 else { return baseStrength }
        let recurringAnchors = recurringAnchorFrequency(in: cluster).filter { $0.value >= 2 }
        guard recurringAnchors.count >= 2 else { return baseStrength }
        return max(baseStrength, 0.42)
    }

    private func buildTextBag(recordText: String, artifactTexts: [String]) -> Set<String> {
        let corpus = ([recordText] + artifactTexts).joined(separator: " ").lowercased()
        let tokens = corpus
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !stopwords.contains($0) && entityQualityPolicy.usefulThemeLabel($0) }
        return Set(tokens)
    }

    private func adjustedSalienceScore(_ score: Double, entityNames: [String], textBag: Set<String>) -> Double {
        guard !entityNames.isEmpty else { return score }
        guard textBag.contains("launch") else { return score }
        let decisionPlanSignals = ["quieter", "quiet", "rollout", "scope", "plan", "carefully"]
        guard decisionPlanSignals.contains(where: textBag.contains) else { return score }
        return max(score, 0.55)
    }

    private func anchorTokens(from value: String) -> [String] {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !stopwords.contains($0) && entityQualityPolicy.usefulThemeLabel($0) }
    }

    private func normalizeAnchor(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopwords.contains($0) }
            .joined(separator: " ")
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
