import SwiftUI

struct MemoryDetailEditingView: View {
    @Binding var title: String
    @Binding var rawText: String
    @Binding var isRecordBodyCardVisible: Bool

    let artifacts: [Artifact]
    let cardArrangement: MemoryCardArrangement?
    let addedDraftItems: [CaptureComposerAttachmentItem]
    let errorMessage: String?
    var onDeleteArtifacts: ([UUID]) -> Void
    var onPreviewArtifacts: ([UUID]) -> Void
    var onSetCardDensity: (UUID, MemoryCardContentDensity) -> Void
    var onStackArtifactWithPrevious: (UUID) -> Void
    var onUnstackArtifact: (UUID) -> Void
    var onAutoArrange: () -> Void
    var onRemoveAddedDraft: (Int) -> Void
    var onRemoveAddedDraftGroup: ([UUID]) -> Void
    var onPreviewAddedDraft: (CaptureComposerAttachmentItem) -> Void
    var onSetAddedDraftDensity: (CaptureComposerAttachmentItem, MemoryCardContentDensity) -> Void
    var onReorderAddedDraft: (CaptureComposerAttachmentItem, CaptureComposerAttachmentItem) -> Void
    var onStackAddedDraftWithPrevious: (CaptureComposerAttachmentItem) -> Void
    var onUnstackAddedDraft: (CaptureComposerAttachmentItem) -> Void

    @FocusState private var isBodyFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    MemoryDetailEditingBoardView(
                        artifacts: artifacts,
                        cardArrangement: cardArrangement,
                        onDeleteArtifacts: onDeleteArtifacts,
                        onPreviewArtifacts: onPreviewArtifacts,
                        onSetCardDensity: onSetCardDensity,
                        onStackArtifactWithPrevious: onStackArtifactWithPrevious,
                        onUnstackArtifact: onUnstackArtifact,
                        onAutoArrange: onAutoArrange
                    )

                    if !addedDraftItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("memory.edit.newCards")
                                .font(.headline)
                                .padding(.horizontal, 20)

                            CaptureAttachmentCompactBoardView(
                                items: addedDraftItems,
                                onRemoveStagedArtifact: onRemoveAddedDraft,
                                onRemoveContextCandidate: { _ in },
                                onRemoveDraftGroup: onRemoveAddedDraftGroup,
                                onRemoveAffectDraft: { _ in },
                                onRemoveJournalingSuggestion: { _ in },
                                onReorderItems: onReorderAddedDraft,
                                onStackWithPrevious: onStackAddedDraftWithPrevious,
                                onUnstack: onUnstackAddedDraft,
                                onSetDensity: onSetAddedDraftDensity,
                                onPreview: onPreviewAddedDraft
                            )
                        }
                        .padding(.top, artifacts.isEmpty ? 16 : 10)
                    }

                    titleEditor
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    if isRecordBodyCardVisible {
                        RecordBodyCardEditor(
                            text: $rawText,
                            focus: $isBodyFocused,
                            minHeight: max(proxy.size.height - 360, 160)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }

                    statusSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemBackground))
    }

    private var titleEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("memory.edit.title")
                .font(.headline)
            TextField("memory.edit.title.placeholder", text: $title)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusSection: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

}

struct MemoryDetailEditingBoardView: View {
    let artifacts: [Artifact]
    let cardArrangement: MemoryCardArrangement?
    var onDeleteArtifacts: ([UUID]) -> Void
    var onPreviewArtifacts: ([UUID]) -> Void
    var onSetCardDensity: (UUID, MemoryCardContentDensity) -> Void
    var onStackArtifactWithPrevious: (UUID) -> Void
    var onUnstackArtifact: (UUID) -> Void
    var onAutoArrange: () -> Void

    @State private var measuredContainerWidth: CGFloat = 0
    private let metrics = MemoryDeskBoardMetrics.default

    private var containerWidth: CGFloat {
        measuredContainerWidth > 0 ? measuredContainerWidth : 390
    }

    private var boardNodes: [MemoryDetailEditingBoardNode] {
        guard let cardArrangement else { return [] }
        let artifactByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        return cardArrangement.nodes
            .sorted { lhs, rhs in
                if lhs.layout.order == rhs.layout.order {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.layout.order < rhs.layout.order
            }
            .compactMap { node in
                MemoryDetailEditingBoardNode(node: node, artifactByID: artifactByID)
            }
    }

    private var layoutPlan: MemoryDeskBoardLayoutPlan<UUID> {
        let columnWidth = metrics.columnSpec(for: containerWidth).columnWidth
        return MemoryDeskBoardLayoutPlan.make(
            nodes: boardNodes.map {
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

    private var resolvedSlots: [MemoryDetailEditingBoardSlot] {
        let nodeByID = Dictionary(uniqueKeysWithValues: boardNodes.map { ($0.id, $0) })
        return layoutPlan.slots.compactMap { slot in
            guard let node = nodeByID[slot.id] else { return nil }
            return MemoryDetailEditingBoardSlot(node: node, frame: slot.frame)
        }
    }

    var body: some View {
        if !boardNodes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Arrangement")
                        .font(.headline)
                    Spacer()
                    Button {
                        onAutoArrange()
                    } label: {
                        Label("Auto Arrange", systemImage: "wand.and.stars")
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ZStack(alignment: .topLeading) {
                    ForEach(resolvedSlots) { slot in
                        MemoryDetailEditingBoardCard(
                            node: slot.node,
                            availableSize: slot.frame.size,
                            canMergeWithPrevious: canMergeMediaWithPrevious(slot.node),
                            onDelete: { onDeleteArtifacts(slot.node.artifactIDs) },
                            onPreview: { onPreviewArtifacts(slot.node.artifactIDs) },
                            onSetDensity: { density in onSetCardDensity(slot.node.id, density) },
                            onStackWithPrevious: { onStackArtifactWithPrevious(slot.node.primaryArtifactID) },
                            onUnstack: { onUnstackArtifact(slot.node.primaryArtifactID) }
                        )
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
                .background(boardBackground)
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
        }
    }

    private var boardBackground: some View {
        LinearGradient(
            colors: [
                Color(.secondarySystemBackground).opacity(0.34),
                Color(.systemBackground).opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func updateMeasuredWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0, abs(width - measuredContainerWidth) > 0.5 else { return }
        measuredContainerWidth = width
    }

    private func canMergeMediaWithPrevious(_ node: MemoryDetailEditingBoardNode) -> Bool {
        guard node.isSingleMedia else { return false }
        guard let index = boardNodes.firstIndex(where: { $0.id == node.id }), index > 0 else { return false }
        return boardNodes[index - 1].isMediaNode
    }

}

private struct MemoryDetailEditingBoardCard: View {
    let node: MemoryDetailEditingBoardNode
    let availableSize: CGSize
    let canMergeWithPrevious: Bool
    var onDelete: () -> Void
    var onPreview: () -> Void
    var onSetDensity: (MemoryCardContentDensity) -> Void
    var onStackWithPrevious: () -> Void
    var onUnstack: () -> Void

    var body: some View {
        CaptureCardView(
            presentation: CaptureCardPresentation(
                item: node.item,
                role: .detailEditing,
                provenanceDisplayMode: .production,
                contentKind: node.contentKind,
                contentDensity: node.contentDensity
            ),
            objectAvailableSize: availableSize,
            onTap: onPreview
        )
        .contextMenu {
            MemoryCardActionMenu(configuration: MemoryCardActionMenuConfiguration(
                contentKind: node.contentKind,
                contentDensity: node.contentDensity,
                canPreview: true,
                canEdit: false,
                canSetDensity: true,
                canMergeMedia: canMergeWithPrevious,
                canSpreadMedia: node.isMediaGroup,
                canDelete: true,
                onPreview: onPreview,
                onSetDensity: onSetDensity,
                onMergeMedia: onStackWithPrevious,
                onSpreadMedia: onUnstack,
                onDelete: onDelete
            ))
        }
    }
}

private struct MemoryDetailEditingBoardNode: Identifiable {
    let id: UUID
    let artifactIDs: [UUID]
    let artifacts: [Artifact]
    let item: CaptureCardItem
    let contentKind: MemoryCardContentKind
    let contentDensity: MemoryCardContentDensity
    let layout: MemoryCardLayoutToken

    var primaryArtifactID: UUID {
        artifactIDs[0]
    }

    init?(node: MemoryCardNode, artifactByID: [UUID: Artifact]) {
        let artifacts: [Artifact]
        switch node.contentRef {
        case let .artifact(id):
            guard let artifact = artifactByID[id] else { return nil }
            artifacts = [artifact]
        case let .artifactGroup(ids, _):
            artifacts = ids.compactMap { artifactByID[$0] }
            guard !artifacts.isEmpty else { return nil }
        case .recordBody, .affect, .journalingSuggestion:
            return nil
        }

        self.id = node.id
        self.artifactIDs = artifacts.map(\.id)
        self.artifacts = artifacts
        self.item = artifacts.count == 1
            ? CaptureCardItem(artifact: artifacts[0])
            : Self.groupItem(nodeID: node.id, artifacts: artifacts)
        self.contentKind = Self.contentKind(for: artifacts)
        self.contentDensity = node.contentDensity
        self.layout = node.layout
    }

    private static func groupItem(nodeID: UUID, artifacts: [Artifact]) -> CaptureCardItem {
        if let first = artifacts.first,
           first.isMemoryCardMergeableMedia,
           artifacts.allSatisfy(\.isMemoryCardMergeableMedia) {
            return mediaStackItem(nodeID: nodeID, first: first, artifacts: artifacts)
        }

        let thumbnail = artifacts.compactMap { $0.previewPayload ?? $0.binaryPayload }.first
        return CaptureCardItem(
            id: "edit-group-\(nodeID.uuidString)",
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
            origin: artifacts.first?.captureProvenance?.artifactOrigin,
            provenance: artifacts.first?.captureProvenance,
            title: "Stack",
            detail: artifacts.map(\.title).compactMap(\.trimmedOrNil).prefix(3).joined(separator: " · "),
            metadata: "\(artifacts.count)"
        )
    }

    private static func mediaStackItem(nodeID: UUID, first: Artifact, artifacts: [Artifact]) -> CaptureCardItem {
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
            id: "edit-media-group-\(nodeID.uuidString)",
            payload: payload,
            origin: first.captureProvenance?.artifactOrigin,
            provenance: first.captureProvenance,
            title: base.title,
            detail: base.detail,
            metadata: "\(artifacts.count)"
        )
    }

    private static func contentKind(for artifacts: [Artifact]) -> MemoryCardContentKind {
        guard let first = artifacts.first else { return .bundle }
        if artifacts.count == 1 {
            return CaptureCardItem(artifact: first).memoryContentKind
        }
        guard artifacts.allSatisfy(\.isMemoryCardMergeableMedia) else {
            return .bundle
        }
        return CaptureCardItem(artifact: first).memoryContentKind
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

private struct MemoryDetailEditingBoardSlot: Identifiable {
    let id: UUID
    let node: MemoryDetailEditingBoardNode
    let frame: CGRect

    init(node: MemoryDetailEditingBoardNode, frame: CGRect) {
        self.id = node.id
        self.node = node
        self.frame = frame
    }
}

extension Artifact {
    var isVisibleMemoryDetailAttachment: Bool {
        kind != .text
    }
}

extension MemoryCardNode {
    var detailEditingArtifactIDs: [UUID] {
        switch contentRef {
        case let .artifact(id):
            return [id]
        case let .artifactGroup(ids, _):
            return ids
        case .recordBody, .affect, .journalingSuggestion:
            return []
        }
    }
}
