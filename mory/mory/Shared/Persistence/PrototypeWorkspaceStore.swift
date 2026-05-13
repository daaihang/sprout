import Foundation
import Observation

@Observable
final class PrototypeWorkspaceStore {
    private let graphInsightsBuilder = GraphInsightsBuilder()
    private let analysisService = PrototypeAnalysisService()
    private let temporalArcService = PrototypeTemporalArcService()

    var scenarioName: String
    var boards: [Board]
    var compositions: [Composition]
    var items: [CompositionItem]
    var records: [RecordShell]
    var artifacts: [Artifact]
    var reflections: [ReflectionSnapshot]
    var temporalArcs: [TemporalArc]
    var analyses: [RecordAnalysisSnapshot]
    var entityNodes: [EntityNode]
    var entityEdges: [EntityEdge]
    var artifactEntityLinks: [ArtifactEntityLink]
    var lastAnalyzedRecordID: UUID?
    var draftArtifact: Artifact?
    var draftRecord: RecordShell?

    init(
        scenarioName: String,
        boards: [Board],
        compositions: [Composition],
        items: [CompositionItem],
        records: [RecordShell],
        artifacts: [Artifact],
        reflections: [ReflectionSnapshot],
        temporalArcs: [TemporalArc],
        analyses: [RecordAnalysisSnapshot],
        entityNodes: [EntityNode],
        entityEdges: [EntityEdge],
        artifactEntityLinks: [ArtifactEntityLink]
    ) {
        self.scenarioName = scenarioName
        self.boards = boards
        self.compositions = compositions
        self.items = items
        self.records = records
        self.artifacts = artifacts
        self.reflections = reflections
        self.temporalArcs = temporalArcs
        self.analyses = analyses
        self.entityNodes = entityNodes
        self.entityEdges = entityEdges
        self.artifactEntityLinks = artifactEntityLinks
        self.lastAnalyzedRecordID = nil
        self.draftArtifact = nil
        self.draftRecord = nil
    }

    static func makeDefault() -> PrototypeWorkspaceStore {
        let snapshot = PrototypeWorkspaceRepository.loadDefaultSnapshot()
        return PrototypeWorkspaceStore(
            scenarioName: snapshot.scenarioName,
            boards: snapshot.boards,
            compositions: snapshot.compositions,
            items: snapshot.items,
            records: snapshot.records,
            artifacts: snapshot.artifacts,
            reflections: snapshot.reflections,
            temporalArcs: snapshot.temporalArcs,
            analyses: snapshot.analyses,
            entityNodes: snapshot.entityNodes,
            entityEdges: snapshot.entityEdges,
            artifactEntityLinks: snapshot.artifactEntityLinks
        )
    }

    func compositionItems(for boardID: UUID) -> [CompositionItem] {
        let compositionIDs = compositions
            .filter { $0.boardID == boardID }
            .map(\.id)
        return items
            .filter { compositionIDs.contains($0.compositionID) }
            .sorted { lhs, rhs in
                if lhs.zIndex == rhs.zIndex { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.zIndex < rhs.zIndex
            }
    }

    func update(
        itemID: UUID,
        widthUnits: Int? = nil,
        heightUnits: Int? = nil,
        zIndex: Int? = nil,
        rotation: Double? = nil,
        scale: Double? = nil,
        positionHint: CompositionPositionHint? = nil
    ) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if let widthUnits { items[index].widthUnits = max(widthUnits, 1) }
        if let heightUnits { items[index].heightUnits = max(heightUnits, 1) }
        if let zIndex { items[index].zIndex = zIndex }
        if let rotation { items[index].rotation = rotation }
        if let scale { items[index].scale = max(scale, 0.4) }
        if let positionHint { items[index].positionHint = positionHint }
    }

    func setAnalysis(_ analysis: RecordAnalysisSnapshot) {
        let result = analysisService.applyAnalysis(
            analysis: analysis,
            records: records,
            analyses: analyses,
            artifacts: artifacts,
            entityNodes: entityNodes,
            entityEdges: entityEdges,
            artifactEntityLinks: artifactEntityLinks
        )
        analyses = result.analyses
        entityNodes = result.entityNodes
        entityEdges = result.entityEdges
        artifactEntityLinks = result.artifactEntityLinks
        artifacts = result.artifacts
        lastAnalyzedRecordID = result.lastAnalyzedRecordID
    }

    func setReflection(_ reflection: ReflectionSnapshot, for recordID: UUID) {
        reflections.removeAll { $0.type == .record && $0.sourceRecordIDs == [recordID] }
        reflections.append(reflection)
    }

    func reload(from scenario: DemoScenario) {
        let snapshot = PrototypeWorkspaceRepository.snapshot(from: scenario)
        scenarioName = snapshot.scenarioName
        boards = snapshot.boards
        compositions = snapshot.compositions
        items = snapshot.items
        records = snapshot.records
        artifacts = snapshot.artifacts
        reflections = snapshot.reflections
        temporalArcs = snapshot.temporalArcs
        analyses = snapshot.analyses
        entityNodes = snapshot.entityNodes
        entityEdges = snapshot.entityEdges
        artifactEntityLinks = snapshot.artifactEntityLinks
        lastAnalyzedRecordID = nil
        draftArtifact = nil
        draftRecord = nil
    }

    func snapshot() -> DemoWorkspaceSnapshot {
        DemoWorkspaceSnapshot(
            scenarioName: scenarioName,
            boards: boards,
            compositions: compositions,
            items: items,
            records: records,
            artifacts: artifacts,
            reflections: reflections,
            temporalArcs: temporalArcs,
            analyses: analyses,
            entityNodes: entityNodes,
            entityEdges: entityEdges,
            artifactEntityLinks: artifactEntityLinks
        )
    }

    func analysis(for recordID: UUID) -> RecordAnalysisSnapshot? {
        analyses.first(where: { $0.recordID == recordID })
    }

    func linkedArtifacts(for recordID: UUID) -> [Artifact] {
        guard let record = records.first(where: { $0.id == recordID }) else { return [] }
        return artifacts.filter { record.artifactIDs.contains($0.id) }
    }

    func artifact(for artifactID: UUID) -> Artifact? {
        artifacts.first(where: { $0.id == artifactID })
    }

    func record(for recordID: UUID) -> RecordShell? {
        records.first(where: { $0.id == recordID })
    }

    func entityNode(for entityID: UUID) -> EntityNode? {
        entityNodes.first(where: { $0.id == entityID })
    }

    func sortedEntityNodes() -> [EntityNode] {
        entityNodes.sorted {
            if $0.kind == $1.kind {
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            return $0.kind.rawValue < $1.kind.rawValue
        }
    }

    func filteredEntityNodes(
        searchText: String,
        kind: EntityKind?
    ) -> [EntityNode] {
        sortedEntityNodes().filter { entity in
            let matchesKind = kind.map { entity.kind == $0 } ?? true
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    entity.displayName.localizedCaseInsensitiveContains(searchText) ||
                    entity.canonicalName.localizedCaseInsensitiveContains(searchText) ||
                    entity.summary.localizedCaseInsensitiveContains(searchText)
            }
            return matchesKind && matchesSearch
        }
    }

    func graphInsights(limit: Int = 3) -> GraphInsightsSnapshot {
        graphInsightsBuilder.build(
            entityNodes: entityNodes,
            entityEdges: entityEdges,
            artifactEntityLinks: artifactEntityLinks,
            records: records,
            artifacts: artifacts,
            limit: limit
        )
    }

    func temporalArcCandidates(limit: Int = 4) -> [TemporalArcCandidate] {
        temporalArcService.buildCandidates(
            records: records,
            analyses: analyses,
            artifacts: artifacts,
            artifactEntityLinks: artifactEntityLinks,
            entityNodes: entityNodes,
            limit: limit
        )
    }

    func promoteTemporalArc(from candidate: TemporalArcCandidate) -> UUID {
        let promotion = temporalArcService.promote(
            candidate: candidate,
            analyses: analyses,
            artifactEntityLinks: artifactEntityLinks,
            entityNodes: entityNodes
        )
        let arc = promotion.arc
        let reflection = promotion.reflection

        temporalArcs.removeAll { existingArc in
            Set(existingArc.sourceRecordIDs) == Set(candidate.recordIDs)
        }
        temporalArcs.insert(arc, at: 0)

        reflections.removeAll {
            $0.type == .phase && Set($0.sourceRecordIDs) == Set(arc.sourceRecordIDs)
        }
        reflections.insert(reflection, at: 0)

        return arc.id
    }

    func temporalArc(for arcID: UUID) -> TemporalArc? {
        temporalArcs.first(where: { $0.id == arcID })
    }

    func reflection(for reflectionID: UUID) -> ReflectionSnapshot? {
        reflections.first(where: { $0.id == reflectionID })
    }

    func linkedReflection(forArcID arcID: UUID) -> ReflectionSnapshot? {
        guard let reflectionID = temporalArc(for: arcID)?.linkedReflectionID else { return nil }
        return reflection(for: reflectionID)
    }

    func linkedTemporalArc(forReflectionID reflectionID: UUID) -> TemporalArc? {
        guard let arcID = reflection(for: reflectionID)?.linkedTemporalArcID else { return nil }
        return temporalArc(for: arcID)
    }

    func mergePreview(for arcID: UUID) -> TemporalArcMergePreview? {
        temporalArcService.mergePreview(sourceArcID: arcID, arcs: temporalArcs)
    }

    func mergeTemporalArc(_ sourceArcID: UUID, with candidateArcID: UUID) {
        guard let sourceArc = temporalArc(for: sourceArcID),
              let candidateArc = temporalArc(for: candidateArcID),
              let sourceIndex = temporalArcs.firstIndex(where: { $0.id == sourceArcID }),
              let candidateIndex = temporalArcs.firstIndex(where: { $0.id == candidateArcID }) else { return }

        let linkedReflection = sourceArc.linkedReflectionID.flatMap { reflectionID in
            reflections.first(where: { $0.id == reflectionID })
        }
        let result = temporalArcService.merge(
            sourceArc: sourceArc,
            candidateArc: candidateArc,
            linkedReflection: linkedReflection
        )

        temporalArcs[sourceIndex] = result.sourceArc
        temporalArcs[candidateIndex] = result.candidateArc

        if let updatedReflection = result.updatedReflection,
           let reflectionIndex = reflections.firstIndex(where: { $0.id == updatedReflection.id }) {
            reflections[reflectionIndex] = updatedReflection
        }
        if let candidateReflectionID = result.candidateReflectionIDToRemove {
            reflections.removeAll { $0.id == candidateReflectionID }
        }
    }

    func sortedTemporalArcs() -> [TemporalArc] {
        temporalArcs.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.startDate > rhs.startDate
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func updateTemporalArcStatus(_ status: TemporalArcStatus, for arcID: UUID) {
        guard let index = temporalArcs.firstIndex(where: { $0.id == arcID }) else { return }
        temporalArcs[index].status = status
        temporalArcs[index].updatedAt = .now
    }

    func linkedRecords(forArcID arcID: UUID) -> [RecordShell] {
        guard let arc = temporalArc(for: arcID) else { return [] }
        let recordIDs = Set(arc.sourceRecordIDs)
        return records
            .filter { recordIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func linkedArtifacts(forArcID arcID: UUID) -> [Artifact] {
        guard let arc = temporalArc(for: arcID) else { return [] }
        let artifactIDs = Set(arc.sourceArtifactIDs)
        return artifacts
            .filter { artifactIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func linkedEntities(forArcID arcID: UUID) -> [EntityNode] {
        guard let arc = temporalArc(for: arcID) else { return [] }
        let entityIDs = Set(arc.sourceEntityIDs)
        return entityNodes
            .filter { entityIDs.contains($0.id) }
            .sorted { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    func linkedRecordIDs(for artifactID: UUID) -> [UUID] {
        records
            .filter { $0.artifactIDs.contains(artifactID) }
            .map(\.id)
    }

    func linkedEntities(forArtifactID artifactID: UUID) -> [EntityNode] {
        let ids = artifactEntityLinks
            .filter { $0.artifactID == artifactID }
            .map(\.entityID)
        return entityNodes.filter { ids.contains($0.id) }
    }

    func linkedEntities(forRecordID recordID: UUID) -> [EntityNode] {
        let artifactIDs = records.first(where: { $0.id == recordID })?.artifactIDs ?? []
        let entityIDs = artifactEntityLinks
            .filter { artifactIDs.contains($0.artifactID) }
            .map(\.entityID)
        return entityNodes.filter { entityIDs.contains($0.id) }
    }

    func linkedArtifacts(forEntityID entityID: UUID) -> [Artifact] {
        let artifactIDs = artifactEntityLinks
            .filter { $0.entityID == entityID }
            .map(\.artifactID)
        return artifacts.filter { artifactIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func linkedRecords(forEntityID entityID: UUID) -> [RecordShell] {
        let artifactIDs = Set(
            artifactEntityLinks
                .filter { $0.entityID == entityID }
                .map(\.artifactID)
        )
        return records
            .filter { !$0.artifactIDs.filter(artifactIDs.contains).isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func connectedEdges(forEntityID entityID: UUID) -> [EntityEdge] {
        entityEdges
            .filter { $0.fromEntityID == entityID || $0.toEntityID == entityID }
            .sorted { lhs, rhs in
                if lhs.evidenceCount == rhs.evidenceCount {
                    return lhs.weight > rhs.weight
                }
                return lhs.evidenceCount > rhs.evidenceCount
            }
    }

    func entityOccurrenceCount(for entityID: UUID) -> Int {
        artifactEntityLinks.filter { $0.entityID == entityID }.count
    }

    func entityLastSeenDate(for entityID: UUID) -> Date? {
        let directUpdatedAt = entityNode(for: entityID)?.updatedAt
        let recordDates = linkedRecords(forEntityID: entityID).map(\.updatedAt)
        return ([directUpdatedAt].compactMap { $0 } + recordDates).max()
    }

    func counterpartEntityID(for edge: EntityEdge, relativeTo entityID: UUID) -> UUID? {
        if edge.fromEntityID == entityID { return edge.toEntityID }
        if edge.toEntityID == entityID { return edge.fromEntityID }
        return nil
    }

    func sharedArtifacts(for edge: EntityEdge) -> [Artifact] {
        let sharedIDs = Set(edge.sourceArtifactIDs)
        return artifacts.filter { sharedIDs.contains($0.id) }
    }

    func sharedRecords(for edge: EntityEdge) -> [RecordShell] {
        let sharedIDs = Set(edge.sourceRecordIDs)
        return records.filter { sharedIDs.contains($0.id) }
    }

    func beginArtifactDraft() {
        draftArtifact = Artifact(
            kind: .text,
            title: "",
            summary: "",
            createdAt: .now,
            updatedAt: .now
        )
    }

    func beginRecordDraft() {
        draftRecord = RecordShell(
            createdAt: .now,
            updatedAt: .now,
            rawText: "",
            captureSource: .manual,
            artifactIDs: []
        )
    }

    @discardableResult
    func saveDraftArtifact(linkToRecordID: UUID? = nil) -> UUID? {
        guard var draftArtifact else { return nil }
        draftArtifact.updatedAt = .now
        artifacts.insert(draftArtifact, at: 0)
        if let linkToRecordID {
            appendArtifactLink(draftArtifact.id, to: linkToRecordID)
        }
        self.draftArtifact = nil
        return draftArtifact.id
    }

    @discardableResult
    func saveDraftRecord(linkedArtifactIDs: [UUID] = []) -> UUID? {
        guard var draftRecord else { return nil }
        draftRecord.updatedAt = .now
        if !linkedArtifactIDs.isEmpty {
            draftRecord.artifactIDs = Array(Set(draftRecord.artifactIDs + linkedArtifactIDs))
        }
        records.insert(draftRecord, at: 0)
        self.draftRecord = nil
        return draftRecord.id
    }

    func cancelDraftArtifact() {
        draftArtifact = nil
    }

    func cancelDraftRecord() {
        draftRecord = nil
    }

    func updateDraftArtifact(
        title: String? = nil,
        summary: String? = nil,
        textContent: String? = nil,
        kind: ArtifactKind? = nil
    ) {
        guard draftArtifact != nil else { return }
        if let title { draftArtifact?.title = title }
        if let summary { draftArtifact?.summary = summary }
        if let textContent { draftArtifact?.textContent = textContent }
        if let kind { draftArtifact?.kind = kind }
    }

    func updateDraftRecord(
        rawText: String? = nil,
        captureSource: CaptureSource? = nil,
        userMood: String? = nil,
        userIntensity: Int? = nil
    ) {
        guard draftRecord != nil else { return }
        if let rawText { draftRecord?.rawText = rawText }
        if let captureSource { draftRecord?.captureSource = captureSource }
        if let userMood { draftRecord?.userMood = userMood }
        if let userIntensity { draftRecord?.userIntensity = userIntensity }
    }

    private func appendArtifactLink(_ artifactID: UUID, to recordID: UUID) {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return }
        if !records[index].artifactIDs.contains(artifactID) {
            records[index].artifactIDs.append(artifactID)
            records[index].updatedAt = .now
        }
    }

}
