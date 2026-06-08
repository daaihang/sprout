import SwiftUI

enum MemoryCardArrangementDraftEditing {
    static func attachmentItems(
        drafts: [CaptureArtifactDraft],
        arrangement: MemoryCardArrangementDraft
    ) -> [CaptureComposerAttachmentItem] {
        let draftByID = Dictionary(uniqueKeysWithValues: drafts.map { ($0.draftID, $0) })
        let orderedNodes = arrangement.nodes.sorted { lhs, rhs in
            if lhs.layout.order == rhs.layout.order {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.layout.order < rhs.layout.order
        }
        return orderedNodes.flatMap { node -> [CaptureComposerAttachmentItem] in
            switch node.contentRef {
            case let .artifactDraft(draftID):
                guard let index = drafts.firstIndex(where: { $0.draftID == draftID }) else { return [] }
                return [.staged(index: index, draft: drafts[index])]
            case let .artifactDraftGroup(draftIDs, _):
                let groupedDrafts = draftIDs.compactMap { draftByID[$0] }
                guard !groupedDrafts.isEmpty else { return [] }
                if groupedDrafts.allSatisfy(\.isMemoryCardMergeableMedia),
                   let groupItem = CaptureComposerAttachmentItem.draftGroup(nodeID: node.id, drafts: groupedDrafts) {
                    return [groupItem]
                }
                return groupedDrafts.compactMap { draft in
                    guard let index = drafts.firstIndex(where: { $0.draftID == draft.draftID }) else { return nil }
                    return .staged(index: index, draft: draft)
                }
            case .recordBody, .affectDraft, .journalingSuggestion:
                return []
            }
        }
    }

    static func draftID(for item: CaptureComposerAttachmentItem, drafts: [CaptureArtifactDraft]) -> UUID? {
        switch item.source {
        case let .stagedArtifact(index):
            return drafts.indices.contains(index) ? drafts[index].draftID : nil
        case let .draftGroup(_, draftIDs):
            return draftIDs.first
        case .contextCandidate, .affect, .journalingSuggestion, .processing:
            return nil
        }
    }

    static func removeDraft(
        at index: Int,
        drafts: inout [CaptureArtifactDraft],
        arrangement: inout MemoryCardArrangementDraft
    ) {
        guard drafts.indices.contains(index) else { return }
        let removed = drafts.remove(at: index)
        arrangement.removeArtifactDraft(removed.draftID, artifactDrafts: drafts)
    }

    static func removeDraftGroup(
        _ draftIDs: [UUID],
        drafts: inout [CaptureArtifactDraft],
        arrangement: inout MemoryCardArrangementDraft
    ) {
        guard !draftIDs.isEmpty else { return }
        let ids = Set(draftIDs)
        drafts.removeAll { ids.contains($0.draftID) }
        draftIDs.forEach { arrangement.removeArtifactDraft($0, artifactDrafts: drafts) }
    }

    static func reorder(
        source: CaptureComposerAttachmentItem,
        target: CaptureComposerAttachmentItem,
        drafts: [CaptureArtifactDraft],
        arrangement: inout MemoryCardArrangementDraft
    ) {
        guard let sourceDraftID = draftID(for: source, drafts: drafts),
              let targetDraftID = draftID(for: target, drafts: drafts),
              sourceDraftID != targetDraftID else {
            return
        }
        arrangement.reorderArtifactDraft(from: sourceDraftID, to: targetDraftID)
    }

    static func setDensity(
        _ density: MemoryCardContentDensity,
        for item: CaptureComposerAttachmentItem,
        drafts: [CaptureArtifactDraft],
        arrangement: inout MemoryCardArrangementDraft
    ) {
        guard let draftID = draftID(for: item, drafts: drafts) else { return }
        arrangement.setContentDensity(density, forDraftID: draftID)
    }

    static func stackWithPrevious(
        item: CaptureComposerAttachmentItem,
        drafts: [CaptureArtifactDraft],
        arrangement: inout MemoryCardArrangementDraft
    ) {
        guard let draftID = draftID(for: item, drafts: drafts),
              drafts.first(where: { $0.draftID == draftID })?.isMemoryCardMergeableMedia == true else {
            return
        }
        let nodes = arrangement.nodes.sorted { lhs, rhs in
            if lhs.layout.order == rhs.layout.order {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.layout.order < rhs.layout.order
        }
        guard let index = nodes.firstIndex(where: { node in
            node.contentRef.artifactDraftIDs.contains(draftID)
        }), index > 0 else {
            return
        }
        let previousDraftIDs = nodes[index - 1].contentRef.artifactDraftIDs
        guard !previousDraftIDs.isEmpty,
              previousDraftIDs.allSatisfy({ previousID in
                  drafts.first(where: { $0.draftID == previousID })?.isMemoryCardMergeableMedia == true
              }) else {
            return
        }
        arrangement.toggleStackWithPrevious(draftID: draftID)
    }

    static func unstack(
        item: CaptureComposerAttachmentItem,
        drafts: [CaptureArtifactDraft],
        arrangement: inout MemoryCardArrangementDraft
    ) {
        guard let draftID = draftID(for: item, drafts: drafts) else { return }
        arrangement.unstackContainingDraft(draftID, artifactDrafts: drafts)
    }
}
