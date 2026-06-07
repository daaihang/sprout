import SwiftUI

struct MemoryDeskRenderer: View {
    let snapshot: MemoryDetailSnapshot
    var onPreviewRecord: () -> Void = {}
    var onPreviewArtifacts: ([UUID]) -> Void = { _ in }
    var onOpenPlace: (UUID) -> Void = { _ in }
    var onOpenLink: (UUID) -> Void = { _ in }
    var onToggleMusic: (UUID) -> Void = { _ in }
    var onEditMemory: () -> Void = {}
    var onSetCardDensity: (UUID, MemoryCardContentDensity) -> Void = { _, _ in }
    var onMergeMediaWithPrevious: (UUID) -> Void = { _ in }
    var onUnmergeMedia: (UUID) -> Void = { _ in }
    var onDeleteArtifacts: ([UUID]) -> Void = { _ in }

    @State private var measuredContainerWidth: CGFloat = 0
    private let metrics = MemoryDeskBoardMetrics.default

    private var resolvedNodes: [ResolvedMemoryDeskNode] {
        MemoryDeskRenderPlan.nodes(for: snapshot).compactMap(resolveNode(_:)).sorted { lhs, rhs in
            if lhs.layout.order == rhs.layout.order {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.layout.order < rhs.layout.order
        }
    }

    private var containerWidth: CGFloat {
        measuredContainerWidth > 0 ? measuredContainerWidth : 390
    }

    private var layoutPlan: MemoryDeskBoardLayoutPlan<UUID> {
        let columnWidth = metrics.columnSpec(for: containerWidth).columnWidth
        return MemoryDeskBoardLayoutPlan.make(
            nodes: resolvedNodes.map {
                MemoryDeskBoardInputNode(
                    id: $0.id,
                    layout: $0.layout,
                    estimatedHeight: MemoryCardObjectMetrics.estimatedHeight(
                        for: $0.contentKind,
                        density: $0.contentDensity,
                        columnWidth: columnWidth,
                        mediaAspectRatio: $0.item.payload.mediaAspectRatio
                    )
                )
            },
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var resolvedSlots: [ResolvedMemoryDeskSlot] {
        let nodesByID = Dictionary(uniqueKeysWithValues: resolvedNodes.map { ($0.id, $0) })
        return layoutPlan.slots.compactMap { slot in
            guard let node = nodesByID[slot.id] else { return nil }
            return ResolvedMemoryDeskSlot(node: node, frame: slot.frame)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(resolvedSlots) { slot in
                deskCard(slot.node, availableSize: slot.frame.size)
                    .frame(width: slot.frame.width, height: slot.frame.height, alignment: .center)
                    .position(
                        x: slot.frame.midX + slot.node.layout.xNudge,
                        y: slot.frame.midY + slot.node.layout.yNudge
                    )
                    .rotationEffect(.degrees(slot.node.renderRotationDegrees))
                    .zIndex(slot.node.layout.renderZIndex)
            }
        }
        .frame(maxWidth: .infinity, minHeight: layoutPlan.boardHeight, maxHeight: layoutPlan.boardHeight, alignment: .topLeading)
        .background(deskBackground)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateMeasuredWidth(proxy.size.width)
                    }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        updateMeasuredWidth(newWidth)
                    }
            }
        }
    }

    private func deskCard(_ node: ResolvedMemoryDeskNode, availableSize: CGSize) -> some View {
        CaptureCardView(
            presentation: CaptureCardPresentation(
                item: node.item,
                role: .detailViewing,
                provenanceDisplayMode: .production,
                contentKind: node.contentKind,
                contentDensity: node.contentDensity
            ),
            objectAvailableSize: availableSize,
            onTap: { performPrimaryAction(for: node) }
        )
        .contextMenu {
            cardContextMenu(for: node)
        }
    }

    @ViewBuilder
    private func cardContextMenu(for node: ResolvedMemoryDeskNode) -> some View {
        Button {
            performPreviewAction(for: node)
        } label: {
            Label("memory.card.preview", systemImage: "eye")
        }

        Menu {
            ForEach(MemoryCardPresentationPolicy.supportedDensities(for: node.contentKind)) { density in
                Button {
                    onSetCardDensity(node.id, density)
                } label: {
                    Label(density.menuLabel, systemImage: density == node.contentDensity ? "checkmark" : density.systemImage)
                }
            }
        } label: {
            Label("memory.card.displayDensity", systemImage: "rectangle.3.group")
        }

        Button {
            onEditMemory()
        } label: {
            Label("memory.card.edit", systemImage: "pencil")
        }

        if canMergeMediaWithPrevious(node), let primaryArtifactID = node.primaryArtifactID {
            Button {
                onMergeMediaWithPrevious(primaryArtifactID)
            } label: {
                Label("memory.card.mergeMedia", systemImage: "rectangle.stack.badge.plus")
            }
        }

        if node.isMediaGroup {
            Button {
                onUnmergeMedia(node.id)
            } label: {
                Label("memory.card.spreadMedia", systemImage: "square.split.2x1")
            }
        }

        if !node.artifactIDs.isEmpty {
            Divider()

            Button(role: .destructive) {
                onDeleteArtifacts(node.artifactIDs)
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    private func performPrimaryAction(for node: ResolvedMemoryDeskNode) {
        switch node.contentKind {
        case .place:
            node.primaryArtifactID.map(onOpenPlace)
        case .link:
            node.primaryArtifactID.map(onOpenLink)
        case .music:
            node.primaryArtifactID.map(onToggleMusic)
        default:
            performPreviewAction(for: node)
        }
    }

    private func performPreviewAction(for node: ResolvedMemoryDeskNode) {
        switch node.contentRef {
        case .recordBody:
            onPreviewRecord()
        case .artifact, .artifactGroup:
            onPreviewArtifacts(node.artifactIDs)
        case .affect, .journalingSuggestion:
            onPreviewArtifacts(node.artifactIDs)
        }
    }

    private func canMergeMediaWithPrevious(_ node: ResolvedMemoryDeskNode) -> Bool {
        guard node.isSingleMedia else { return false }
        let ordered = resolvedNodes
        guard let index = ordered.firstIndex(where: { $0.id == node.id }), index > 0 else { return false }
        return ordered[index - 1].isMediaNode
    }

    private func updateMeasuredWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0, abs(width - measuredContainerWidth) > 0.5 else { return }
        measuredContainerWidth = width
    }

    private func resolveNode(_ node: MemoryCardNode) -> ResolvedMemoryDeskNode? {
        switch node.contentRef {
        case .recordBody:
            guard let rawText = snapshot.record.rawText.trimmedOrNil else { return nil }
            return ResolvedMemoryDeskNode(
                id: node.id,
                contentRef: node.contentRef,
                artifacts: [],
                item: CaptureCardItem(
                    id: "record-\(snapshot.record.id.uuidString)",
                    payload: .prompt(CapturePromptCardPayload(prompt: snapshot.record.displayTitle, answer: rawText)),
                    origin: snapshot.record.captureProvenance?.artifactOrigin ?? .manual,
                    provenance: snapshot.record.captureProvenance,
                    title: snapshot.record.displayTitle,
                    detail: rawText,
                    metadata: snapshot.record.createdAt.formatted(date: .abbreviated, time: .shortened)
                ),
                contentKind: .recordBody,
                contentDensity: node.contentDensity,
                layout: node.layout
            )
        case let .artifact(id):
            guard let artifact = snapshot.artifacts.first(where: { $0.id == id }) else { return nil }
            return ResolvedMemoryDeskNode(
                id: node.id,
                contentRef: node.contentRef,
                artifacts: [artifact],
                item: CaptureCardItem(artifact: artifact),
                contentKind: CaptureCardItem(artifact: artifact).memoryContentKind,
                contentDensity: node.contentDensity,
                layout: node.layout
            )
        case let .artifactGroup(ids, kind):
            let artifacts = ids.compactMap { id in snapshot.artifacts.first(where: { $0.id == id }) }
            guard !artifacts.isEmpty else { return nil }
            return ResolvedMemoryDeskNode(
                id: node.id,
                contentRef: node.contentRef,
                artifacts: artifacts,
                item: groupedItem(artifacts: artifacts, kind: kind, nodeID: node.id),
                contentKind: groupContentKind(artifacts: artifacts, kind: kind),
                contentDensity: node.contentDensity,
                layout: node.layout
            )
        case .affect:
            return nil
        case let .journalingSuggestion(importSessionID):
            let artifacts = snapshot.artifacts.filter { $0.captureProvenance?.importSessionID == importSessionID }
            guard !artifacts.isEmpty else { return nil }
            return ResolvedMemoryDeskNode(
                id: node.id,
                contentRef: node.contentRef,
                artifacts: artifacts,
                item: journalingSuggestionItem(importSessionID: importSessionID, artifacts: artifacts),
                contentKind: .journalingSuggestion,
                contentDensity: node.contentDensity,
                layout: node.layout
            )
        }
    }

    private func groupedItem(artifacts: [Artifact], kind: MemoryCardGroupKind, nodeID: UUID) -> CaptureCardItem {
        if kind.isMediaGroup,
           let first = artifacts.first,
           first.isMemoryCardMergeableMedia {
            return mediaStackItem(first: first, artifacts: artifacts, nodeID: nodeID)
        }

        let thumbnail = artifacts.compactMap { $0.previewPayload ?? $0.binaryPayload }.first
        let title: String
        switch kind {
        case .mediaStack:
            title = String(localized: "memory.desk.group.mediaStack")
        case .photoStack:
            title = String(localized: "memory.desk.group.photoStack")
        case .mixedContext:
            title = String(localized: "memory.desk.group.mixedContext")
        case .journalingBundle:
            title = String(localized: "memory.desk.group.journalingBundle")
        }
        return CaptureCardItem(
            id: "group-\(nodeID.uuidString)",
            payload: .journalingSuggestion(
                CaptureJournalingSuggestionCardPayload(
                    artifactCount: artifacts.count,
                    affectCount: 0,
                    photoCount: artifacts.filter { $0.kind == .photo }.count,
                    videoCount: artifacts.filter { $0.kind == .video }.count,
                    livePhotoCount: artifacts.filter { $0.kind == .livePhoto }.count,
                    locationCount: artifacts.filter { $0.kind == .location }.count,
                    musicCount: artifacts.filter { $0.kind == .music }.count,
                    promptCount: artifacts.filter { $0.metadata["documentType"] == "promptAnswer" }.count,
                    thumbnailData: thumbnail
                )
            ),
            origin: artifacts.first?.deskCaptureOrigin,
            provenance: artifacts.first?.captureProvenance,
            title: title,
            detail: artifacts.map(\.title).compactMap(\.trimmedOrNil).prefix(3).joined(separator: " · "),
            metadata: "\(artifacts.count)"
        )
    }

    private func mediaStackItem(first: Artifact, artifacts: [Artifact], nodeID: UUID) -> CaptureCardItem {
        let base = CaptureCardItem(artifact: first)
        let payload: CaptureCardPayload
        switch base.payload {
        case var .photo(photo):
            photo.photoCount = artifacts.count
            payload = .photo(photo)
        case var .video(video):
            video.mediaCount = artifacts.count
            payload = .video(video)
        case var .livePhoto(livePhoto):
            livePhoto.mediaCount = artifacts.count
            payload = .livePhoto(livePhoto)
        default:
            payload = base.payload
        }
        return CaptureCardItem(
            id: "media-group-\(nodeID.uuidString)",
            payload: payload,
            origin: first.deskCaptureOrigin,
            provenance: first.captureProvenance,
            title: base.title,
            detail: base.detail,
            metadata: "\(artifacts.count)"
        )
    }

    private func groupContentKind(artifacts: [Artifact], kind: MemoryCardGroupKind) -> MemoryCardContentKind {
        guard kind.isMediaGroup,
              let first = artifacts.first,
              first.isMemoryCardMergeableMedia else {
            return .bundle
        }
        return CaptureCardItem(artifact: first).memoryContentKind
    }

    private func journalingSuggestionItem(importSessionID: UUID, artifacts: [Artifact]) -> CaptureCardItem {
        CaptureCardItem(
            id: "journaling-\(importSessionID.uuidString)",
            payload: .journalingSuggestion(
                CaptureJournalingSuggestionCardPayload(
                    artifactCount: artifacts.count,
                    affectCount: 0,
                    photoCount: artifacts.filter { $0.kind == .photo }.count,
                    videoCount: artifacts.filter { $0.kind == .video }.count,
                    livePhotoCount: artifacts.filter { $0.kind == .livePhoto }.count,
                    locationCount: artifacts.filter { $0.kind == .location }.count,
                    musicCount: artifacts.filter { $0.kind == .music }.count,
                    promptCount: artifacts.filter { $0.metadata["documentType"] == "promptAnswer" }.count,
                    thumbnailData: artifacts.compactMap { $0.previewPayload ?? $0.binaryPayload }.first
                )
            ),
            origin: .imported,
            provenance: artifacts.first?.captureProvenance,
            title: String(localized: "capture.card.kind.journalingSuggestion"),
            detail: String(localized: "memory.desk.journalingSuggestion.detail"),
            metadata: String(localized: "memory.desk.journalingSuggestion.metadata")
        )
    }

    private var deskBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground).opacity(0.65),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct MemoryDeskRenderPlan {
    static func nodes(for snapshot: MemoryDetailSnapshot) -> [MemoryCardNode] {
        let arrangement = snapshot.cardArrangement
            ?? MemoryCardArrangement.defaultArrangement(
                record: snapshot.record,
                artifacts: snapshot.artifacts,
                createdAt: snapshot.record.createdAt
            )
        return arrangement.nodes
            .filter { isResolvable($0, snapshot: snapshot) }
            .sorted { lhs, rhs in
                if lhs.layout.order == rhs.layout.order {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.layout.order < rhs.layout.order
            }
    }

    private static func isResolvable(_ node: MemoryCardNode, snapshot: MemoryDetailSnapshot) -> Bool {
        switch node.contentRef {
        case .recordBody:
            return snapshot.record.rawText.trimmedOrNil != nil
        case let .artifact(id):
            return snapshot.artifacts.contains { $0.id == id }
        case let .artifactGroup(ids, _):
            return ids.contains { id in snapshot.artifacts.contains { $0.id == id } }
        case .affect:
            return false
        case let .journalingSuggestion(importSessionID):
            return snapshot.artifacts.contains { $0.captureProvenance?.importSessionID == importSessionID }
        }
    }
}

private struct ResolvedMemoryDeskNode: Identifiable {
    let id: UUID
    var contentRef: MemoryCardContentRef
    var artifacts: [Artifact]
    var item: CaptureCardItem
    var contentKind: MemoryCardContentKind
    var contentDensity: MemoryCardContentDensity
    var layout: MemoryCardLayoutToken

    var artifactIDs: [UUID] {
        artifacts.map(\.id)
    }

    var primaryArtifactID: UUID? {
        artifactIDs.first
    }

    var isSingleMedia: Bool {
        artifacts.count == 1 && artifacts[0].isMemoryCardMergeableMedia
    }

    var isMediaNode: Bool {
        !artifacts.isEmpty && artifacts.allSatisfy(\.isMemoryCardMergeableMedia)
    }

    var isMediaGroup: Bool {
        artifacts.count > 1 && isMediaNode
    }

    var renderRotationDegrees: Double {
        isMediaNode ? 0 : layout.rotationDegrees
    }
}

private struct ResolvedMemoryDeskSlot: Identifiable {
    let id: UUID
    let node: ResolvedMemoryDeskNode
    let frame: CGRect

    init(node: ResolvedMemoryDeskNode, frame: CGRect) {
        self.id = node.id
        self.node = node
        self.frame = frame
    }
}

private extension Artifact {
    var deskCaptureOrigin: CaptureArtifactOrigin? {
        captureProvenance?.artifactOrigin
            ?? metadata["captureOrigin"].flatMap(CaptureArtifactOrigin.init(rawValue:))
    }
}

extension MemoryCardContentDensity {
    var menuLabel: LocalizedStringKey {
        switch self {
        case .simple: return "memory.card.density.simple"
        case .standard: return "memory.card.density.standard"
        case .detailed: return "memory.card.density.detailed"
        }
    }

    var systemImage: String {
        switch self {
        case .simple: return "capsule"
        case .standard: return "rectangle"
        case .detailed: return "rectangle.portrait"
        }
    }
}

private extension MemoryCardGroupKind {
    var isMediaGroup: Bool {
        self == .mediaStack || self == .photoStack
    }
}
