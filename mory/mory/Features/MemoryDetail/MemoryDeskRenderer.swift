import SwiftUI

struct MemoryDeskRenderer: View {
    let snapshot: MemoryDetailSnapshot

    private var resolvedNodes: [ResolvedMemoryDeskNode] {
        MemoryDeskRenderPlan.nodes(for: snapshot).compactMap(resolveNode(_:)).sorted { lhs, rhs in
            if lhs.layout.order == rhs.layout.order {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.layout.order < rhs.layout.order
        }
    }

    var body: some View {
        LazyVStack(alignment: .center, spacing: 18) {
            ForEach(resolvedNodes) { node in
                deskCard(node)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(deskBackground)
    }

    private func deskCard(_ node: ResolvedMemoryDeskNode) -> some View {
        CaptureCardView(
            presentation: CaptureCardPresentation(
                item: node.item,
                role: .detailViewing,
                provenanceDisplayMode: .production,
                musicCardStyle: .auto,
                placeCardStyle: .auto,
                surfaceMode: .skeuomorphic
            )
        )
        .frame(width: width(for: node.layout.size), alignment: .center)
        .rotationEffect(.degrees(node.layout.rotationDegrees))
        .offset(x: node.layout.xNudge, y: node.layout.yNudge)
        .zIndex(Double(node.layout.zIndex))
        .frame(maxWidth: .infinity, alignment: alignment(for: node.layout.order))
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

    private func width(for size: MemoryCardSizeToken) -> CGFloat? {
        switch size {
        case .small:
            return 180
        case .medium:
            return 220
        case .wide:
            return 300
        case .hero, .stack:
            return 330
        }
    }

    private func alignment(for order: Int) -> Alignment {
        switch order % 3 {
        case 0:
            return .leading
        case 1:
            return .trailing
        default:
            return .center
        }
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

private extension MemoryCardArrangement {
    static func defaultVisualRecipeForRendering(_ artifact: Artifact) -> MemoryCardVisualRecipe {
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

    static func defaultSizeForRendering(_ artifact: Artifact) -> MemoryCardSizeToken {
        switch artifact.kind {
        case .photo, .video, .livePhoto:
            return .hero
        case .music, .audio:
            return .wide
        case .location, .weather, .text, .link, .todo, .document:
            return .medium
        }
    }
}
