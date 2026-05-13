import Foundation

struct DemoScenario: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let boards: [Board]
    let compositions: [Composition]
    let items: [CompositionItem]
    let records: [RecordShell]
    let artifacts: [Artifact]
    let reflections: [ReflectionSnapshot]
    let temporalArcs: [TemporalArc]
    let analyses: [RecordAnalysisSnapshot]
    let entityNodes: [EntityNode]
    let entityEdges: [EntityEdge]
    let artifactEntityLinks: [ArtifactEntityLink]

    init(
        id: UUID = UUID(),
        name: String,
        boards: [Board],
        compositions: [Composition],
        items: [CompositionItem],
        records: [RecordShell],
        artifacts: [Artifact],
        reflections: [ReflectionSnapshot],
        temporalArcs: [TemporalArc] = [],
        analyses: [RecordAnalysisSnapshot],
        entityNodes: [EntityNode] = [],
        entityEdges: [EntityEdge] = [],
        artifactEntityLinks: [ArtifactEntityLink] = []
    ) {
        self.id = id
        self.name = name
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
    }
}

enum DemoScenarios {
    static func all() -> [DemoScenario] {
        [
            relationshipArc(),
            relocationPhase(),
            workDecisionPhase()
        ]
    }

    static func relationshipArc() -> DemoScenario {
        let now = Date()
        let board = Board(kind: .homeDay, title: "Relationship Arc", subtitle: "A gentle memory board", createdAt: now)
        let composition = Composition(boardID: board.id, title: "Main Composition", sortOrder: 0, createdAt: now, updatedAt: now)
        let person = EntityNode(kind: .person, displayName: "Lina", summary: "Stabilizing figure around departure decisions.", createdAt: now, updatedAt: now)
        let place = EntityNode(kind: .place, displayName: "Bund", summary: "Recurring location marker for reflective evenings.", createdAt: now, updatedAt: now)
        let theme = EntityNode(kind: .theme, displayName: "change", summary: "Signals transition and possible departure.", createdAt: now, updatedAt: now)
        let artifact1 = Artifact(kind: .text, title: "Late-night walk", summary: "Talked about leaving Shanghai next year.", textContent: "We walked along the river and talked about whether staying was still honest.", createdAt: now.addingTimeInterval(-86_400 * 3), updatedAt: now.addingTimeInterval(-86_400 * 3), metadata: ["person": "Lina", "theme": "change"], entities: [EntityReference(id: person.id, kind: .person, name: "Lina"), EntityReference(id: theme.id, kind: .theme, name: "change")])
        let artifact2 = Artifact(kind: .photo, title: "River photo", summary: "Blurred lights on the Bund.", createdAt: now.addingTimeInterval(-86_400 * 3), updatedAt: now.addingTimeInterval(-86_400 * 3), metadata: ["location": "Bund"], entities: [EntityReference(id: place.id, kind: .place, name: "Bund")])
        let artifact3 = Artifact(kind: .music, title: "Anchor Song", summary: "The track I kept replaying after that talk.", createdAt: now.addingTimeInterval(-86_400 * 2), updatedAt: now.addingTimeInterval(-86_400 * 2), metadata: ["artist": "Phoebe Bridgers"])
        let record = RecordShell(createdAt: now.addingTimeInterval(-86_400 * 3), updatedAt: now.addingTimeInterval(-86_400 * 3), rawText: "I think I've been delaying a necessary goodbye. The walk with Lina made that obvious.", captureSource: .composer, artifactIDs: [artifact1.id, artifact2.id, artifact3.id], userMood: "reflective", userIntensity: 4)
        let analysis = RecordAnalysisSnapshot(recordID: record.id, tags: ["relationship", "transition", "goodbye"], emotionLabel: "reflective", insight: "The note suggests a repeated hesitation around leaving, with the relationship acting as an emotional anchor.", followUpQuestion: "What exactly are you trying not to lose if you leave?", entities: [EntityReference(id: person.id, kind: .person, name: "Lina"), EntityReference(id: theme.id, kind: .theme, name: "relationship"), EntityReference(id: UUID(), kind: .theme, name: "transition"), EntityReference(id: UUID(), kind: .theme, name: "goodbye")], createdAt: now)
        let reflection = ReflectionSnapshot(type: .relationship, title: "Anchor Relationship", body: "Lina appears as a stabilizing figure in moments where departure becomes real.", sourceRecordIDs: [record.id], sourceArtifactIDs: [artifact1.id, artifact2.id, artifact3.id], sourceEntityIDs: [person.id, theme.id], createdAt: now)
        let links = [
            ArtifactEntityLink(artifactID: artifact1.id, entityID: person.id, confidence: 0.95, source: "fixture", createdAt: now),
            ArtifactEntityLink(artifactID: artifact1.id, entityID: theme.id, confidence: 0.88, source: "fixture", createdAt: now),
            ArtifactEntityLink(artifactID: artifact2.id, entityID: place.id, confidence: 0.92, source: "fixture", createdAt: now)
        ]
        let edges = [
            EntityEdge(fromEntityID: person.id, toEntityID: theme.id, relationKind: .mentionedWith, weight: 0.9, firstSeenAt: now, lastSeenAt: now, evidenceCount: 1),
            EntityEdge(fromEntityID: place.id, toEntityID: person.id, relationKind: .relatedTo, weight: 0.6, firstSeenAt: now, lastSeenAt: now, evidenceCount: 1)
        ]
        let items = [
            CompositionItem(compositionID: composition.id, targetType: .artifact, targetID: artifact2.id, widthUnits: 4, heightUnits: 3, zIndex: 0, rotation: -2, scale: 1, positionHint: .init(x: 0.16, y: 0.18)),
            CompositionItem(compositionID: composition.id, targetType: .artifact, targetID: artifact1.id, widthUnits: 5, heightUnits: 2, zIndex: 1, rotation: 1.5, scale: 1, positionHint: .init(x: 0.48, y: 0.24)),
            CompositionItem(compositionID: composition.id, targetType: .reflection, targetID: reflection.id, widthUnits: 4, heightUnits: 2, zIndex: 2, rotation: 0, scale: 1, positionHint: .init(x: 0.34, y: 0.56)),
            CompositionItem(compositionID: composition.id, targetType: .artifact, targetID: artifact3.id, widthUnits: 3, heightUnits: 2, zIndex: 3, rotation: -1, scale: 1, positionHint: .init(x: 0.70, y: 0.62))
        ]
        return DemoScenario(name: "Relationship Arc", boards: [board], compositions: [composition], items: items, records: [record], artifacts: [artifact1, artifact2, artifact3], reflections: [reflection], temporalArcs: [], analyses: [analysis], entityNodes: [person, place, theme], entityEdges: edges, artifactEntityLinks: links)
    }

    static func relocationPhase() -> DemoScenario {
        let now = Date().addingTimeInterval(-86_400 * 9)
        let board = Board(kind: .arc, title: "Relocation Phase", subtitle: "Moving cities and identity drift", createdAt: now)
        let composition = Composition(boardID: board.id, title: "Relocation Board", sortOrder: 0, createdAt: now, updatedAt: now)
        let place = EntityNode(kind: .place, displayName: "Jing'an", summary: "New neighborhood in relocation phase.", createdAt: now, updatedAt: now)
        let theme = EntityNode(kind: .theme, displayName: "arrival", summary: "The move is emotionally incomplete.", createdAt: now, updatedAt: now)
        let artifact1 = Artifact(kind: .text, title: "Apartment keys", summary: "The first night alone in the new apartment felt more empty than free.", textContent: "I thought arrival would feel clean. It mostly felt suspended.", createdAt: now, updatedAt: now, metadata: ["theme": "arrival", "place": "Shanghai"], entities: [EntityReference(id: theme.id, kind: .theme, name: "arrival")])
        let artifact2 = Artifact(kind: .location, title: "New neighborhood", summary: "Walked around the blocks to make the place feel mine.", createdAt: now.addingTimeInterval(86_400), updatedAt: now.addingTimeInterval(86_400), metadata: ["place": "Jing'an"], entities: [EntityReference(id: place.id, kind: .place, name: "Jing'an")])
        let artifact3 = Artifact(kind: .weather, title: "Humid dusk", summary: "The weather made the city feel heavier than I expected.", createdAt: now.addingTimeInterval(86_400), updatedAt: now.addingTimeInterval(86_400), metadata: ["condition": "humid"])
        let record = RecordShell(createdAt: now, updatedAt: now, rawText: "I keep calling this a move, but it still feels like a temporary pause.", captureSource: .manual, artifactIDs: [artifact1.id, artifact2.id, artifact3.id], userMood: "unsettled", userIntensity: 3)
        let analysis = RecordAnalysisSnapshot(recordID: record.id, tags: ["move", "arrival", "identity"], emotionLabel: "unsettled", insight: "The move is being processed less as a fresh start and more as a suspended transition.", followUpQuestion: "What would make this place feel chosen instead of provisional?", entities: [EntityReference(id: place.id, kind: .place, name: "Jing'an"), EntityReference(id: theme.id, kind: .theme, name: "arrival"), EntityReference(id: UUID(), kind: .theme, name: "identity")], createdAt: now.addingTimeInterval(3_600))
        let reflection = ReflectionSnapshot(type: .phase, title: "Suspended Arrival", body: "Several artifacts frame the relocation as emotionally unfinished rather than completed.", sourceRecordIDs: [record.id], sourceArtifactIDs: [artifact1.id, artifact2.id, artifact3.id], sourceEntityIDs: [place.id, theme.id], createdAt: now.addingTimeInterval(7_200))
        let links = [
            ArtifactEntityLink(artifactID: artifact1.id, entityID: theme.id, confidence: 0.9, source: "fixture", createdAt: now),
            ArtifactEntityLink(artifactID: artifact2.id, entityID: place.id, confidence: 0.95, source: "fixture", createdAt: now)
        ]
        let edges = [
            EntityEdge(fromEntityID: place.id, toEntityID: theme.id, relationKind: .repeatedIn, weight: 0.7, firstSeenAt: now, lastSeenAt: now, evidenceCount: 1)
        ]
        let items = [
            CompositionItem(compositionID: composition.id, targetType: .artifact, targetID: artifact1.id, widthUnits: 5, heightUnits: 2, zIndex: 1, rotation: -1.5, scale: 1, positionHint: .init(x: 0.30, y: 0.22)),
            CompositionItem(compositionID: composition.id, targetType: .artifact, targetID: artifact2.id, widthUnits: 3, heightUnits: 3, zIndex: 0, rotation: 2.0, scale: 1, positionHint: .init(x: 0.70, y: 0.26)),
            CompositionItem(compositionID: composition.id, targetType: .artifact, targetID: artifact3.id, widthUnits: 3, heightUnits: 2, zIndex: 2, rotation: 0, scale: 1, positionHint: .init(x: 0.58, y: 0.60)),
            CompositionItem(compositionID: composition.id, targetType: .reflection, targetID: reflection.id, widthUnits: 4, heightUnits: 2, zIndex: 3, rotation: -0.5, scale: 1, positionHint: .init(x: 0.28, y: 0.64))
        ]
        return DemoScenario(name: "Relocation Phase", boards: [board], compositions: [composition], items: items, records: [record], artifacts: [artifact1, artifact2, artifact3], reflections: [reflection], temporalArcs: [], analyses: [analysis], entityNodes: [place, theme], entityEdges: edges, artifactEntityLinks: links)
    }

    static func workDecisionPhase() -> DemoScenario {
        let now = Date().addingTimeInterval(-86_400 * 16)
        let board = Board(kind: .review, title: "Work Decision", subtitle: "Career fork and delayed conviction", createdAt: now)
        let composition = Composition(boardID: board.id, title: "Decision Review", sortOrder: 0, createdAt: now, updatedAt: now)
        let decision = EntityNode(kind: .decision, displayName: "job_offer", summary: "Choice between safe role and smaller studio.", createdAt: now, updatedAt: now)
        let person = EntityNode(kind: .person, displayName: "Marcus", summary: "Conversation partner challenging defensive framing.", createdAt: now, updatedAt: now)
        let theme = EntityNode(kind: .theme, displayName: "risk", summary: "Recurring tension between caution and aliveness.", createdAt: now, updatedAt: now)
        let artifact1 = Artifact(kind: .decisionNote, title: "Offer comparison", summary: "The safer role looks sensible, but the smaller team feels alive.", textContent: "I only sound certain when I explain the safe option to other people.", createdAt: now, updatedAt: now, metadata: ["decision": "job_offer"], entities: [EntityReference(id: decision.id, kind: .decision, name: "job_offer"), EntityReference(id: theme.id, kind: .theme, name: "risk")])
        let artifact2 = Artifact(kind: .personMention, title: "Talk with Marcus", summary: "Marcus asked whether stability is actually what I want, or just what sounds defensible.", createdAt: now.addingTimeInterval(86_400), updatedAt: now.addingTimeInterval(86_400), metadata: ["person": "Marcus"], entities: [EntityReference(id: person.id, kind: .person, name: "Marcus")])
        let artifact3 = Artifact(kind: .link, title: "Studio website", summary: "I kept rereading the tiny team manifesto.", createdAt: now.addingTimeInterval(86_400 * 2), updatedAt: now.addingTimeInterval(86_400 * 2), metadata: ["type": "company"])
        let record = RecordShell(createdAt: now.addingTimeInterval(86_400 * 2), updatedAt: now.addingTimeInterval(86_400 * 2), rawText: "I think I'm using caution as a public story and curiosity as the private one.", captureSource: .composer, artifactIDs: [artifact1.id, artifact2.id, artifact3.id], userMood: "tense", userIntensity: 4)
        let analysis = RecordAnalysisSnapshot(recordID: record.id, tags: ["career", "decision", "risk"], emotionLabel: "tense", insight: "The record distinguishes between a socially defensible choice and a privately energizing one.", followUpQuestion: "Which option would still feel honest if nobody else had to approve it?", entities: [EntityReference(id: decision.id, kind: .decision, name: "job_offer"), EntityReference(id: person.id, kind: .person, name: "Marcus"), EntityReference(id: theme.id, kind: .theme, name: "risk")], createdAt: now.addingTimeInterval(86_400 * 2 + 3_600))
        let reflection = ReflectionSnapshot(type: .pattern, title: "Defensible vs. Alive", body: "This decision is framed as a conflict between external legitimacy and internal aliveness.", sourceRecordIDs: [record.id], sourceArtifactIDs: [artifact1.id, artifact2.id, artifact3.id], sourceEntityIDs: [decision.id, person.id, theme.id], createdAt: now.addingTimeInterval(86_400 * 2 + 7_200))
        let links = [
            ArtifactEntityLink(artifactID: artifact1.id, entityID: decision.id, confidence: 0.96, source: "fixture", createdAt: now),
            ArtifactEntityLink(artifactID: artifact1.id, entityID: theme.id, confidence: 0.88, source: "fixture", createdAt: now),
            ArtifactEntityLink(artifactID: artifact2.id, entityID: person.id, confidence: 0.95, source: "fixture", createdAt: now)
        ]
        let edges = [
            EntityEdge(fromEntityID: person.id, toEntityID: decision.id, relationKind: .decidedAt, weight: 0.82, firstSeenAt: now, lastSeenAt: now, evidenceCount: 1),
            EntityEdge(fromEntityID: decision.id, toEntityID: theme.id, relationKind: .relatedTo, weight: 0.76, firstSeenAt: now, lastSeenAt: now, evidenceCount: 1)
        ]
        let items = [
            CompositionItem(compositionID: composition.id, targetType: .artifact, targetID: artifact1.id, widthUnits: 5, heightUnits: 3, zIndex: 0, rotation: -2.0, scale: 1, positionHint: .init(x: 0.22, y: 0.26)),
            CompositionItem(compositionID: composition.id, targetType: .artifact, targetID: artifact2.id, widthUnits: 4, heightUnits: 2, zIndex: 1, rotation: 1.2, scale: 1, positionHint: .init(x: 0.66, y: 0.22)),
            CompositionItem(compositionID: composition.id, targetType: .artifact, targetID: artifact3.id, widthUnits: 3, heightUnits: 2, zIndex: 2, rotation: 0, scale: 1, positionHint: .init(x: 0.70, y: 0.54)),
            CompositionItem(compositionID: composition.id, targetType: .reflection, targetID: reflection.id, widthUnits: 5, heightUnits: 2, zIndex: 3, rotation: -1.0, scale: 1, positionHint: .init(x: 0.36, y: 0.66))
        ]
        return DemoScenario(name: "Work Decision", boards: [board], compositions: [composition], items: items, records: [record], artifacts: [artifact1, artifact2, artifact3], reflections: [reflection], temporalArcs: [], analyses: [analysis], entityNodes: [decision, person, theme], entityEdges: edges, artifactEntityLinks: links)
    }
}
