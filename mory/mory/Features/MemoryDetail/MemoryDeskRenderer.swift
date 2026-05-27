import SwiftUI

struct MemoryDeskRenderer: View {
    let snapshot: MemoryDetailSnapshot
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

    private var layoutPlan: MemoryDeskBoardLayoutPlan {
        MemoryDeskBoardLayoutPlan.make(
            nodes: resolvedNodes.map { MemoryDeskBoardInputNode(id: $0.id, layout: $0.layout) },
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
                deskCard(slot.node)
                    .frame(width: slot.frame.width, height: slot.frame.height, alignment: .center)
                    .position(
                        x: slot.frame.midX + slot.node.layout.xNudge,
                        y: slot.frame.midY + slot.node.layout.yNudge
                    )
                    .rotationEffect(.degrees(slot.node.layout.rotationDegrees))
                    .zIndex(Double(slot.node.layout.zIndex))
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

    private func deskCard(_ node: ResolvedMemoryDeskNode) -> some View {
        CaptureCardView(
            presentation: CaptureCardPresentation(
                item: node.item,
                role: .detailViewing,
                provenanceDisplayMode: .production,
                musicCardStyle: .auto,
                placeCardStyle: .auto,
                surfaceMode: .skeuomorphic,
                visualRecipe: node.visualRecipe,
                sizeToken: node.layout.size
            )
        )
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
                item: CaptureCardItem(
                    id: "record-\(snapshot.record.id.uuidString)",
                    payload: .prompt(CapturePromptCardPayload(prompt: snapshot.record.titleForDesk, answer: rawText)),
                    origin: snapshot.record.captureProvenance?.artifactOrigin ?? .manual,
                    provenance: snapshot.record.captureProvenance,
                    title: snapshot.record.titleForDesk,
                    detail: rawText,
                    metadata: snapshot.record.createdAt.formatted(date: .abbreviated, time: .shortened)
                ),
                visualRecipe: node.visualRecipe,
                layout: node.layout
            )
        case let .artifact(id):
            guard let artifact = snapshot.artifacts.first(where: { $0.id == id }) else { return nil }
            return ResolvedMemoryDeskNode(
                id: node.id,
                item: CaptureCardItem(artifact: artifact),
                visualRecipe: node.visualRecipe,
                layout: node.layout
            )
        case let .artifactGroup(ids, kind):
            let artifacts = ids.compactMap { id in snapshot.artifacts.first(where: { $0.id == id }) }
            guard !artifacts.isEmpty else { return nil }
            return ResolvedMemoryDeskNode(
                id: node.id,
                item: groupedItem(artifacts: artifacts, kind: kind, nodeID: node.id),
                visualRecipe: node.visualRecipe,
                layout: node.layout
            )
        case .affect:
            return nil
        case let .journalingSuggestion(importSessionID):
            let artifacts = snapshot.artifacts.filter { $0.captureProvenance?.importSessionID == importSessionID }
            guard !artifacts.isEmpty else { return nil }
            return ResolvedMemoryDeskNode(
                id: node.id,
                item: journalingSuggestionItem(importSessionID: importSessionID, artifacts: artifacts),
                visualRecipe: node.visualRecipe,
                layout: node.layout
            )
        }
    }

    private func groupedItem(artifacts: [Artifact], kind: MemoryCardGroupKind, nodeID: UUID) -> CaptureCardItem {
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
            payload: .photo(CapturePhotoCardPayload(thumbnailData: thumbnail, photoCount: artifacts.count, groupStyle: .stack)),
            origin: artifacts.first?.deskCaptureOrigin,
            provenance: artifacts.first?.captureProvenance,
            title: title,
            detail: artifacts.map(\.title).compactMap(\.trimmedOrNil).prefix(3).joined(separator: " · "),
            metadata: "\(artifacts.count)"
        )
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
    var item: CaptureCardItem
    var visualRecipe: MemoryCardVisualRecipe
    var layout: MemoryCardLayoutToken
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

struct MemoryDeskBoardMetrics: Hashable, Sendable {
    var columns: Int
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var columnSpacing: CGFloat
    var rowSpacing: CGFloat
    var rowHeight: CGFloat
    var minimumCellWidth: CGFloat

    static let `default` = MemoryDeskBoardMetrics(
        columns: MemoryCardRecipeLayoutPolicy.columnCount,
        horizontalPadding: 16,
        verticalPadding: 18,
        columnSpacing: 10,
        rowSpacing: 12,
        rowHeight: 82,
        minimumCellWidth: 42
    )

    func cellWidth(for containerWidth: CGFloat) -> CGFloat {
        let clampedColumns = max(1, columns)
        let usableWidth = max(containerWidth - (horizontalPadding * 2), minimumCellWidth * CGFloat(clampedColumns))
        let totalSpacing = columnSpacing * CGFloat(clampedColumns - 1)
        return max(minimumCellWidth, floor((usableWidth - totalSpacing) / CGFloat(clampedColumns)))
    }
}

struct MemoryDeskBoardInputNode: Hashable, Sendable {
    let id: UUID
    let layout: MemoryCardLayoutToken
}

struct MemoryDeskBoardLayoutSlot: Identifiable, Hashable, Sendable {
    let id: UUID
    let layout: MemoryCardLayoutToken
    let frame: CGRect
}

struct MemoryDeskBoardLayoutPlan: Hashable, Sendable {
    let slots: [MemoryDeskBoardLayoutSlot]
    let boardHeight: CGFloat

    static func make(
        nodes: [MemoryDeskBoardInputNode],
        containerWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics = .default
    ) -> MemoryDeskBoardLayoutPlan {
        let ordered = nodes.enumerated().map { index, node in
            (index: index, node: node)
        }
        let frames = ordered.map { entry in
            frame(for: entry.node.layout, containerWidth: containerWidth, metrics: metrics, fallbackOrder: entry.index)
        }
        let slots = zip(ordered, frames).map { entry, frame in
            MemoryDeskBoardLayoutSlot(id: entry.node.id, layout: entry.node.layout, frame: frame)
        }
        let maxY = frames.map(\.maxY).max() ?? 0
        let minHeight = metrics.verticalPadding * 2 + metrics.rowHeight
        return MemoryDeskBoardLayoutPlan(
            slots: slots,
            boardHeight: max(minHeight, maxY + metrics.verticalPadding)
        )
    }

    private static func frame(
        for layout: MemoryCardLayoutToken,
        containerWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics,
        fallbackOrder: Int
    ) -> CGRect {
        let columns = max(1, min(metrics.columns, MemoryCardRecipeLayoutPolicy.columnCount))
        let cellWidth = metrics.cellWidth(for: containerWidth)
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: layout.size)
        let fallbackPlacement = MemoryCardGridPlacement(
            column: max(0, fallbackOrder % columns),
            row: max(0, fallbackOrder / columns)
        )
        let placement = layout.gridPlacement ?? fallbackPlacement

        let x = metrics.horizontalPadding + CGFloat(placement.column) * (cellWidth + metrics.columnSpacing)
        let y = metrics.verticalPadding + CGFloat(placement.row) * (metrics.rowHeight + metrics.rowSpacing)
        let width = CGFloat(box.columnSpan) * cellWidth + CGFloat(max(0, box.columnSpan - 1)) * metrics.columnSpacing
        let height = CGFloat(box.rowSpan) * metrics.rowHeight + CGFloat(max(0, box.rowSpan - 1)) * metrics.rowSpacing

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private extension RecordShell {
    var titleForDesk: String {
        rawText.firstMeaningfulLine ?? "Untitled Memory"
    }
}

private extension Artifact {
    var deskCaptureOrigin: CaptureArtifactOrigin? {
        captureProvenance?.artifactOrigin
            ?? metadata["captureOrigin"].flatMap(CaptureArtifactOrigin.init(rawValue:))
    }
}
