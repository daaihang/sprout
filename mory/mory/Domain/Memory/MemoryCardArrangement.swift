import Foundation

enum MemoryCardContentRef: Codable, Hashable, Sendable {
    case recordBody
    case artifact(UUID)
    case artifactGroup([UUID], kind: MemoryCardGroupKind)
    case affect(UUID)
    case journalingSuggestion(UUID)
}

enum MemoryCardGroupKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case mediaStack
    case photoStack
    case mixedContext
    case journalingBundle

    var id: String { rawValue }
}

enum MemoryCardVisualRecipe: String, Codable, CaseIterable, Identifiable, Sendable {
    case notebook
    case polaroid
    case filmFrame
    case livePhotoPrint
    case cassette
    case vinyl
    case mapTicket
    case weatherStamp
    case linkNote
    case taskNote
    case personCard
    case affectCard
    case bundlePacket
    case statusNote

    var id: String { rawValue }
}

enum MemoryCardSizeToken: String, Codable, CaseIterable, Identifiable, Sendable {
    case stamp
    case strip
    case card
    case square
    case tape
    case banner

    var id: String { rawValue }
}

struct MemoryCardLayoutToken: Codable, Hashable, Sendable {
    var order: Int
    var size: MemoryCardSizeToken
    var gridPlacement: MemoryCardGridPlacement?
    var groupID: UUID?
    var rotationDegrees: Double
    var xNudge: Double
    var yNudge: Double
    var zIndex: Int

    init(
        order: Int,
        size: MemoryCardSizeToken = .card,
        gridPlacement: MemoryCardGridPlacement? = nil,
        groupID: UUID? = nil,
        rotationDegrees: Double = 0,
        xNudge: Double = 0,
        yNudge: Double = 0,
        zIndex: Int = 0
    ) {
        self.order = order
        self.size = size
        self.gridPlacement = gridPlacement
        self.groupID = groupID
        self.rotationDegrees = rotationDegrees
        self.xNudge = xNudge
        self.yNudge = yNudge
        self.zIndex = zIndex
    }
}

struct MemoryCardNode: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var contentRef: MemoryCardContentRef
    var visualRecipe: MemoryCardVisualRecipe
    var layout: MemoryCardLayoutToken

    init(
        id: UUID = UUID(),
        contentRef: MemoryCardContentRef,
        visualRecipe: MemoryCardVisualRecipe,
        layout: MemoryCardLayoutToken
    ) {
        self.id = id
        self.contentRef = contentRef
        self.visualRecipe = visualRecipe
        self.layout = layout
    }
}

struct MemoryCardArrangement: Identifiable, Codable, Hashable, Sendable {
    static let schemaVersion = 2

    var id: UUID
    var recordID: UUID
    var schemaVersion: Int
    var nodes: [MemoryCardNode]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        schemaVersion: Int = MemoryCardArrangement.schemaVersion,
        nodes: [MemoryCardNode],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.schemaVersion = schemaVersion
        self.nodes = nodes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum MemoryCardDraftContentRef: Codable, Hashable, Sendable {
    case recordBody
    case artifactDraft(UUID)
    case artifactDraftGroup([UUID], kind: MemoryCardGroupKind)
    case affectDraft(UUID)
    case journalingSuggestion(UUID)
}

struct MemoryCardDraftNode: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var contentRef: MemoryCardDraftContentRef
    var visualRecipe: MemoryCardVisualRecipe
    var layout: MemoryCardLayoutToken

    init(
        id: UUID = UUID(),
        contentRef: MemoryCardDraftContentRef,
        visualRecipe: MemoryCardVisualRecipe,
        layout: MemoryCardLayoutToken
    ) {
        self.id = id
        self.contentRef = contentRef
        self.visualRecipe = visualRecipe
        self.layout = layout
    }
}

struct MemoryCardArrangementDraft: Codable, Hashable, Sendable {
    var nodes: [MemoryCardDraftNode]

    init(nodes: [MemoryCardDraftNode] = []) {
        self.nodes = nodes
    }

    static func artifactCards(for artifactDrafts: [CaptureArtifactDraft]) -> MemoryCardArrangementDraft? {
        guard !artifactDrafts.isEmpty else { return nil }
        var arrangement = MemoryCardArrangementDraft()
        for draft in artifactDrafts {
            arrangement.appendArtifactDraft(draft)
        }
        return arrangement
    }

    mutating func ensureRecordBodyNode() {
        guard !nodes.contains(where: { $0.contentRef == .recordBody }) else { return }
        nodes.insert(
            MemoryCardDraftNode(
                contentRef: .recordBody,
                visualRecipe: .notebook,
                layout: MemoryCardLayoutToken(order: 0, size: .banner, rotationDegrees: -1.5, zIndex: 0)
            ),
            at: 0
        )
        normalizeOrder()
    }

    mutating func appendArtifactDraft(_ draft: CaptureArtifactDraft) {
        guard !containsArtifactDraft(draft.draftID) else { return }
        let order = nodes.count
        nodes.append(
            MemoryCardDraftNode(
                contentRef: .artifactDraft(draft.draftID),
                visualRecipe: Self.defaultVisualRecipe(for: draft.content),
                layout: MemoryCardLayoutToken(
                    order: order,
                    size: Self.defaultSize(for: draft.content),
                    rotationDegrees: Self.defaultRotation(for: draft.draftID),
                    zIndex: order
                )
            )
        )
    }

    mutating func removeArtifactDraft(_ draftID: UUID) {
        removeArtifactDraft(draftID, artifactDrafts: [])
    }

    mutating func removeArtifactDraft(_ draftID: UUID, artifactDrafts: [CaptureArtifactDraft]) {
        let draftByID = Dictionary(uniqueKeysWithValues: artifactDrafts.map { ($0.draftID, $0) })
        nodes = nodes.compactMap { node in
            var node = node
            switch node.contentRef {
            case let .artifactDraft(id):
                return id == draftID ? nil : node
            case let .artifactDraftGroup(ids, _):
                let keptIDs = ids.filter { $0 != draftID }
                guard !keptIDs.isEmpty else { return nil }
                if keptIDs.count == 1 {
                    node.contentRef = .artifactDraft(keptIDs[0])
                    if let keptDraft = draftByID[keptIDs[0]] {
                        node.visualRecipe = Self.defaultVisualRecipe(for: keptDraft.content)
                        node.layout.size = Self.defaultSize(for: keptDraft.content)
                    } else {
                        node.visualRecipe = .statusNote
                        node.layout.size = MemoryCardRecipeLayoutPolicy.defaultSize(for: .statusNote)
                    }
                } else {
                    node.contentRef = .artifactDraftGroup(keptIDs, kind: .mediaStack)
                }
                return node
            case .recordBody, .affectDraft, .journalingSuggestion:
                return node
            }
        }
        normalizeOrder()
    }

    mutating func reorderArtifactDraft(from sourceDraftID: UUID, to targetDraftID: UUID) {
        guard let sourceIndex = nodeIndex(containingArtifactDraft: sourceDraftID),
              let targetIndex = nodeIndex(containingArtifactDraft: targetDraftID),
              sourceIndex != targetIndex else {
            return
        }
        let moved = nodes.remove(at: sourceIndex)
        let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        nodes.insert(moved, at: min(max(adjustedTarget, 0), nodes.endIndex))
        normalizeOrder()
    }

    mutating func setSize(_ size: MemoryCardSizeToken, forDraftID draftID: UUID) {
        guard let index = nodeIndex(containingArtifactDraft: draftID) else { return }
        nodes[index].layout.size = MemoryCardRecipeLayoutPolicy.normalizedSize(size, for: nodes[index].visualRecipe)
        normalizeOrder()
    }

    mutating func toggleStackWithPrevious(draftID: UUID) {
        guard let index = nodeIndex(containingArtifactDraft: draftID), index > 0 else { return }
        let previousIndex = index - 1
        let currentIDs = artifactDraftIDs(in: nodes[index])
        let previousIDs = artifactDraftIDs(in: nodes[previousIndex])
        guard !currentIDs.isEmpty, !previousIDs.isEmpty else { return }
        let mergedIDs = OrderedCollections.unique(previousIDs + currentIDs)
        nodes[previousIndex].contentRef = .artifactDraftGroup(mergedIDs, kind: .mediaStack)
        nodes[previousIndex].visualRecipe = .bundlePacket
        nodes[previousIndex].layout.size = MemoryCardRecipeLayoutPolicy.defaultSize(for: .bundlePacket)
        nodes.remove(at: index)
        normalizeOrder()
    }

    mutating func unstackNode(_ nodeID: UUID) {
        unstackNode(nodeID, artifactDrafts: [])
    }

    mutating func unstackNode(_ nodeID: UUID, artifactDrafts: [CaptureArtifactDraft]) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }),
              case let .artifactDraftGroup(ids, _) = nodes[index].contentRef else {
            return
        }
        let baseOrder = nodes[index].layout.order
        let draftByID = Dictionary(uniqueKeysWithValues: artifactDrafts.map { ($0.draftID, $0) })
        let expanded: [MemoryCardDraftNode] = ids.enumerated().map { offset, draftID in
            let draft = draftByID[draftID]
            return MemoryCardDraftNode(
                contentRef: .artifactDraft(draftID),
                visualRecipe: draft.map { Self.defaultVisualRecipe(for: $0.content) } ?? .statusNote,
                layout: MemoryCardLayoutToken(
                    order: baseOrder + offset,
                    size: draft.map { Self.defaultSize(for: $0.content) } ?? MemoryCardRecipeLayoutPolicy.defaultSize(for: .statusNote),
                    rotationDegrees: Self.defaultRotation(for: draftID),
                    zIndex: baseOrder + offset
                )
            )
        }
        nodes.remove(at: index)
        nodes.insert(contentsOf: expanded, at: index)
        normalizeOrder()
    }

    mutating func unstackContainingDraft(_ draftID: UUID) {
        unstackContainingDraft(draftID, artifactDrafts: [])
    }

    mutating func unstackContainingDraft(_ draftID: UUID, artifactDrafts: [CaptureArtifactDraft]) {
        guard let index = nodeIndex(containingArtifactDraft: draftID) else { return }
        unstackNode(nodes[index].id, artifactDrafts: artifactDrafts)
    }

    mutating func sync(recordBodyIsPresent: Bool, artifactDrafts: [CaptureArtifactDraft]) {
        let validIDs = Set(artifactDrafts.map(\.draftID))
        nodes = nodes.compactMap { node in
            var node = node
            switch node.contentRef {
            case .recordBody:
                return recordBodyIsPresent ? node : nil
            case let .artifactDraft(id):
                return validIDs.contains(id) ? node : nil
            case let .artifactDraftGroup(ids, kind):
                let keptIDs = ids.filter { validIDs.contains($0) }
                guard !keptIDs.isEmpty else { return nil }
                node.contentRef = keptIDs.count == 1 ? .artifactDraft(keptIDs[0]) : .artifactDraftGroup(keptIDs, kind: kind)
                if keptIDs.count == 1 {
                    if let draft = artifactDrafts.first(where: { $0.draftID == keptIDs[0] }) {
                        node.visualRecipe = Self.defaultVisualRecipe(for: draft.content)
                        node.layout.size = Self.defaultSize(for: draft.content)
                    } else {
                        node.visualRecipe = .statusNote
                        node.layout.size = MemoryCardRecipeLayoutPolicy.defaultSize(for: .statusNote)
                    }
                    node.layout.groupID = nil
                }
                return node
            case .affectDraft, .journalingSuggestion:
                return node
            }
        }

        if recordBodyIsPresent {
            ensureRecordBodyNode()
        }

        for draft in artifactDrafts {
            if !containsArtifactDraft(draft.draftID) {
                appendArtifactDraft(draft)
            }
        }
        normalizeOrder()
    }

    mutating func mergeArrangement(_ other: MemoryCardArrangementDraft) {
        for node in other.nodes.sorted(by: { $0.layout.order < $1.layout.order }) {
            let shouldAppend: Bool
            switch node.contentRef {
            case .recordBody:
                shouldAppend = !nodes.contains(where: { $0.contentRef == .recordBody })
            case let .artifactDraft(id):
                shouldAppend = !containsArtifactDraft(id)
            case let .artifactDraftGroup(ids, _):
                shouldAppend = ids.allSatisfy { !containsArtifactDraft($0) }
            case .affectDraft, .journalingSuggestion:
                shouldAppend = !nodes.contains(where: { $0.id == node.id })
            }
            if shouldAppend {
                nodes.append(node)
            }
        }
        normalizeOrder()
    }

    func resolve(
        record: RecordShell,
        artifacts: [Artifact],
        artifactIDByDraftID: [UUID: UUID],
        createdAt: Date
    ) -> MemoryCardArrangement {
        let artifactByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        var resolvedNodes: [MemoryCardNode] = []
        var usedArtifactIDs = Set<UUID>()
        var sourceNodes = nodes

        if record.rawText.trimmedOrNil != nil && !sourceNodes.contains(where: { $0.contentRef == .recordBody }) {
            sourceNodes.insert(
                MemoryCardDraftNode(
                    contentRef: .recordBody,
                    visualRecipe: .notebook,
                    layout: MemoryCardLayoutToken(order: 0, size: .banner, rotationDegrees: -1.5, zIndex: 0)
                ),
                at: 0
            )
        }

        for node in sourceNodes.sorted(by: { $0.layout.order < $1.layout.order }) {
            switch node.contentRef {
            case .recordBody:
                guard record.rawText.trimmedOrNil != nil else { continue }
                resolvedNodes.append(
                    MemoryCardNode(
                        id: node.id,
                        contentRef: .recordBody,
                        visualRecipe: node.visualRecipe,
                        layout: node.layout
                    )
                )
            case let .artifactDraft(draftID):
                guard let artifactID = artifactIDByDraftID[draftID],
                      let artifact = artifactByID[artifactID],
                      artifact.kind != .text else {
                    continue
                }
                usedArtifactIDs.insert(artifactID)
                resolvedNodes.append(
                    MemoryCardNode(
                        id: node.id,
                        contentRef: .artifact(artifactID),
                        visualRecipe: node.visualRecipe,
                        layout: node.layout
                    )
                )
            case let .artifactDraftGroup(draftIDs, kind):
                let artifactIDs = draftIDs.compactMap { artifactIDByDraftID[$0] }
                    .filter { artifactByID[$0]?.kind != .text }
                guard !artifactIDs.isEmpty else { continue }
                usedArtifactIDs.formUnion(artifactIDs)
                resolvedNodes.append(
                    MemoryCardNode(
                        id: node.id,
                        contentRef: .artifactGroup(artifactIDs, kind: kind),
                        visualRecipe: node.visualRecipe,
                        layout: node.layout
                    )
                )
            case let .affectDraft(id):
                resolvedNodes.append(
                    MemoryCardNode(
                        id: node.id,
                        contentRef: .affect(id),
                        visualRecipe: node.visualRecipe,
                        layout: node.layout
                    )
                )
            case let .journalingSuggestion(importSessionID):
                resolvedNodes.append(
                    MemoryCardNode(
                        id: node.id,
                        contentRef: .journalingSuggestion(importSessionID),
                        visualRecipe: node.visualRecipe,
                        layout: node.layout
                    )
                )
            }
        }

        let existingOrderCount = resolvedNodes.count
        let missingArtifacts = MemoryCardArrangement.ordered(artifacts, by: record.artifactIDs)
            .filter { $0.kind != .text && !usedArtifactIDs.contains($0.id) }
        resolvedNodes.append(contentsOf: missingArtifacts.enumerated().map { offset, artifact in
            let order = existingOrderCount + offset
            return MemoryCardNode(
                contentRef: .artifact(artifact.id),
                visualRecipe: MemoryCardArrangement.defaultVisualRecipe(for: artifact),
                layout: MemoryCardLayoutToken(
                    order: order,
                    size: MemoryCardArrangement.defaultSize(for: artifact),
                    rotationDegrees: MemoryCardArrangement.defaultRotation(for: artifact.id),
                    zIndex: order
                )
            )
        })

        return MemoryCardArrangement(
            recordID: record.id,
            nodes: resolvedNodes.normalizedLayoutOrder(),
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    func resolveArtifactNodes(
        artifacts: [Artifact],
        artifactIDByDraftID: [UUID: UUID]
    ) -> [MemoryCardNode] {
        let artifactByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        return nodes
            .sorted { $0.layout.order < $1.layout.order }
            .compactMap { node -> MemoryCardNode? in
                switch node.contentRef {
                case let .artifactDraft(draftID):
                    guard let artifactID = artifactIDByDraftID[draftID],
                          artifactByID[artifactID]?.kind != .text else {
                        return nil
                    }
                    return MemoryCardNode(
                        id: node.id,
                        contentRef: .artifact(artifactID),
                        visualRecipe: node.visualRecipe,
                        layout: node.layout
                    )
                case let .artifactDraftGroup(draftIDs, kind):
                    let artifactIDs = draftIDs.compactMap { artifactIDByDraftID[$0] }
                        .filter { artifactByID[$0]?.kind != .text }
                    guard !artifactIDs.isEmpty else { return nil }
                    return MemoryCardNode(
                        id: node.id,
                        contentRef: .artifactGroup(artifactIDs, kind: kind),
                        visualRecipe: node.visualRecipe,
                        layout: node.layout
                    )
                case .recordBody, .affectDraft, .journalingSuggestion:
                    return nil
                }
            }
    }

    private func containsArtifactDraft(_ draftID: UUID) -> Bool {
        nodes.contains { node in artifactDraftIDs(in: node).contains(draftID) }
    }

    private func nodeIndex(containingArtifactDraft draftID: UUID) -> Int? {
        nodes.firstIndex { node in artifactDraftIDs(in: node).contains(draftID) }
    }

    private func artifactDraftIDs(in node: MemoryCardDraftNode) -> [UUID] {
        switch node.contentRef {
        case let .artifactDraft(id):
            return [id]
        case let .artifactDraftGroup(ids, _):
            return ids
        case .recordBody, .affectDraft, .journalingSuggestion:
            return []
        }
    }

    private mutating func normalizeOrder() {
        nodes = nodes.normalizedLayoutOrder()
    }

    private static func defaultVisualRecipe(for content: CaptureArtifactContent) -> MemoryCardVisualRecipe {
        switch content {
        case .text:
            return .notebook
        case .photo:
            return .polaroid
        case .video:
            return .filmFrame
        case .livePhoto:
            return .livePhotoPrint
        case .audio:
            return .cassette
        case .music:
            return .vinyl
        case .link:
            return .linkNote
        case .location:
            return .mapTicket
        case .weather:
            return .weatherStamp
        case .todo:
            return .taskNote
        case .promptAnswer:
            return .notebook
        case .personContext:
            return .personCard
        }
    }

    private static func defaultSize(for content: CaptureArtifactContent) -> MemoryCardSizeToken {
        switch content {
        case .photo, .livePhoto:
            return .square
        case .video:
            return .tape
        case .audio, .music:
            return .tape
        case .weather:
            return .stamp
        case .todo:
            return .strip
        case .text, .location, .link, .promptAnswer, .personContext:
            return .card
        }
    }

    private static func defaultRotation(for id: UUID) -> Double {
        let value = abs(id.uuidString.hashValue % 7)
        return Double(value - 3)
    }
}

extension MemoryCardArrangement {
    static func defaultArrangement(
        record: RecordShell,
        artifacts: [Artifact],
        createdAt: Date
    ) -> MemoryCardArrangement {
        var nodes: [MemoryCardNode] = []
        var order = 0

        if record.rawText.trimmedOrNil != nil {
            nodes.append(
                MemoryCardNode(
                    contentRef: .recordBody,
                    visualRecipe: .notebook,
                    layout: MemoryCardLayoutToken(order: order, size: .banner, rotationDegrees: -1.5, zIndex: order)
                )
            )
            order += 1
        }

        let orderedArtifacts = ordered(artifacts, by: record.artifactIDs)
            .filter { $0.kind != .text }

        for artifact in orderedArtifacts {
            nodes.append(
                MemoryCardNode(
                    contentRef: .artifact(artifact.id),
                    visualRecipe: defaultVisualRecipe(for: artifact),
                    layout: MemoryCardLayoutToken(
                        order: order,
                        size: defaultSize(for: artifact),
                        rotationDegrees: defaultRotation(for: artifact.id),
                        zIndex: order
                    )
                )
            )
            order += 1
        }

        return MemoryCardArrangement(
            recordID: record.id,
            nodes: nodes.normalizedLayoutOrder(),
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    static func ordered(_ artifacts: [Artifact], by artifactIDs: [UUID]) -> [Artifact] {
        var artifactsByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        var result: [Artifact] = []
        for id in artifactIDs {
            if let artifact = artifactsByID.removeValue(forKey: id) {
                result.append(artifact)
            }
        }
        result.append(contentsOf: artifactsByID.values.sorted { $0.updatedAt > $1.updatedAt })
        return result
    }

    static func defaultVisualRecipe(for artifact: Artifact) -> MemoryCardVisualRecipe {
        switch artifact.kind {
        case .text:
            return .notebook
        case .photo:
            return .polaroid
        case .video:
            return .filmFrame
        case .livePhoto:
            return .livePhotoPrint
        case .audio:
            return .cassette
        case .music:
            return .vinyl
        case .link:
            return .linkNote
        case .location:
            return .mapTicket
        case .weather:
            return .weatherStamp
        case .todo:
            return .taskNote
        case .document:
            if artifact.metadata["documentType"] == "personContext" {
                return .personCard
            }
            return .notebook
        }
    }

    static func defaultSize(for artifact: Artifact) -> MemoryCardSizeToken {
        switch artifact.kind {
        case .photo, .livePhoto:
            return .square
        case .video:
            return .tape
        case .music, .audio:
            return .tape
        case .weather:
            return .stamp
        case .todo:
            return .strip
        case .text, .location, .link, .document:
            return .card
        }
    }

    static func defaultRotation(for id: UUID) -> Double {
        let value = abs(id.uuidString.hashValue % 7)
        return Double(value - 3)
    }

    func synchronized(
        record: RecordShell,
        artifacts: [Artifact],
        artifactOrder: [UUID]? = nil,
        updatedAt: Date
    ) -> MemoryCardArrangement {
        let artifactByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        let availableArtifactIDs = Set(artifacts.map(\.id))
        var usedArtifactIDs = Set<UUID>()

        var syncedNodes = nodes.compactMap { node -> MemoryCardNode? in
            var node = node
            switch node.contentRef {
            case .recordBody:
                return record.rawText.trimmedOrNil == nil ? nil : node
            case let .artifact(id):
                guard availableArtifactIDs.contains(id), artifactByID[id]?.kind != .text else { return nil }
                usedArtifactIDs.insert(id)
                return node
            case let .artifactGroup(ids, kind):
                let keptIDs = ids.filter { id in
                    availableArtifactIDs.contains(id) && artifactByID[id]?.kind != .text
                }
                guard !keptIDs.isEmpty else { return nil }
                usedArtifactIDs.formUnion(keptIDs)
                node.contentRef = keptIDs.count == 1 ? .artifact(keptIDs[0]) : .artifactGroup(keptIDs, kind: kind)
                if keptIDs.count == 1 {
                    node.visualRecipe = artifactByID[keptIDs[0]].map(Self.defaultVisualRecipe(for:)) ?? node.visualRecipe
                    node.layout.size = artifactByID[keptIDs[0]].map(Self.defaultSize(for:)) ?? node.layout.size
                    node.layout.groupID = nil
                }
                return node
            case .affect, .journalingSuggestion:
                return node
            }
        }

        if record.rawText.trimmedOrNil != nil,
           !syncedNodes.contains(where: { $0.contentRef == .recordBody }) {
            syncedNodes.insert(
                MemoryCardNode(
                    contentRef: .recordBody,
                    visualRecipe: .notebook,
                    layout: MemoryCardLayoutToken(order: 0, size: .banner, rotationDegrees: -1.5, zIndex: 0)
                ),
                at: 0
            )
        }

        let orderedArtifacts = Self.ordered(artifacts, by: record.artifactIDs)
            .filter { $0.kind != .text && !usedArtifactIDs.contains($0.id) }
        let baseOrder = syncedNodes.count
        syncedNodes.append(contentsOf: orderedArtifacts.enumerated().map { offset, artifact in
            MemoryCardNode(
                contentRef: .artifact(artifact.id),
                visualRecipe: Self.defaultVisualRecipe(for: artifact),
                layout: MemoryCardLayoutToken(
                    order: baseOrder + offset,
                    size: Self.defaultSize(for: artifact),
                    rotationDegrees: Self.defaultRotation(for: artifact.id),
                    zIndex: baseOrder + offset
                )
            )
        })

        if let artifactOrder {
            syncedNodes = Self.reordered(nodes: syncedNodes, artifactOrder: artifactOrder)
        }

        return MemoryCardArrangement(
            id: id,
            recordID: record.id,
            schemaVersion: schemaVersion,
            nodes: syncedNodes.normalizedLayoutOrder(),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func settingSize(_ size: MemoryCardSizeToken, forArtifactID artifactID: UUID, updatedAt: Date) -> MemoryCardArrangement {
        var nodes = nodes
        guard let index = nodes.firstIndex(where: { $0.containsArtifactID(artifactID) }) else { return self }
        nodes[index].layout.size = MemoryCardRecipeLayoutPolicy.normalizedSize(size, for: nodes[index].visualRecipe)
        return replacing(nodes: nodes, updatedAt: updatedAt)
    }

    func stackingWithPrevious(artifactID: UUID, updatedAt: Date) -> MemoryCardArrangement {
        var nodes = nodes.normalizedLayoutOrder()
        guard let index = nodes.firstIndex(where: { $0.containsArtifactID(artifactID) }), index > 0 else { return self }
        let currentIDs = nodes[index].artifactIDs
        let previousIDs = nodes[index - 1].artifactIDs
        guard !currentIDs.isEmpty, !previousIDs.isEmpty else { return self }
        nodes[index - 1].contentRef = .artifactGroup(OrderedCollections.unique(previousIDs + currentIDs), kind: .mediaStack)
        nodes[index - 1].visualRecipe = .bundlePacket
        nodes[index - 1].layout.size = MemoryCardRecipeLayoutPolicy.defaultSize(for: .bundlePacket)
        nodes.remove(at: index)
        return replacing(nodes: nodes.normalizedLayoutOrder(), updatedAt: updatedAt)
    }

    func unstacking(nodeID: UUID, artifacts: [Artifact], updatedAt: Date) -> MemoryCardArrangement {
        var nodes = nodes.normalizedLayoutOrder()
        let artifactByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }),
              case let .artifactGroup(ids, _) = nodes[index].contentRef else {
            return self
        }
        let expanded = ids.enumerated().compactMap { offset, artifactID -> MemoryCardNode? in
            guard let artifact = artifactByID[artifactID] else { return nil }
            return MemoryCardNode(
                contentRef: .artifact(artifactID),
                visualRecipe: Self.defaultVisualRecipe(for: artifact),
                layout: MemoryCardLayoutToken(
                    order: nodes[index].layout.order + offset,
                    size: Self.defaultSize(for: artifact),
                    rotationDegrees: Self.defaultRotation(for: artifactID),
                    zIndex: nodes[index].layout.zIndex + offset
                )
            )
        }
        guard !expanded.isEmpty else { return self }
        nodes.remove(at: index)
        nodes.insert(contentsOf: expanded, at: index)
        return replacing(nodes: nodes.normalizedLayoutOrder(), updatedAt: updatedAt)
    }

    func unstackingContainingArtifactID(_ artifactID: UUID, artifacts: [Artifact], updatedAt: Date) -> MemoryCardArrangement {
        guard let node = nodes.first(where: { $0.containsArtifactID(artifactID) }) else { return self }
        return unstacking(nodeID: node.id, artifacts: artifacts, updatedAt: updatedAt)
    }

    func appendingArtifactNodes(_ nodesToAppend: [MemoryCardNode], updatedAt: Date) -> MemoryCardArrangement {
        guard !nodesToAppend.isEmpty else { return self }
        var knownArtifactIDs = Set(nodes.flatMap(\.artifactIDs))
        var appendedNodes: [MemoryCardNode] = []

        for node in nodesToAppend.sorted(by: { $0.layout.order < $1.layout.order }) {
            let artifactIDs = node.artifactIDs
            guard !artifactIDs.isEmpty,
                  artifactIDs.allSatisfy({ !knownArtifactIDs.contains($0) }) else {
                continue
            }
            appendedNodes.append(node)
            knownArtifactIDs.formUnion(artifactIDs)
        }

        guard !appendedNodes.isEmpty else { return self }
        return replacing(nodes: nodes + appendedNodes, updatedAt: updatedAt)
    }

    private func replacing(nodes: [MemoryCardNode], updatedAt: Date) -> MemoryCardArrangement {
        MemoryCardArrangement(
            id: id,
            recordID: recordID,
            schemaVersion: schemaVersion,
            nodes: nodes.normalizedLayoutOrder(),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func reordered(nodes: [MemoryCardNode], artifactOrder: [UUID]) -> [MemoryCardNode] {
        let orderIndex = Dictionary(uniqueKeysWithValues: artifactOrder.enumerated().map { ($0.element, $0.offset) })
        return nodes.sorted { lhsNode, rhsNode in
            let lhsIndex = lhsNode.artifactIDs.compactMap { orderIndex[$0] }.min()
            let rhsIndex = rhsNode.artifactIDs.compactMap { orderIndex[$0] }.min()
            switch (lhsIndex, rhsIndex) {
            case let (lhs?, rhs?):
                return lhs == rhs ? lhsNode.layout.order < rhsNode.layout.order : lhs < rhs
            case (_?, nil):
                return false
            case (nil, _?):
                return true
            case (nil, nil):
                return lhsNode.layout.order < rhsNode.layout.order
            }
        }
    }
}

private extension MemoryCardNode {
    var artifactIDs: [UUID] {
        switch contentRef {
        case let .artifact(id):
            return [id]
        case let .artifactGroup(ids, _):
            return ids
        case .recordBody, .affect, .journalingSuggestion:
            return []
        }
    }

    func containsArtifactID(_ artifactID: UUID) -> Bool {
        artifactIDs.contains(artifactID)
    }
}

private extension Array where Element == MemoryCardNode {
    func normalizedLayoutOrder() -> [MemoryCardNode] {
        var ordered = enumerated().map { index, element in
            var node = element
            node.layout.order = index
            node.layout.zIndex = index
            node.layout.size = MemoryCardRecipeLayoutPolicy.normalizedSize(node.layout.size, for: node.visualRecipe)
            return node
        }
        let placements = MemoryCardGridPacking.placements(for: ordered.map(\.layout.size))
        for index in ordered.indices {
            ordered[index].layout.gridPlacement = placements[safe: index]
        }
        return ordered
    }
}

private extension Array where Element == MemoryCardDraftNode {
    func normalizedLayoutOrder() -> [MemoryCardDraftNode] {
        var ordered = enumerated().map { index, element in
            var node = element
            node.layout.order = index
            node.layout.zIndex = index
            node.layout.size = MemoryCardRecipeLayoutPolicy.normalizedSize(node.layout.size, for: node.visualRecipe)
            return node
        }
        let placements = MemoryCardGridPacking.placements(for: ordered.map(\.layout.size))
        for index in ordered.indices {
            ordered[index].layout.gridPlacement = placements[safe: index]
        }
        return ordered
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
