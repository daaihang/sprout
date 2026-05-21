import Foundation

struct CaptureComposerAttachmentItem: Identifiable {
    enum Source: Equatable {
        case stagedArtifact(index: Int)
        case contextCandidate(id: UUID)
        case processing(id: String)
    }

    let id: String
    let source: Source
    var card: CaptureCardItem

    var isProcessing: Bool {
        card.state == .loading
    }

    var isRemovable: Bool {
        card.isRemovable
    }

    static func staged(index: Int, draft: CaptureArtifactDraft) -> CaptureComposerAttachmentItem {
        let id = "staged-\(index)-\(draft.id)"
        return CaptureComposerAttachmentItem(
            id: id,
            source: .stagedArtifact(index: index),
            card: CaptureCardItem(draft: draft, id: id)
        )
    }

    static func context(_ candidate: ContextCandidate) -> CaptureComposerAttachmentItem {
        let id = "context-\(candidate.id.uuidString)"
        var card = CaptureCardItem(draft: candidate.draft, id: id)
        if card.metadata?.trimmedOrNil == nil {
            card.metadata = candidate.capturedAt.formatted(date: .omitted, time: .shortened)
        }
        return CaptureComposerAttachmentItem(
            id: id,
            source: .contextCandidate(id: candidate.id),
            card: card
        )
    }

    static func processing(id: String, kind: CaptureCardKind = .status, detail: String) -> CaptureComposerAttachmentItem {
        let itemID = "processing-\(id)"
        return CaptureComposerAttachmentItem(
            id: itemID,
            source: .processing(id: id),
            card: CaptureCardItem(
                id: itemID,
                payload: processingPayload(for: kind),
                origin: nil,
                state: .loading,
                title: kind.label,
                detail: detail,
                isRemovable: false
            )
        )
    }

    private static func processingPayload(for kind: CaptureCardKind) -> CaptureCardPayload {
        switch kind {
        case .photo:
            return .photo(CapturePhotoCardPayload())
        case .audio:
            return .audio(CaptureAudioCardPayload())
        case .place:
            return .place(CapturePlaceCardPayload())
        case .weather:
            return .weather(CaptureWeatherCardPayload())
        case .music:
            return .music(CaptureMusicCardPayload())
        case .link:
            return .link(CaptureLinkCardPayload())
        case .todo:
            return .todo(CaptureTodoCardPayload())
        case .status:
            return .status(CaptureStatusCardPayload())
        }
    }
}
