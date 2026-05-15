import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class SproutMemoryRepository {
    struct EntityMemoryView: Sendable {
        var entity: EntityNode
        var relatedEntities: [EntityNode]
        var relatedRecords: [RecordShell]
        var relatedArtifacts: [Artifact]
        var supportingEdges: [EntityEdge]
    }

    struct PersonIndexEntry: Identifiable, Sendable {
        var entity: EntityNode
        var relatedRecordCount: Int
        var relatedArtifactCount: Int
        var relatedEntityCount: Int
        var themeNames: [String]
        var placeNames: [String]
        var arcTitles: [String]
        var lastSeenAt: Date?
        var graphCentrality: Double
        var totalEdgeWeight: Double
        var totalEvidenceCount: Int

        var id: UUID { entity.id }
    }

    struct SearchResults: Sendable {
        var entities: [EntityNode]
        var arcs: [TemporalArc]
        var records: [RecordShell]
        var artifacts: [Artifact]
        var reflections: [ReflectionSnapshot]
    }

    struct PipelineHealthSnapshot: Sendable {
        var totalRecords: Int
        var recordsWithArtifacts: Int
        var recordsWithAnalysis: Int
        var recordsWithGraphLinks: Int
        var recordsLinkedToArcs: Int
        var recordsWithReflections: Int
        var orphanAnalysisRecordIDs: [UUID]
        var orphanArtifactIDs: [UUID]
        var arcsWithoutReflections: [UUID]
        var reflectionsWithoutArcs: [UUID]
    }

    struct RecordMemoryView: Sendable {
        var recordShell: RecordShell
        var artifacts: [Artifact]
        var analysis: RecordAnalysisSnapshot?
        var linkedEntities: [EntityNode]
        var reflection: ReflectionSnapshot?
    }

    struct ArtifactEvidenceView: Sendable {
        var artifact: Artifact
        var linkedEntities: [EntityNode]
        var relatedRecordShells: [RecordShell]
        var relatedAnalyses: [RecordAnalysisSnapshot]
        var relatedArcs: [TemporalArc]
    }

    struct ArcEvidenceView: Sendable {
        var arc: TemporalArc
        var linkedReflection: ReflectionSnapshot?
        var relatedRecordShells: [RecordShell]
        var relatedAnalyses: [RecordAnalysisSnapshot]
        var linkedEntities: [EntityNode]
    }

    struct EntityPhaseEvidenceView: Sendable {
        var entity: EntityNode
        var relatedArcs: [TemporalArc]
        var relatedReflections: [ReflectionSnapshot]
    }

    struct ReflectionEvidenceView: Sendable {
        var reflection: ReflectionSnapshot
        var linkedArc: TemporalArc?
        var linkedEntities: [EntityNode]
        var linkedArtifacts: [Artifact]
    }
    private let graphUpdater = GraphUpdater()
    private let analysisEntityMatcher = AnalysisEntityMatcher()
    private let temporalArcService = SproutTemporalArcService()
    private let modelContainer: ModelContainer

    var modelContext: ModelContext {
        modelContainer.mainContext
    }

    var recordShells: [RecordShell] = []
    var artifacts: [Artifact] = []
    var analyses: [RecordAnalysisSnapshot] = []
    var reflections: [ReflectionSnapshot] = []
    var entityNodes: [EntityNode] = []
    var entityEdges: [EntityEdge] = []
    var artifactEntityLinks: [ArtifactEntityLink] = []
    var temporalArcs: [TemporalArc] = []

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        load()
    }

    convenience init() {
        self.init(modelContainer: Self.makePreviewContainer())
    }

    func upsertAggregate(_ aggregate: SproutMemoryAggregate) throws {
        recordShells.removeAll { $0.id == aggregate.recordShell.id }
        recordShells.append(aggregate.recordShell)

        let aggregateArtifactIDs = Set(aggregate.artifacts.map(\.id))
        artifacts.removeAll { aggregateArtifactIDs.contains($0.id) }
        artifacts.append(contentsOf: aggregate.artifacts)

        try save()
    }

    func setAnalysis(_ analysis: RecordAnalysisSnapshot, aggregate: SproutMemoryAggregate) throws {
        try upsertAggregate(aggregate)
        analyses.removeAll { $0.recordID == analysis.recordID }
        analyses.append(analysis)

        let graphResult = graphUpdater.apply(
            analysis: analysis,
            linkedArtifactIDs: aggregate.artifacts.map(\.id),
            linkedRecordIDs: [aggregate.recordShell.id],
            existingEntityNodes: entityNodes,
            existingEntityEdges: entityEdges,
            existingArtifactEntityLinks: artifactEntityLinks
        )

        entityNodes = graphResult.entityNodes
        entityEdges = graphResult.entityEdges
        artifactEntityLinks = graphResult.artifactEntityLinks
        rebuildTemporalArcs()
        upsertRecordReflection(
            for: analysis,
            aggregate: aggregate,
            sourceEntityIDs: graphResult.resolvedEntityIDs
        )
        try save()
    }

    func deleteRecordShell(_ recordID: UUID) {
        recordShells.removeAll { $0.id == recordID }
        let artifactIDs = Set(artifacts(forRecordID: recordID).map(\.id))
        artifacts.removeAll { artifactIDs.contains($0.id) }
        analyses.removeAll { $0.recordID == recordID }
        reflections.removeAll { $0.sourceRecordIDs.contains(recordID) }
        entityEdges.removeAll { $0.sourceRecordIDs.contains(recordID) }
        artifactEntityLinks.removeAll { artifactIDs.contains($0.artifactID) }
        temporalArcs.removeAll { $0.sourceRecordIDs.contains(recordID) }
        persistCurrentState()
    }

    func recordShell(for recordID: UUID) -> RecordShell? {
        recordShells.first { $0.id == recordID }
    }

    func analysis(for recordID: UUID) -> RecordAnalysisSnapshot? {
        analyses.first { $0.recordID == recordID }
    }

    func artifacts(forRecordID recordID: UUID) -> [Artifact] {
        guard let shell = recordShell(for: recordID) else { return [] }
        let artifactIDs = Set(shell.artifactIDs)
        return artifacts
            .filter { artifactIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func linkedEntities(forRecordID recordID: UUID) -> [EntityNode] {
        let artifactIDs = Set(artifacts(forRecordID: recordID).map(\.id))
        let entityIDs = Set(
            artifactEntityLinks
                .filter { artifactIDs.contains($0.artifactID) }
                .map(\.entityID)
        )
        return entityNodes
            .filter { entityIDs.contains($0.id) }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }
    }

    func memoryView(for recordID: UUID) -> RecordMemoryView? {
        guard let shell = recordShell(for: recordID) else { return nil }
        return RecordMemoryView(
            recordShell: shell,
            artifacts: artifacts(forRecordID: recordID),
            analysis: analysis(for: recordID),
            linkedEntities: linkedEntities(forRecordID: recordID),
            reflection: recordReflection(forRecordID: recordID)
        )
    }

    func entityNode(for entityID: UUID) -> EntityNode? {
        entityNodes.first { $0.id == entityID }
    }

    func featuredTemporalArc(for referenceDate: Date, toleranceDays: Int = 6) -> TemporalArc? {
        let accepted = temporalArcs.filter { $0.status == .accepted }
        let active = accepted.filter { $0.startDate <= referenceDate && $0.endDate >= referenceDate }
        if let current = active.sorted(by: temporalArcSort).first {
            return current
        }

        let tolerance = TimeInterval(60 * 60 * 24 * toleranceDays)
        let nearby = accepted
            .filter {
                abs($0.startDate.timeIntervalSince(referenceDate)) <= tolerance
                    || abs($0.endDate.timeIntervalSince(referenceDate)) <= tolerance
            }
            .sorted(by: temporalArcSort)
        return nearby.first
    }

    func temporalArc(for arcID: UUID) -> TemporalArc? {
        temporalArcs.first { $0.id == arcID }
    }

    func reflection(_ reflectionID: UUID) -> ReflectionSnapshot? {
        reflections.first { $0.id == reflectionID }
    }

    func linkedReflection(forArcID arcID: UUID) -> ReflectionSnapshot? {
        guard let reflectionID = temporalArc(for: arcID)?.linkedReflectionID else { return nil }
        return reflections.first { $0.id == reflectionID }
    }

    func recordReflection(forRecordID recordID: UUID) -> ReflectionSnapshot? {
        reflections.first {
            $0.type == .record && $0.sourceRecordIDs.contains(recordID)
        }
    }

    func savedReflectionsForHome(referenceDate: Date, limit: Int = 3) -> [ReflectionSnapshot] {
        let saved = reflections
            .filter { $0.status == .saved && $0.type != .phase }
            .sorted { lhs, rhs in
                if lhs.savedAt == rhs.savedAt {
                    if lhs.createdAt == rhs.createdAt {
                        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                    }
                    return lhs.createdAt > rhs.createdAt
                }
                return (lhs.savedAt ?? lhs.createdAt) > (rhs.savedAt ?? rhs.createdAt)
            }

        let referenceRecordIDs = Set(recordShells(on: referenceDate).map(\.id))
        let ranked = saved.map { reflection -> (reflection: ReflectionSnapshot, score: Double) in
            var score = Double(reflection.sourceRecordIDs.filter { referenceRecordIDs.contains($0) }.count) * 80
            if let savedAt = reflection.savedAt, Calendar.current.isDate(savedAt, inSameDayAs: referenceDate) {
                score += 40
            }
            if Calendar.current.isDate(reflection.createdAt, inSameDayAs: referenceDate) {
                score += 24
            }
            if let linkedArcID = reflection.linkedTemporalArcID,
               temporalArcs.contains(where: { $0.id == linkedArcID && $0.status == .accepted }) {
                score += 18
            }
            score += min(Double(reflection.sourceArtifactIDs.count), 6) * 6
            score += min(Double(reflection.sourceEntityIDs.count), 6) * 3
            score += min(Double(reflection.body.count / 40), 6)
            return (reflection, score)
        }

        let matched = ranked
            .filter { item in
                let reflection = item.reflection
                return referenceRecordIDs.isEmpty
                    ? true
                    : reflection.sourceRecordIDs.contains { referenceRecordIDs.contains($0) }
            }
            .sorted {
                if $0.score == $1.score {
                    if $0.reflection.savedAt == $1.reflection.savedAt {
                        return $0.reflection.createdAt > $1.reflection.createdAt
                    }
                    return ($0.reflection.savedAt ?? $0.reflection.createdAt) > ($1.reflection.savedAt ?? $1.reflection.createdAt)
                }
                return $0.score > $1.score
            }
            .map(\.reflection)

        if !matched.isEmpty {
            return Array(matched.prefix(limit))
        }

        return Array(saved.prefix(limit))
    }

    func activeRecordReflectionsForHome(referenceDate: Date, limit: Int = 2) -> [ReflectionSnapshot] {
        let active = reflections
            .filter { $0.status == .active && $0.type == .record }

        guard !active.isEmpty else { return [] }

        let referenceRecordIDs = Set(recordShells(on: referenceDate).map(\.id))
        let ranked = active.map { reflection -> (reflection: ReflectionSnapshot, score: Double) in
            var score = 0.0

            let sameDayMatchCount = reflection.sourceRecordIDs.filter { referenceRecordIDs.contains($0) }.count
            score += Double(sameDayMatchCount) * 100

            if Calendar.current.isDate(reflection.createdAt, inSameDayAs: referenceDate) {
                score += 36
            }
            if let confidence = reflection.confidence {
                score += confidence * 24
            }
            score += min(Double(reflection.sourceArtifactIDs.count), 6) * 6
            score += min(Double(reflection.sourceEntityIDs.count), 6) * 5
            score += min(Double(reflection.body.count / 40), 6) * 2

            if let linkedArcID = reflection.linkedTemporalArcID,
               temporalArcs.contains(where: { $0.id == linkedArcID && $0.status == .accepted }) {
                score += 12
            }

            return (reflection, score)
        }

        let matched = ranked
            .filter { item in
                let reflection = item.reflection
                return referenceRecordIDs.isEmpty
                    ? true
                    : reflection.sourceRecordIDs.contains { referenceRecordIDs.contains($0) }
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.reflection.createdAt > $1.reflection.createdAt
                }
                return $0.score > $1.score
            }
            .map(\.reflection)

        if !matched.isEmpty {
            return Array(matched.prefix(limit))
        }

        let fallback = ranked
            .sorted {
                if $0.score == $1.score {
                    return $0.reflection.createdAt > $1.reflection.createdAt
                }
                return $0.score > $1.score
            }
            .map(\.reflection)

        return Array(fallback.prefix(limit))
    }

    func archiveTemporalArc(_ arcID: UUID) {
        guard let index = temporalArcs.firstIndex(where: { $0.id == arcID }) else { return }
        temporalArcs[index].status = .archived
        temporalArcs[index].updatedAt = .now
        persistCurrentState()
    }

    func restoreTemporalArc(_ arcID: UUID) {
        guard let index = temporalArcs.firstIndex(where: { $0.id == arcID }) else { return }
        temporalArcs[index].status = .accepted
        temporalArcs[index].updatedAt = .now
        persistCurrentState()
    }

    // MARK: - Protocol-Conformant Governance Methods

    func fetchTemporalArcSummaries(limit: Int?) throws -> [TemporalArcSummarySnapshot] {
        let summaries = temporalArcs
            .sorted(by: temporalArcSort)
            .map { arc -> TemporalArcSummarySnapshot in
                let relatedRecords = recordShells
                    .filter { arc.sourceRecordIDs.contains($0.id) }
                    .sorted { $0.createdAt > $1.createdAt }
                let relatedMemories = relatedRecords.prefix(5).map { record -> MemorySummary in
                    let recordArtifacts = artifacts.filter { $0.recordID == record.id }
                    let primaryArtifact = recordArtifacts.first
                    let pipelineStatus = fetchPipelineStatusSnapshot(for: record.id)
                    return MemorySummary(
                        record: record,
                        primaryArtifact: primaryArtifact,
                        artifactCount: recordArtifacts.count,
                        pipelineStatus: pipelineStatus
                    )
                }
                let linkedReflection = self.linkedReflection(forArcID: arc.id)
                return TemporalArcSummarySnapshot(
                    arc: arc,
                    relatedMemories: Array(relatedMemories),
                    linkedReflection: linkedReflection
                )
            }
        if let limit {
            return Array(summaries.prefix(limit))
        }
        return summaries
    }

    func fetchTemporalArcDetail(arcID: UUID) throws -> TemporalArcDetailSnapshot? {
        guard let arc = temporalArcs.first(where: { $0.id == arcID }) else { return nil }
        let summaries = try fetchTemporalArcSummaries(limit: nil)
        guard let summary = summaries.first(where: { $0.arc.id == arcID }) else { return nil }

        let reflections = self.reflections
            .filter { $0.type == .phase && $0.linkedTemporalArcID == arcID }
            .sorted { $0.createdAt > $1.createdAt }
            .map { reflection -> ReflectionSummarySnapshot in
                let reflectionRecords = recordShells
                    .filter { reflection.sourceRecordIDs.contains($0.id) }
                    .sorted { $0.createdAt > $1.createdAt }
                let reflectionMemories = reflectionRecords.prefix(5).map { record -> MemorySummary in
                    let recordArtifacts = artifacts.filter { $0.recordID == record.id }
                    let primaryArtifact = recordArtifacts.first
                    let pipelineStatus = fetchPipelineStatusSnapshot(for: record.id)
                    return MemorySummary(
                        record: record,
                        primaryArtifact: primaryArtifact,
                        artifactCount: recordArtifacts.count,
                        pipelineStatus: pipelineStatus
                    )
                }
                let linkedArc = temporalArcs.first { $0.id == reflection.linkedTemporalArcID }
                return ReflectionSummarySnapshot(
                    reflection: reflection,
                    linkedArc: linkedArc,
                    relatedMemories: Array(reflectionMemories)
                )
            }

        let entityDetails = entityNodes
            .filter { arc.sourceEntityIDs.contains($0.id) || arc.entityNames.contains($0.displayName) }
            .prefix(10)
            .map { entity -> EntityDetailSnapshot in
                let entityArtifacts = artifacts.filter { artifact in
                    artifactEntityLinks.contains { $0.entityID == entity.id && artifact.artifactID == $0.artifactID }
                }
                let entityRecords = recordShells
                    .filter { entityArtifacts.contains { $0.recordID == $1.id } }
                    .prefix(5)
                    .map { record -> MemorySummary in
                        let recordArtifacts = artifacts.filter { $0.recordID == record.id }
                        let primaryArtifact = recordArtifacts.first
                        let pipelineStatus = fetchPipelineStatusSnapshot(for: record.id)
                        return MemorySummary(
                            record: record,
                            primaryArtifact: primaryArtifact,
                            artifactCount: recordArtifacts.count,
                            pipelineStatus: pipelineStatus
                        )
                    }
                let relatedThemes = arc.themeLabels
                let relatedPeople = arc.entityNames
                let relatedArcs = temporalArcs
                    .filter { $0.sourceEntityIDs.contains(entity.id) && $0.id != arcID }
                    .sorted(by: temporalArcSort)
                    .prefix(3)
                let entityEdges = self.entityEdges.filter { $0.sourceID == entity.id || $0.targetID == entity.id }
                return EntityDetailSnapshot(
                    entity: entity,
                    artifactCount: entityArtifacts.count,
                    relatedMemories: Array(entityRecords),
                    relatedThemes: relatedThemes,
                    relatedPeople: relatedPeople,
                    relatedReflections: [],
                    relatedArcs: Array(relatedArcs),
                    edges: entityEdges
                )
            }

        var mergeCandidate: TemporalArcSummarySnapshot?
        var mergeCandidateOverlapScore: Double?
        if arc.status == .accepted {
            if let preview = temporalArcService.mergePreview(sourceArcID: arcID, arcs: temporalArcs) {
                mergeCandidate = summaries.first { $0.arc.id == preview.candidateArcID }
                mergeCandidateOverlapScore = preview.overlapScore
            }
        }

        return TemporalArcDetailSnapshot(
            summary: summary,
            reflections: reflections,
            entityDetails: Array(entityDetails),
            mergeCandidate: mergeCandidate,
            mergeCandidateOverlapScore: mergeCandidateOverlapScore
        )
    }

    func acceptTemporalArc(arcID: UUID) async throws {
        guard let index = temporalArcs.firstIndex(where: { $0.id == arcID }) else {
            throw RepositoryError.arcNotFound
        }
        temporalArcs[index].status = .accepted
        temporalArcs[index].updatedAt = .now
        persistCurrentState()
    }

    func mergeTemporalArc(arcID: UUID) async throws -> TemporalArcDetailSnapshot? {
        guard let baseArc = temporalArcs.first(where: { $0.id == arcID }),
              baseArc.status == .accepted else {
            throw RepositoryError.arcNotFound
        }
        guard let preview = temporalArcService.mergePreview(sourceArcID: arcID, arcs: temporalArcs),
              let candidateArc = temporalArcs.first(where: { $0.id == preview.candidateArcID }) else {
            return try fetchTemporalArcDetail(arcID: arcID)
        }
        let linkedReflection = self.linkedReflection(forArcID: arcID)
        let result = temporalArcService.merge(
            sourceArc: baseArc,
            candidateArc: candidateArc,
            linkedReflection: linkedReflection
        )

        if let index = temporalArcs.firstIndex(where: { $0.id == result.sourceArc.id }) {
            temporalArcs[index] = result.sourceArc
        }
        if let candidateIndex = temporalArcs.firstIndex(where: { $0.id == result.candidateArc.id }) {
            temporalArcs[candidateIndex] = result.candidateArc
        }
        if let candidateReflectionID = result.candidateReflectionIDToRemove {
            reflections.removeAll { $0.id == candidateReflectionID }
        }
        if let updatedReflection = result.updatedReflection {
            upsertReflection(updatedReflection)
        }

        persistCurrentState()
        return try fetchTemporalArcDetail(arcID: result.sourceArc.id)
    }

    private func fetchPipelineStatusSnapshot(for recordID: UUID) -> MemoryPipelineStatusSnapshot? {
        if let analysis = analyses.first(where: { $0.recordID == recordID }) {
            return MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .completed,
                lastError: nil,
                requestBody: nil,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: nil,
                failedStage: nil,
                lastAttemptAt: nil,
                completedAt: analysis.createdAt,
                updatedAt: analysis.createdAt
            )
        }
        if let shell = recordShells.first(where: { $0.id == recordID }) {
            return MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .pending,
                lastError: nil,
                requestBody: nil,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: nil,
                failedStage: nil,
                lastAttemptAt: nil,
                completedAt: nil,
                updatedAt: shell.updatedAt
            )
        }
        return nil
    }

    enum RepositoryError: Error {
        case arcNotFound
    }

    func saveReflection(_ reflectionID: UUID) {
        guard let index = reflections.firstIndex(where: { $0.id == reflectionID }) else { return }
        reflections[index].status = .saved
        reflections[index].savedAt = .now
        reflections[index].dismissedAt = nil
        persistCurrentState()
    }

    func upsertReflection(_ reflection: ReflectionSnapshot) {
        if let index = reflections.firstIndex(where: { $0.id == reflection.id }) {
            reflections[index] = reflection
        } else {
            reflections.append(reflection)
        }
        persistCurrentState()
    }

    func dismissReflection(_ reflectionID: UUID) {
        guard let index = reflections.firstIndex(where: { $0.id == reflectionID }) else { return }
        reflections[index].status = .dismissed
        reflections[index].dismissedAt = .now
        persistCurrentState()
    }

    func reactivateReflection(_ reflectionID: UUID) {
        guard let index = reflections.firstIndex(where: { $0.id == reflectionID }) else { return }
        reflections[index].status = .active
        reflections[index].dismissedAt = nil
        persistCurrentState()
    }

    func entityView(for entityID: UUID) -> EntityMemoryView? {
        guard let entity = entityNode(for: entityID) else { return nil }

        let supportingEdges = entityEdges.filter {
            $0.fromEntityID == entityID || $0.toEntityID == entityID
        }

        let relatedEntityIDs = Set(
            supportingEdges.map {
                $0.fromEntityID == entityID ? $0.toEntityID : $0.fromEntityID
            }
        )
        let relatedEntities = entityNodes
            .filter { relatedEntityIDs.contains($0.id) }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }

        let relatedArtifactIDs = Set(
            artifactEntityLinks
                .filter { $0.entityID == entityID }
                .map(\.artifactID)
        )
        let relatedArtifacts = artifacts
            .filter { relatedArtifactIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }

        let relatedRecordIDs = Set(
            supportingEdges
                .flatMap(\.sourceRecordIDs)
        )
        let relatedRecords = recordShells
            .filter { relatedRecordIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }

        return EntityMemoryView(
            entity: entity,
            relatedEntities: relatedEntities,
            relatedRecords: relatedRecords,
            relatedArtifacts: relatedArtifacts,
            supportingEdges: supportingEdges.sorted { $0.lastSeenAt > $1.lastSeenAt }
        )
    }

    func artifactEvidenceView(for artifactID: UUID) -> ArtifactEvidenceView? {
        guard let artifact = artifacts.first(where: { $0.id == artifactID }) else { return nil }

        let linkedEntityIDs = Set(
            artifactEntityLinks
                .filter { $0.artifactID == artifactID }
                .map(\.entityID)
        )
        let linkedEntities = entityNodes
            .filter { linkedEntityIDs.contains($0.id) }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }

        let relatedRecordShells = recordShells
            .filter { $0.artifactIDs.contains(artifactID) }
            .sorted { $0.createdAt > $1.createdAt }

        let relatedRecordIDs = Set(relatedRecordShells.map(\.id))
        let relatedAnalyses = analyses
            .filter { relatedRecordIDs.contains($0.recordID) }
            .sorted { $0.createdAt > $1.createdAt }

        let relatedArcs = temporalArcs
            .filter { $0.sourceArtifactIDs.contains(artifactID) }
            .sorted(by: temporalArcSort)

        return ArtifactEvidenceView(
            artifact: artifact,
            linkedEntities: linkedEntities,
            relatedRecordShells: relatedRecordShells,
            relatedAnalyses: relatedAnalyses,
            relatedArcs: relatedArcs
        )
    }

    func arcEvidenceView(for arcID: UUID) -> ArcEvidenceView? {
        guard let arc = temporalArcs.first(where: { $0.id == arcID }) else { return nil }

        let relatedRecordShells = recordShells
            .filter { arc.sourceRecordIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }

        let relatedRecordIDs = Set(relatedRecordShells.map(\.id))
        let relatedAnalyses = analyses
            .filter { relatedRecordIDs.contains($0.recordID) }
            .sorted { $0.createdAt > $1.createdAt }

        let linkedEntities = entityNodes
            .filter { arc.sourceEntityIDs.contains($0.id) || arc.entityNames.contains($0.displayName) }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }

        return ArcEvidenceView(
            arc: arc,
            linkedReflection: linkedReflection(forArcID: arcID),
            relatedRecordShells: relatedRecordShells,
            relatedAnalyses: relatedAnalyses,
            linkedEntities: linkedEntities
        )
    }

    func entityPhaseEvidenceView(for entityID: UUID) -> EntityPhaseEvidenceView? {
        guard let entity = entityNode(for: entityID) else { return nil }

        let relatedArcs = temporalArcs
            .filter { $0.sourceEntityIDs.contains(entityID) || $0.entityNames.contains(entity.displayName) }
            .sorted(by: temporalArcSort)

        let relatedArcIDs = Set(relatedArcs.map(\.id))
        let relatedReflections = reflections
            .filter { reflection in
                guard reflection.type == .phase else { return false }
                if reflection.sourceEntityIDs.contains(entityID) {
                    return true
                }
                guard let linkedTemporalArcID = reflection.linkedTemporalArcID else { return false }
                return relatedArcIDs.contains(linkedTemporalArcID)
            }
            .sorted { $0.createdAt > $1.createdAt }

        return EntityPhaseEvidenceView(
            entity: entity,
            relatedArcs: relatedArcs,
            relatedReflections: relatedReflections
        )
    }

    func reflectionEvidenceView(for reflectionID: UUID) -> ReflectionEvidenceView? {
        guard let reflection = reflections.first(where: { $0.id == reflectionID }) else { return nil }

        let linkedEntities = entityNodes
            .filter { reflection.sourceEntityIDs.contains($0.id) }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }

        let linkedArtifacts = artifacts
            .filter { reflection.sourceArtifactIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }

        return ReflectionEvidenceView(
            reflection: reflection,
            linkedArc: reflection.linkedTemporalArcID.flatMap(temporalArc(for:)),
            linkedEntities: linkedEntities,
            linkedArtifacts: linkedArtifacts
        )
    }

    func analyses(mentioning entityID: UUID) -> [RecordAnalysisSnapshot] {
        guard let entity = entityNode(for: entityID) else { return [] }
        return analyses
            .filter { analysisEntityMatcher.matches(entity: entity, analysis: $0) }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.recordID.uuidString < $1.recordID.uuidString
                }
                return $0.createdAt > $1.createdAt
            }
    }

    func peopleIndex(limit: Int? = nil) -> [PersonIndexEntry] {
        let acceptedArcs = temporalArcs
            .filter { $0.status == .accepted }
            .sorted(by: temporalArcSort)

        let entries = entityNodes
            .filter { $0.kind == .person }
            .compactMap { person -> PersonIndexEntry? in
                guard let entityView = entityView(for: person.id) else { return nil }

                let themeNames = orderedUniqueNames(
                    from: entityView.relatedEntities,
                    matching: .theme
                )
                let placeNames = orderedUniqueNames(
                    from: entityView.relatedEntities,
                    matching: .place
                )
                let arcTitles = acceptedArcs
                    .filter { $0.sourceEntityIDs.contains(person.id) }
                    .prefix(3)
                    .map(\.title)
                let lastSeenAt = entityView.relatedRecords.first?.createdAt ?? person.updatedAt

                let connectedEdges = entityEdges.filter { $0.fromEntityID == person.id || $0.toEntityID == person.id }
                let totalEdgeWeight = connectedEdges.reduce(0) { $0 + $1.weight }
                let totalEvidenceCount = connectedEdges.reduce(0) { $0 + $1.evidenceCount }
                let graphCentrality = totalEdgeWeight + Double(totalEvidenceCount) * 0.5 + Double(connectedEdges.count) * 0.3

                return PersonIndexEntry(
                    entity: person,
                    relatedRecordCount: entityView.relatedRecords.count,
                    relatedArtifactCount: entityView.relatedArtifacts.count,
                    relatedEntityCount: entityView.relatedEntities.count,
                    themeNames: Array(themeNames.prefix(3)),
                    placeNames: Array(placeNames.prefix(3)),
                    arcTitles: arcTitles,
                    lastSeenAt: lastSeenAt,
                    graphCentrality: graphCentrality,
                    totalEdgeWeight: totalEdgeWeight,
                    totalEvidenceCount: totalEvidenceCount
                )
            }
            .sorted(by: peopleIndexSort)

        guard let limit else { return entries }
        return Array(entries.prefix(limit))
    }

    func searchResults(matching query: String, limitPerSection: Int = 6) -> SearchResults {
        let tokens = searchTokens(for: query)
        guard !tokens.isEmpty else {
            return SearchResults(entities: [], arcs: [], records: [], artifacts: [], reflections: [])
        }

        let analysisIndex = Dictionary(uniqueKeysWithValues: analyses.map { ($0.recordID, $0) })

        let entities = entityNodes
            .compactMap { entity -> (EntityNode, Int)? in
                let fields = [
                    entity.displayName,
                    entity.canonicalName,
                    entity.summary,
                    entity.kind.rawValue
                ]
                guard let score = searchScore(in: fields, tokens: tokens) else { return nil }
                return (entity, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.displayName.localizedCaseInsensitiveCompare(rhs.0.displayName) == .orderedAscending
                }
                return lhs.1 > rhs.1
            }
            .prefix(limitPerSection)
            .map(\.0)

        let arcs = temporalArcs
            .filter { $0.status == .accepted }
            .compactMap { arc -> (TemporalArc, Int)? in
                let fields = [
                    arc.title,
                    arc.summary,
                    arc.dominantTheme ?? "",
                    arc.dominantEntityName ?? "",
                    arc.themeLabels.joined(separator: " "),
                    arc.entityNames.joined(separator: " ")
                ]
                guard let score = searchScore(in: fields, tokens: tokens) else { return nil }
                return (arc, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return temporalArcSort(lhs: lhs.0, rhs: rhs.0)
                }
                return lhs.1 > rhs.1
            }
            .prefix(limitPerSection)
            .map(\.0)

        let records = recordShells
            .compactMap { record -> (RecordShell, Int)? in
                let analysis = analysisIndex[record.id]
                let fields = [
                    record.rawText,
                    record.captureSource.rawValue,
                    record.userMood ?? "",
                    analysis?.emotionLabel ?? "",
                    analysis?.insight ?? "",
                    analysis?.tags.joined(separator: " ") ?? "",
                    analysis?.entities.map(\.name).joined(separator: " ") ?? ""
                ]
                guard let score = searchScore(in: fields, tokens: tokens) else { return nil }
                return (record, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.createdAt > rhs.0.createdAt
                }
                return lhs.1 > rhs.1
            }
            .prefix(limitPerSection)
            .map(\.0)

        let matchedArtifacts = artifacts
            .compactMap { artifact -> (Artifact, Int)? in
                let fields = [
                    artifact.kind.rawValue,
                    artifact.title,
                    artifact.summary,
                    artifact.textContent,
                    artifact.entities.map(\.name).joined(separator: " "),
                    artifact.metadata.values.joined(separator: " ")
                ]
                guard let score = searchScore(in: fields, tokens: tokens) else { return nil }
                return (artifact, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.updatedAt > rhs.0.updatedAt
                }
                return lhs.1 > rhs.1
            }
            .prefix(limitPerSection)
            .map(\.0)

        let reflections = self.reflections
            .compactMap { reflection -> (ReflectionSnapshot, Int)? in
                let fields = [
                    reflection.title,
                    reflection.body,
                    reflection.evidenceSummary ?? "",
                    reflection.type.rawValue,
                    reflection.status.rawValue
                ]
                guard let score = searchScore(in: fields, tokens: tokens) else { return nil }
                return (reflection, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.createdAt > rhs.0.createdAt
                }
                return lhs.1 > rhs.1
            }
            .prefix(limitPerSection)
            .map(\.0)

        return SearchResults(
            entities: entities,
            arcs: arcs,
            records: records,
            artifacts: matchedArtifacts,
            reflections: reflections
        )
    }

    func pipelineHealthSnapshot() -> PipelineHealthSnapshot {
        let recordIDs = Set(recordShells.map(\.id))
        let acceptedArcRecordIDs = Set(
            temporalArcs
                .filter { $0.status == .accepted }
                .flatMap(\.sourceRecordIDs)
        )
        let arcIDs = Set(temporalArcs.map(\.id))
        let phaseReflectionArcIDs = Set(
            reflections
                .filter { $0.type == .phase }
                .compactMap(\.linkedTemporalArcID)
        )

        let recordsWithArtifacts = recordShells.filter { !$0.artifactIDs.isEmpty }.count
        let recordsWithAnalysis = recordShells.filter { analysis(for: $0.id) != nil }.count
        let recordsWithGraphLinks = recordShells.filter { !linkedEntities(forRecordID: $0.id).isEmpty }.count
        let recordsLinkedToArcs = recordShells.filter { acceptedArcRecordIDs.contains($0.id) }.count
        let recordsWithReflections = recordShells.filter { recordReflection(forRecordID: $0.id) != nil }.count

        let orphanAnalysisRecordIDs = analyses
            .map(\.recordID)
            .filter { !recordIDs.contains($0) }

        let orphanArtifactIDs = artifacts
            .filter { artifact in
                !recordShells.contains { $0.artifactIDs.contains(artifact.id) }
            }
            .map(\.id)

        let arcsWithoutReflections = temporalArcs
            .filter { $0.status == .accepted && linkedReflection(forArcID: $0.id) == nil }
            .map(\.id)

        let reflectionsWithoutArcs = reflections
            .filter { reflection in
                reflection.type == .phase &&
                (reflection.linkedTemporalArcID == nil || !arcIDs.contains(reflection.linkedTemporalArcID!))
            }
            .map(\.id)

        let normalizedArclessReflections = reflectionsWithoutArcs.filter { reflectionID in
            guard let reflection = reflection(reflectionID) else { return false }
            guard let arcID = reflection.linkedTemporalArcID else { return true }
            return !phaseReflectionArcIDs.contains(arcID)
        }

        return PipelineHealthSnapshot(
            totalRecords: recordShells.count,
            recordsWithArtifacts: recordsWithArtifacts,
            recordsWithAnalysis: recordsWithAnalysis,
            recordsWithGraphLinks: recordsWithGraphLinks,
            recordsLinkedToArcs: recordsLinkedToArcs,
            recordsWithReflections: recordsWithReflections,
            orphanAnalysisRecordIDs: orphanAnalysisRecordIDs,
            orphanArtifactIDs: orphanArtifactIDs,
            arcsWithoutReflections: arcsWithoutReflections,
            reflectionsWithoutArcs: normalizedArclessReflections
        )
    }

    private static func makePreviewContainer() -> ModelContainer {
        do {
            let schema = MemoryModelSchema.makeSchema()
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }


    private func persistCurrentState() {
        do {
            try save()
        } catch {
            assertionFailure("Failed to persist Sprout memory state: \(error)")
        }
    }

    private func load() {
        do {
            recordShells = try fetchRecordShells()
            artifacts = try fetchArtifacts()
            analyses = try fetchAnalyses()
            reflections = try fetchReflections()
            entityNodes = try fetchEntityNodes()
            entityEdges = try fetchEntityEdges()
            artifactEntityLinks = try fetchArtifactEntityLinks()
            temporalArcs = try fetchTemporalArcs()
            if temporalArcs.isEmpty && !analyses.isEmpty {
                rebuildTemporalArcs()
                try save()
            }
        } catch {
            recordShells = []
            artifacts = []
            analyses = []
            reflections = []
            entityNodes = []
            entityEdges = []
            artifactEntityLinks = []
            temporalArcs = []
            assertionFailure("Failed to load Sprout memory state: \(error)")
        }
    }

    private func save() throws {
        try upsertRecordShellModels()
        try upsertArtifactStoreModels()
        try upsertAnalysisStoreModels()
        try upsertReflectionStoreModels()
        try upsertEntityNodeStoreModels()
        try upsertEntityEdgeStoreModels()
        try upsertArtifactEntityLinkStoreModels()
        try upsertTemporalArcStoreModels()
        try modelContext.save()
    }

    private func fetchRecordShells() throws -> [RecordShell] {
        let records = try modelContext.fetch(FetchDescriptor<Record>())
        return records
            .map {
                RecordShell(
                    id: $0.id,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    rawText: $0.rawText,
                    captureSource: $0.captureSource,
                    artifactIDs: artifactsForRecordID($0.id, in: try? modelContext.fetch(FetchDescriptor<ArtifactStoreModel>())).map(\.id),
                    userMood: $0.userMood,
                    userIntensity: $0.userIntensity,
                    inputContext: $0.inputContext
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func artifactsForRecordID(_ recordID: UUID, in cached: [ArtifactStoreModel]?) -> [ArtifactStoreModel] {
        let source = cached ?? []
        return source.filter { $0.recordID == recordID }.sorted { $0.createdAt < $1.createdAt }
    }

    private func fetchArtifacts() throws -> [Artifact] {
        try modelContext.fetch(FetchDescriptor<ArtifactStoreModel>())
            .map(artifact(from:))
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private func fetchAnalyses() throws -> [RecordAnalysisSnapshot] {
        try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStoreModel>())
            .map(analysis(from:))
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchReflections() throws -> [ReflectionSnapshot] {
        try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStoreModel>())
            .map(reflection(from:))
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchEntityNodes() throws -> [EntityNode] {
        try modelContext.fetch(FetchDescriptor<EntityNodeStoreModel>())
            .map(entityNode(from:))
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func fetchEntityEdges() throws -> [EntityEdge] {
        try modelContext.fetch(FetchDescriptor<EntityEdgeStoreModel>())
            .map(entityEdge(from:))
            .sorted { $0.lastSeenAt > $1.lastSeenAt }
    }

    private func fetchArtifactEntityLinks() throws -> [ArtifactEntityLink] {
        try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStoreModel>())
            .map(artifactEntityLink(from:))
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchTemporalArcs() throws -> [TemporalArc] {
        try modelContext.fetch(FetchDescriptor<TemporalArcStoreModel>())
            .map(temporalArc(from:))
            .sorted(by: temporalArcSort)
    }

    private func upsertRecordShellModels() throws {
        let existing = try Dictionary(uniqueKeysWithValues: modelContext.fetch(FetchDescriptor<Record>()).map { ($0.id, $0) })
        let targetIDs = Set(recordShells.map(\.id))

        for record in existing.values where !targetIDs.contains(record.id) {
            modelContext.delete(record)
        }

        for shell in recordShells {
            let record = existing[shell.id] ?? Record()
            record.id = shell.id
            record.createdAt = shell.createdAt
            record.updatedAt = shell.updatedAt
            record.captureSource = shell.captureSource
            record.rawText = shell.rawText
            record.userMood = shell.userMood
            record.userIntensity = shell.userIntensity
            record.inputContext = shell.inputContext
            if existing[shell.id] == nil { modelContext.insert(record) }
        }
    }

    private func upsertArtifactStoreModels() throws {
        let existing = try Dictionary(uniqueKeysWithValues: modelContext.fetch(FetchDescriptor<ArtifactStoreModel>()).map { ($0.id, $0) })
        let targetIDs = Set(artifacts.map(\.id))

        for model in existing.values where !targetIDs.contains(model.id) {
            modelContext.delete(model)
        }

        for artifact in artifacts {
            let model = existing[artifact.id] ?? ArtifactStoreModel()
            model.id = artifact.id
            model.recordID = recordID(forArtifactID: artifact.id)
            model.kindRawValue = artifact.kind.rawValue
            model.title = artifact.title
            model.summary = artifact.summary
            model.textContent = artifact.textContent
            model.createdAt = artifact.createdAt
            model.updatedAt = artifact.updatedAt
            model.metadataData = try encode(artifact.metadata)
            model.entitiesData = try encode(artifact.entities)
            model.binaryPayload = artifact.binaryPayload
            model.previewPayload = artifact.previewPayload
            if existing[artifact.id] == nil { modelContext.insert(model) }
        }
    }

    private func upsertAnalysisStoreModels() throws {
        let existing = try Dictionary(uniqueKeysWithValues: modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStoreModel>()).map { ($0.id, $0) })
        let targetIDs = Set(analyses.map(\.id))

        for model in existing.values where !targetIDs.contains(model.id) {
            modelContext.delete(model)
        }

        for snapshot in analyses {
            let model = existing[snapshot.id] ?? RecordAnalysisSnapshotStoreModel()
            model.id = snapshot.id
            model.recordID = snapshot.recordID
            model.summary = snapshot.summary
            model.themesData = try encode(snapshot.themes)
            model.emotionInterpretation = snapshot.emotionInterpretation
            model.followUpCandidatesData = try encode(snapshot.followUpCandidates)
            model.entityMentionsData = try encode(snapshot.entityMentions)
            model.salienceScore = snapshot.salienceScore
            model.retrievalTermsData = try encode(snapshot.retrievalTerms)
            model.reflectionHint = snapshot.reflectionHint
            model.candidateEdgesData = try encode(snapshot.candidateEdges)
            model.createdAt = snapshot.createdAt
            if existing[snapshot.id] == nil { modelContext.insert(model) }
        }
    }

    private func upsertReflectionStoreModels() throws {
        let existing = try Dictionary(uniqueKeysWithValues: modelContext.fetch(FetchDescriptor<ReflectionSnapshotStoreModel>()).map { ($0.id, $0) })
        let targetIDs = Set(reflections.map(\.id))

        for model in existing.values where !targetIDs.contains(model.id) {
            modelContext.delete(model)
        }

        for reflection in reflections {
            let model = existing[reflection.id] ?? ReflectionSnapshotStoreModel()
            model.id = reflection.id
            model.typeRawValue = reflection.type.rawValue
            model.title = reflection.title
            model.bodyText = reflection.body
            model.evidenceSummary = reflection.evidenceSummary
            model.confidence = reflection.confidence
            model.statusRawValue = reflection.status.rawValue
            model.linkedTemporalArcID = reflection.linkedTemporalArcID
            model.sourceRecordIDsData = try encode(reflection.sourceRecordIDs)
            model.sourceArtifactIDsData = try encode(reflection.sourceArtifactIDs)
            model.sourceEntityIDsData = try encode(reflection.sourceEntityIDs)
            model.createdAt = reflection.createdAt
            model.savedAt = reflection.savedAt
            model.dismissedAt = reflection.dismissedAt
            if existing[reflection.id] == nil { modelContext.insert(model) }
        }
    }

    private func upsertEntityNodeStoreModels() throws {
        let existing = try Dictionary(uniqueKeysWithValues: modelContext.fetch(FetchDescriptor<EntityNodeStoreModel>()).map { ($0.id, $0) })
        let targetIDs = Set(entityNodes.map(\.id))

        for model in existing.values where !targetIDs.contains(model.id) {
            modelContext.delete(model)
        }

        for node in entityNodes {
            let model = existing[node.id] ?? EntityNodeStoreModel()
            model.id = node.id
            model.kindRawValue = node.kind.rawValue
            model.displayName = node.displayName
            model.canonicalName = node.canonicalName
            model.summary = node.summary
            model.createdAt = node.createdAt
            model.updatedAt = node.updatedAt
            model.confidence = node.confidence
            if existing[node.id] == nil { modelContext.insert(model) }
        }
    }

    private func upsertEntityEdgeStoreModels() throws {
        let existing = try Dictionary(uniqueKeysWithValues: modelContext.fetch(FetchDescriptor<EntityEdgeStoreModel>()).map { ($0.id, $0) })
        let targetIDs = Set(entityEdges.map(\.id))

        for model in existing.values where !targetIDs.contains(model.id) {
            modelContext.delete(model)
        }

        for edge in entityEdges {
            let model = existing[edge.id] ?? EntityEdgeStoreModel()
            model.id = edge.id
            model.fromEntityID = edge.fromEntityID
            model.toEntityID = edge.toEntityID
            model.relationKindRawValue = edge.relationKind.rawValue
            model.weight = edge.weight
            model.firstSeenAt = edge.firstSeenAt
            model.lastSeenAt = edge.lastSeenAt
            model.evidenceCount = edge.evidenceCount
            model.sourceArtifactIDsData = try encode(edge.sourceArtifactIDs)
            model.sourceRecordIDsData = try encode(edge.sourceRecordIDs)
            if existing[edge.id] == nil { modelContext.insert(model) }
        }
    }

    private func upsertArtifactEntityLinkStoreModels() throws {
        let existing = try Dictionary(uniqueKeysWithValues: modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStoreModel>()).map { ($0.id, $0) })
        let targetIDs = Set(artifactEntityLinks.map(\.id))

        for model in existing.values where !targetIDs.contains(model.id) {
            modelContext.delete(model)
        }

        for link in artifactEntityLinks {
            let model = existing[link.id] ?? ArtifactEntityLinkStoreModel()
            model.id = link.id
            model.artifactID = link.artifactID
            model.entityID = link.entityID
            model.confidence = link.confidence
            model.source = link.source
            model.createdAt = link.createdAt
            if existing[link.id] == nil { modelContext.insert(model) }
        }
    }

    private func upsertTemporalArcStoreModels() throws {
        let existing = try Dictionary(uniqueKeysWithValues: modelContext.fetch(FetchDescriptor<TemporalArcStoreModel>()).map { ($0.id, $0) })
        let targetIDs = Set(temporalArcs.map(\.id))

        for model in existing.values where !targetIDs.contains(model.id) {
            modelContext.delete(model)
        }

        for arc in temporalArcs {
            let model = existing[arc.id] ?? TemporalArcStoreModel()
            model.id = arc.id
            model.title = arc.title
            model.summary = arc.summary
            model.statusRawValue = arc.status.rawValue
            model.dominantTheme = arc.dominantTheme
            model.dominantEntityName = arc.dominantEntityName
            model.themeLabelsData = try encode(arc.themeLabels)
            model.entityNamesData = try encode(arc.entityNames)
            model.linkedReflectionID = arc.linkedReflectionID
            model.mergedFromArcIDsData = try encode(arc.mergedFromArcIDs)
            model.mergedIntoArcID = arc.mergedIntoArcID
            model.lastMergedAt = arc.lastMergedAt
            model.sourceRecordIDsData = try encode(arc.sourceRecordIDs)
            model.sourceArtifactIDsData = try encode(arc.sourceArtifactIDs)
            model.sourceEntityIDsData = try encode(arc.sourceEntityIDs)
            model.startDate = arc.startDate
            model.endDate = arc.endDate
            model.intensityScore = arc.intensityScore
            model.clusterStrength = arc.clusterStrength
            model.createdAt = arc.createdAt
            model.updatedAt = arc.updatedAt
            if existing[arc.id] == nil { modelContext.insert(model) }
        }
    }

    private func recordID(forArtifactID artifactID: UUID) -> UUID {
        recordShells.first(where: { $0.artifactIDs.contains(artifactID) })?.id ?? UUID()
    }

    private func artifact(from model: ArtifactStoreModel) -> Artifact {
        Artifact(
            id: model.id,
            kind: ArtifactKind(rawValue: model.kindRawValue) ?? .text,
            title: model.title,
            summary: model.summary,
            textContent: model.textContent,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            metadata: decode(model.metadataData, default: [:]),
            entities: decode(model.entitiesData, default: []),
            binaryPayload: model.binaryPayload,
            previewPayload: model.previewPayload
        )
    }

    private func analysis(from model: RecordAnalysisSnapshotStoreModel) -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            id: model.id,
            recordID: model.recordID,
            summary: model.summary,
            themes: decode(model.themesData, default: []),
            emotionInterpretation: model.emotionInterpretation,
            followUpCandidates: decode(model.followUpCandidatesData, default: []),
            entityMentions: decode(model.entityMentionsData, default: []),
            salienceScore: model.salienceScore,
            retrievalTerms: decode(model.retrievalTermsData, default: []),
            reflectionHint: model.reflectionHint,
            candidateEdges: decode(model.candidateEdgesData, default: []),
            createdAt: model.createdAt
        )
    }

    private func reflection(from model: ReflectionSnapshotStoreModel) -> ReflectionSnapshot {
        ReflectionSnapshot(
            id: model.id,
            type: ReflectionType(rawValue: model.typeRawValue) ?? .record,
            title: model.title,
            body: model.bodyText,
            evidenceSummary: model.evidenceSummary,
            confidence: model.confidence,
            status: ReflectionStatus(rawValue: model.statusRawValue) ?? .active,
            linkedTemporalArcID: model.linkedTemporalArcID,
            sourceRecordIDs: decode(model.sourceRecordIDsData, default: []),
            sourceArtifactIDs: decode(model.sourceArtifactIDsData, default: []),
            sourceEntityIDs: decode(model.sourceEntityIDsData, default: []),
            createdAt: model.createdAt,
            savedAt: model.savedAt,
            dismissedAt: model.dismissedAt
        )
    }

    private func entityNode(from model: EntityNodeStoreModel) -> EntityNode {
        EntityNode(
            id: model.id,
            kind: EntityKind(rawValue: model.kindRawValue) ?? .person,
            displayName: model.displayName,
            canonicalName: model.canonicalName,
            summary: model.summary,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            confidence: model.confidence
        )
    }

    private func entityEdge(from model: EntityEdgeStoreModel) -> EntityEdge {
        EntityEdge(
            id: model.id,
            fromEntityID: model.fromEntityID,
            toEntityID: model.toEntityID,
            relationKind: EntityRelationKind(rawValue: model.relationKindRawValue) ?? .relatedTo,
            weight: model.weight,
            firstSeenAt: model.firstSeenAt,
            lastSeenAt: model.lastSeenAt,
            evidenceCount: model.evidenceCount,
            sourceArtifactIDs: decode(model.sourceArtifactIDsData, default: []),
            sourceRecordIDs: decode(model.sourceRecordIDsData, default: [])
        )
    }

    private func artifactEntityLink(from model: ArtifactEntityLinkStoreModel) -> ArtifactEntityLink {
        ArtifactEntityLink(
            id: model.id,
            artifactID: model.artifactID,
            entityID: model.entityID,
            confidence: model.confidence,
            source: model.source,
            createdAt: model.createdAt
        )
    }

    private func temporalArc(from model: TemporalArcStoreModel) -> TemporalArc {
        TemporalArc(
            id: model.id,
            title: model.title,
            summary: model.summary,
            status: TemporalArcStatus(rawValue: model.statusRawValue) ?? .candidate,
            dominantTheme: model.dominantTheme,
            dominantEntityName: model.dominantEntityName,
            themeLabels: decode(model.themeLabelsData, default: []),
            entityNames: decode(model.entityNamesData, default: []),
            linkedReflectionID: model.linkedReflectionID,
            mergedFromArcIDs: decode(model.mergedFromArcIDsData, default: []),
            mergedIntoArcID: model.mergedIntoArcID,
            lastMergedAt: model.lastMergedAt,
            sourceRecordIDs: decode(model.sourceRecordIDsData, default: []),
            sourceArtifactIDs: decode(model.sourceArtifactIDsData, default: []),
            sourceEntityIDs: decode(model.sourceEntityIDsData, default: []),
            startDate: model.startDate,
            endDate: model.endDate,
            intensityScore: model.intensityScore,
            clusterStrength: model.clusterStrength,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func decode<T: Decodable>(_ data: Data, default defaultValue: T) -> T {
        guard !data.isEmpty else { return defaultValue }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
    }


    private func rebuildTemporalArcs() {
        let existingArcs = temporalArcs
        let existingPhaseReflections = reflections.filter { $0.type == .phase }
        let bundles = temporalArcService.rebuildAcceptedBundles(
            records: recordShells,
            analyses: analyses,
            artifacts: artifacts,
            artifactEntityLinks: artifactEntityLinks,
            entityNodes: entityNodes
        )

        let preservedBundles = bundles.map {
            preservePhaseBundle(
                $0,
                existingArcs: existingArcs,
                existingPhaseReflections: existingPhaseReflections
            )
        }

        temporalArcs = preservedBundles.map(\.arc)
        reflections.removeAll { $0.type == .phase }
        reflections.append(contentsOf: preservedBundles.map(\.reflection))
    }

    private func upsertRecordReflection(
        for analysis: RecordAnalysisSnapshot,
        aggregate: SproutMemoryAggregate,
        sourceEntityIDs: [UUID]
    ) {
        let recordID = aggregate.recordShell.id
        let existing = recordReflection(forRecordID: recordID)
        let linkedArcID = temporalArcs.first {
            $0.status == .accepted && $0.sourceRecordIDs.contains(recordID)
        }?.id

        let reflection = ReflectionSnapshot(
            id: existing?.id ?? UUID(),
            type: .record,
            title: existing?.title ?? recordReflectionTitle(for: analysis, aggregate: aggregate),
            body: existing?.body ?? recordReflectionBody(for: analysis, aggregate: aggregate),
            evidenceSummary: existing?.evidenceSummary ?? recordReflectionEvidenceSummary(
                analysis: analysis,
                artifactCount: aggregate.artifacts.count,
                entityCount: sourceEntityIDs.count
            ),
            confidence: analysis.salienceScore.map { min(max($0, 0), 1) },
            status: existing?.status ?? .active,
            linkedTemporalArcID: existing?.linkedTemporalArcID ?? linkedArcID,
            sourceRecordIDs: [recordID],
            sourceArtifactIDs: aggregate.artifacts.map(\.id),
            sourceEntityIDs: sourceEntityIDs,
            createdAt: existing?.createdAt ?? analysis.createdAt,
            savedAt: existing?.savedAt,
            dismissedAt: existing?.dismissedAt
        )

        if let index = reflections.firstIndex(where: {
            $0.type == .record && $0.sourceRecordIDs.contains(recordID)
        }) {
            reflections[index] = reflection
        } else {
            reflections.append(reflection)
        }
    }

    private func recordReflectionTitle(
        for analysis: RecordAnalysisSnapshot,
        aggregate: SproutMemoryAggregate
    ) -> String {
        if let theme = analysis.tags.first?.trimmingCharacters(in: .whitespacesAndNewlines), !theme.isEmpty {
            return "\(theme.capitalized) Reflection"
        }
        if let mood = aggregate.recordShell.userMood?.trimmingCharacters(in: .whitespacesAndNewlines), !mood.isEmpty {
            return "\(mood.capitalized) Reflection"
        }
        let emotion = analysis.emotionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !emotion.isEmpty {
            return "\(emotion.capitalized) Reflection"
        }
        return "Record Reflection"
    }

    private func recordReflectionBody(
        for analysis: RecordAnalysisSnapshot,
        aggregate: SproutMemoryAggregate
    ) -> String {
        if let hint = analysis.reflectionHint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            return hint
        }

        var parts: [String] = []
        let insight = analysis.insight.trimmingCharacters(in: .whitespacesAndNewlines)
        if !insight.isEmpty {
            parts.append(insight)
        }

        let themes = analysis.tags.prefix(3)
        if !themes.isEmpty {
            parts.append("Themes: \(themes.joined(separator: " · "))")
        }

        let entities = analysis.entities.prefix(3).map(\.name)
        if !entities.isEmpty {
            parts.append("Entities: \(entities.joined(separator: " · "))")
        }

        parts.append("Captured via \(aggregate.recordShell.captureSource.rawValue.replacingOccurrences(of: "_", with: " ")).")
        return parts.joined(separator: "\n\n")
    }

    private func recordReflectionEvidenceSummary(
        analysis: RecordAnalysisSnapshot,
        artifactCount: Int,
        entityCount: Int
    ) -> String? {
        let parts = [
            artifactCount > 0 ? "\(artifactCount) artifacts" : nil,
            entityCount > 0 ? "\(entityCount) entities" : nil,
            analysis.tags.isEmpty ? nil : analysis.tags.prefix(3).joined(separator: " · ")
        ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func recordShells(on referenceDate: Date) -> [RecordShell] {
        let calendar = Calendar.current
        return recordShells.filter { calendar.isDate($0.createdAt, inSameDayAs: referenceDate) }
    }

    private func temporalArcSort(lhs: TemporalArc, rhs: TemporalArc) -> Bool {
        if lhs.endDate == rhs.endDate {
            return lhs.intensityScore > rhs.intensityScore
        }
        return lhs.endDate > rhs.endDate
    }

    private func peopleIndexSort(lhs: PersonIndexEntry, rhs: PersonIndexEntry) -> Bool {
        if lhs.graphCentrality != rhs.graphCentrality {
            return lhs.graphCentrality > rhs.graphCentrality
        }
        if lhs.totalEdgeWeight != rhs.totalEdgeWeight {
            return lhs.totalEdgeWeight > rhs.totalEdgeWeight
        }
        if lhs.totalEvidenceCount == rhs.totalEvidenceCount {
            if lhs.lastSeenAt != rhs.lastSeenAt {
                return lhs.lastSeenAt ?? .distantPast > rhs.lastSeenAt ?? .distantPast
            }
        }
        return lhs.totalEvidenceCount > rhs.totalEvidenceCount
    }

    private func searchTokens(for query: String) -> [String] {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private func searchScore(in fields: [String], tokens: [String]) -> Int? {
        let normalizedFields = fields
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !normalizedFields.isEmpty else { return nil }

        var total = 0
        for token in tokens {
            var best = 0
            for field in normalizedFields {
                if field == token {
                    best = max(best, 120)
                } else if field.hasPrefix(token) {
                    best = max(best, 90)
                } else if field.contains(token) {
                    best = max(best, 60)
                }
            }

            guard best > 0 else { return nil }
            total += best
        }

        return total
    }

    private func orderedUniqueNames(from entities: [EntityNode], matching kind: EntityKind) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for entity in entities where entity.kind == kind {
            let name = entity.displayName
            guard seen.insert(name).inserted else { continue }
            ordered.append(name)
        }
        return ordered
    }

    private func preservePhaseBundle(
        _ bundle: SproutTemporalArcService.PhaseBundle,
        existingArcs: [TemporalArc],
        existingPhaseReflections: [ReflectionSnapshot]
    ) -> SproutTemporalArcService.PhaseBundle {
        guard let existingArc = bestMatchingArc(for: bundle.arc, in: existingArcs) else {
            return bundle
        }

        let existingReflection = existingReflection(
            for: existingArc,
            in: existingPhaseReflections
        )
        let reflectionID = existingReflection?.id ?? existingArc.linkedReflectionID ?? bundle.reflection.id

        var arc = bundle.arc
        arc.id = existingArc.id
        arc.status = existingArc.status
        arc.linkedReflectionID = reflectionID
        arc.mergedFromArcIDs = existingArc.mergedFromArcIDs
        arc.mergedIntoArcID = existingArc.mergedIntoArcID
        arc.lastMergedAt = existingArc.lastMergedAt
        arc.createdAt = existingArc.createdAt
        arc.updatedAt = bundle.arc.updatedAt

        let reflection = ReflectionSnapshot(
            id: reflectionID,
            type: .phase,
            title: existingReflection?.title ?? bundle.reflection.title,
            body: existingReflection?.body ?? bundle.reflection.body,
            evidenceSummary: existingReflection?.evidenceSummary ?? bundle.reflection.evidenceSummary,
            confidence: bundle.reflection.confidence ?? existingReflection?.confidence,
            status: existingReflection?.status ?? bundle.reflection.status,
            linkedTemporalArcID: arc.id,
            sourceRecordIDs: bundle.reflection.sourceRecordIDs,
            sourceArtifactIDs: bundle.reflection.sourceArtifactIDs,
            sourceEntityIDs: bundle.reflection.sourceEntityIDs,
            createdAt: existingReflection?.createdAt ?? bundle.reflection.createdAt,
            savedAt: existingReflection?.savedAt,
            dismissedAt: existingReflection?.dismissedAt
        )

        return SproutTemporalArcService.PhaseBundle(arc: arc, reflection: reflection)
    }

    private func bestMatchingArc(for rebuiltArc: TemporalArc, in existingArcs: [TemporalArc]) -> TemporalArc? {
        existingArcs
            .map { arc in (arc: arc, score: arcReuseScore(rebuiltArc, arc)) }
            .filter { $0.score >= 0.55 }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return temporalArcSort(lhs: lhs.arc, rhs: rhs.arc)
                }
                return lhs.score > rhs.score
            }
            .first?
            .arc
    }

    private func existingReflection(
        for arc: TemporalArc,
        in existingPhaseReflections: [ReflectionSnapshot]
    ) -> ReflectionSnapshot? {
        if let linkedReflectionID = arc.linkedReflectionID,
           let linked = existingPhaseReflections.first(where: { $0.id == linkedReflectionID }) {
            return linked
        }

        let sourceRecordIDs = Set(arc.sourceRecordIDs)
        return existingPhaseReflections.first {
            guard $0.type == .phase else { return false }
            if $0.linkedTemporalArcID == arc.id {
                return true
            }
            return !sourceRecordIDs.isEmpty && Set($0.sourceRecordIDs) == sourceRecordIDs
        }
    }

    private func arcReuseScore(_ lhs: TemporalArc, _ rhs: TemporalArc) -> Double {
        let recordOverlap = overlapScore(lhs.sourceRecordIDs, rhs.sourceRecordIDs)
        let artifactOverlap = overlapScore(lhs.sourceArtifactIDs, rhs.sourceArtifactIDs)
        let entityOverlap = overlapScore(lhs.sourceEntityIDs, rhs.sourceEntityIDs)
        let titleMatch = lhs.title == rhs.title ? 0.1 : 0
        let intervalScore = intervalReuseScore(lhs, rhs)

        return recordOverlap * 0.50
            + artifactOverlap * 0.20
            + entityOverlap * 0.10
            + intervalScore * 0.10
            + titleMatch
    }

    private func overlapScore<T: Hashable>(_ lhs: [T], _ rhs: [T]) -> Double {
        let left = Set(lhs)
        let right = Set(rhs)
        guard !left.isEmpty || !right.isEmpty else { return 0 }
        let union = left.union(right)
        guard !union.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(union.count)
    }

    private func intervalReuseScore(_ lhs: TemporalArc, _ rhs: TemporalArc) -> Double {
        let overlapStart = max(lhs.startDate, rhs.startDate)
        let overlapEnd = min(lhs.endDate, rhs.endDate)
        let overlap = overlapEnd.timeIntervalSince(overlapStart)
        if overlap > 0 {
            let leftDuration = max(lhs.endDate.timeIntervalSince(lhs.startDate), 1)
            let rightDuration = max(rhs.endDate.timeIntervalSince(rhs.startDate), 1)
            return min(overlap / min(leftDuration, rightDuration), 1)
        }

        let boundaryGap = min(
            abs(lhs.startDate.timeIntervalSince(rhs.endDate)),
            abs(lhs.endDate.timeIntervalSince(rhs.startDate))
        )
        let twoWeeks: TimeInterval = 60 * 60 * 24 * 14
        return max(0, 1 - boundaryGap / twoWeeks)
    }
}
