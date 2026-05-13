import Foundation
import Observation

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

        var id: UUID { entity.id }
    }

    struct SearchResults: Sendable {
        var entities: [EntityNode]
        var arcs: [TemporalArc]
        var records: [RecordShell]
        var artifacts: [Artifact]
        var reflections: [ReflectionSnapshot]
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

    struct Snapshot: Codable, Sendable {
        var recordShells: [RecordShell]
        var artifacts: [Artifact]
        var analyses: [RecordAnalysisSnapshot]
        var reflections: [ReflectionSnapshot]
        var entityNodes: [EntityNode]
        var entityEdges: [EntityEdge]
        var artifactEntityLinks: [ArtifactEntityLink]
        var temporalArcs: [TemporalArc]

        enum CodingKeys: String, CodingKey {
            case recordShells
            case artifacts
            case analyses
            case reflections
            case entityNodes
            case entityEdges
            case artifactEntityLinks
            case temporalArcs
        }

        init(
            recordShells: [RecordShell],
            artifacts: [Artifact],
            analyses: [RecordAnalysisSnapshot],
            reflections: [ReflectionSnapshot],
            entityNodes: [EntityNode],
            entityEdges: [EntityEdge],
            artifactEntityLinks: [ArtifactEntityLink],
            temporalArcs: [TemporalArc]
        ) {
            self.recordShells = recordShells
            self.artifacts = artifacts
            self.analyses = analyses
            self.reflections = reflections
            self.entityNodes = entityNodes
            self.entityEdges = entityEdges
            self.artifactEntityLinks = artifactEntityLinks
            self.temporalArcs = temporalArcs
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            recordShells = try container.decode([RecordShell].self, forKey: .recordShells)
            artifacts = try container.decode([Artifact].self, forKey: .artifacts)
            analyses = try container.decode([RecordAnalysisSnapshot].self, forKey: .analyses)
            reflections = try container.decodeIfPresent([ReflectionSnapshot].self, forKey: .reflections) ?? []
            entityNodes = try container.decode([EntityNode].self, forKey: .entityNodes)
            entityEdges = try container.decode([EntityEdge].self, forKey: .entityEdges)
            artifactEntityLinks = try container.decode([ArtifactEntityLink].self, forKey: .artifactEntityLinks)
            temporalArcs = try container.decodeIfPresent([TemporalArc].self, forKey: .temporalArcs) ?? []
        }
    }

    private let graphUpdater = GraphUpdater()
    private let analysisEntityMatcher = AnalysisEntityMatcher()
    private let temporalArcService = SproutTemporalArcService()

    var recordShells: [RecordShell] = []
    var artifacts: [Artifact] = []
    var analyses: [RecordAnalysisSnapshot] = []
    var reflections: [ReflectionSnapshot] = []
    var entityNodes: [EntityNode] = []
    var entityEdges: [EntityEdge] = []
    var artifactEntityLinks: [ArtifactEntityLink] = []
    var temporalArcs: [TemporalArc] = []

    init() {
        load()
    }

    func upsertAggregate(_ aggregate: SproutMemoryAggregate) {
        recordShells.removeAll { $0.id == aggregate.recordShell.id }
        recordShells.append(aggregate.recordShell)

        let aggregateArtifactIDs = Set(aggregate.artifacts.map(\.id))
        artifacts.removeAll { aggregateArtifactIDs.contains($0.id) }
        artifacts.append(contentsOf: aggregate.artifacts)

        save()
    }

    func setAnalysis(_ analysis: RecordAnalysisSnapshot, aggregate: SproutMemoryAggregate) {
        upsertAggregate(aggregate)
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
        save()
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

    func archiveTemporalArc(_ arcID: UUID) {
        guard let index = temporalArcs.firstIndex(where: { $0.id == arcID }) else { return }
        temporalArcs[index].status = .archived
        temporalArcs[index].updatedAt = .now
        save()
    }

    func restoreTemporalArc(_ arcID: UUID) {
        guard let index = temporalArcs.firstIndex(where: { $0.id == arcID }) else { return }
        temporalArcs[index].status = .accepted
        temporalArcs[index].updatedAt = .now
        save()
    }

    func saveReflection(_ reflectionID: UUID) {
        guard let index = reflections.firstIndex(where: { $0.id == reflectionID }) else { return }
        reflections[index].status = .saved
        reflections[index].savedAt = .now
        reflections[index].dismissedAt = nil
        save()
    }

    func dismissReflection(_ reflectionID: UUID) {
        guard let index = reflections.firstIndex(where: { $0.id == reflectionID }) else { return }
        reflections[index].status = .dismissed
        reflections[index].dismissedAt = .now
        save()
    }

    func reactivateReflection(_ reflectionID: UUID) {
        guard let index = reflections.firstIndex(where: { $0.id == reflectionID }) else { return }
        reflections[index].status = .active
        reflections[index].dismissedAt = nil
        save()
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

                return PersonIndexEntry(
                    entity: person,
                    relatedRecordCount: entityView.relatedRecords.count,
                    relatedArtifactCount: entityView.relatedArtifacts.count,
                    relatedEntityCount: entityView.relatedEntities.count,
                    themeNames: Array(themeNames.prefix(3)),
                    placeNames: Array(placeNames.prefix(3)),
                    arcTitles: arcTitles,
                    lastSeenAt: lastSeenAt
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

    private func storageURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("SproutMemory", isDirectory: true)
            .appendingPathComponent("memory_snapshot.json")
    }

    private func load() {
        guard let url = storageURL() else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        recordShells = snapshot.recordShells
        artifacts = snapshot.artifacts
        analyses = snapshot.analyses
        reflections = snapshot.reflections
        entityNodes = snapshot.entityNodes
        entityEdges = snapshot.entityEdges
        artifactEntityLinks = snapshot.artifactEntityLinks
        temporalArcs = snapshot.temporalArcs
        if temporalArcs.isEmpty && !analyses.isEmpty {
            rebuildTemporalArcs()
        }
    }

    private func save() {
        guard let url = storageURL() else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = Snapshot(
            recordShells: recordShells,
            artifacts: artifacts,
            analyses: analyses,
            reflections: reflections,
            entityNodes: entityNodes,
            entityEdges: entityEdges,
            artifactEntityLinks: artifactEntityLinks,
            temporalArcs: temporalArcs
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func rebuildTemporalArcs() {
        let bundles = temporalArcService.rebuildAcceptedBundles(
            records: recordShells,
            analyses: analyses,
            artifacts: artifacts,
            artifactEntityLinks: artifactEntityLinks,
            entityNodes: entityNodes
        )
        temporalArcs = bundles.map(\.arc)
        reflections.removeAll { $0.type == .phase }
        reflections.append(contentsOf: bundles.map(\.reflection))
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
            title: recordReflectionTitle(for: analysis, aggregate: aggregate),
            body: recordReflectionBody(for: analysis, aggregate: aggregate),
            evidenceSummary: recordReflectionEvidenceSummary(
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
        if lhs.relatedRecordCount == rhs.relatedRecordCount {
            if lhs.relatedArtifactCount == rhs.relatedArtifactCount {
                switch (lhs.lastSeenAt, rhs.lastSeenAt) {
                case let (left?, right?) where left != right:
                    return left > right
                default:
                    return lhs.entity.displayName.localizedCaseInsensitiveCompare(rhs.entity.displayName) == .orderedAscending
                }
            }
            return lhs.relatedArtifactCount > rhs.relatedArtifactCount
        }
        return lhs.relatedRecordCount > rhs.relatedRecordCount
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
}
