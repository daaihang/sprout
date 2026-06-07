import Foundation

struct CaptureComposerAttachmentItem: Identifiable {
    enum Source: Equatable {
        case stagedArtifact(index: Int)
        case draftGroup(nodeID: UUID, draftIDs: [UUID])
        case contextCandidate(id: UUID)
        case affect(index: Int)
        case journalingSuggestion(importSessionID: UUID)
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

    static func draftGroup(nodeID: UUID, drafts: [CaptureArtifactDraft]) -> CaptureComposerAttachmentItem? {
        guard let first = drafts.first else { return nil }
        let itemID = "draft-group-\(nodeID.uuidString)"
        var card = CaptureCardItem(draft: first, id: itemID)
        switch card.payload {
        case var .photo(payload):
            payload.photoCount = drafts.count
            card.payload = .photo(payload)
        case var .video(payload):
            payload.mediaCount = drafts.count
            card.payload = .video(payload)
        case var .livePhoto(payload):
            payload.mediaCount = drafts.count
            card.payload = .livePhoto(payload)
        default:
            break
        }
        card.metadata = "\(drafts.count)"
        return CaptureComposerAttachmentItem(
            id: itemID,
            source: .draftGroup(nodeID: nodeID, draftIDs: drafts.map(\.draftID)),
            card: card
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

    static func affect(index: Int, draft: AffectSnapshotDraft) -> CaptureComposerAttachmentItem {
        let title = draft.labels.first?.rawValue
            ?? draft.rawInput?.trimmedOrNil
            ?? "Mood"
        let detail = draft.evidenceSummary?.trimmedOrNil
            ?? draft.rawInput?.trimmedOrNil
            ?? draft.labels.map(\.rawValue).joined(separator: ", ")
            .trimmedOrNil
            ?? "Affect evidence"
        let metadata = [
            draft.valence.map { "valence \(String(format: "%.2f", $0))" },
            draft.sources.first?.rawValue
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
        .trimmedOrNil
        let itemID = "affect-\(index)-\(title)"
        return CaptureComposerAttachmentItem(
            id: itemID,
            source: .affect(index: index),
            card: CaptureCardItem(
                id: itemID,
                payload: .affect(CaptureAffectCardPayload(valence: draft.valence, sourceDescription: draft.sources.first?.rawValue)),
                origin: draft.provenance?.artifactOrigin ?? (draft.sources.contains(.journalSuggestionStateOfMind) ? .imported : .manual),
                provenance: draft.provenance,
                state: .normal,
                title: title,
                detail: detail,
                metadata: metadata,
                isRemovable: true
            )
        )
    }

    static func journalingSuggestion(importSessionID: UUID, artifacts: [CaptureArtifactDraft], affects: [AffectSnapshotDraft]) -> CaptureComposerAttachmentItem {
        let payload = CaptureJournalingSuggestionCardPayload(
            artifactCount: artifacts.count,
            affectCount: affects.count,
            photoCount: artifacts.filter(\.isPhotoContent).count,
            videoCount: artifacts.filter(\.isVideoContent).count,
            livePhotoCount: artifacts.filter(\.isLivePhotoContent).count,
            locationCount: artifacts.filter(\.isLocationContent).count,
            musicCount: artifacts.filter(\.isMusicContent).count,
            promptCount: artifacts.filter(\.isPromptAnswerContent).count,
            thumbnailData: artifacts.compactMap(\.journalingPreviewData).first
        )
        let itemID = "journaling-\(importSessionID.uuidString)"
        let detail = [
            artifacts.isEmpty ? nil : "\(artifacts.count) items",
            affects.isEmpty ? nil : "\(affects.count) moods",
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
        .trimmedOrNil ?? "Journaling suggestion"

        return CaptureComposerAttachmentItem(
            id: itemID,
            source: .journalingSuggestion(importSessionID: importSessionID),
            card: CaptureCardItem(
                id: itemID,
                payload: .journalingSuggestion(payload),
                origin: .imported,
                provenance: artifacts.first?.provenance ?? affects.first?.provenance,
                state: .normal,
                title: "Journaling Suggestion",
                detail: detail,
                metadata: "Journaling",
                isRemovable: true
            )
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
        case .video:
            return .video(CaptureVideoCardPayload())
        case .livePhoto:
            return .livePhoto(CaptureLivePhotoCardPayload())
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
        case .prompt:
            return .prompt(CapturePromptCardPayload(prompt: ""))
        case .person:
            return .person(CapturePersonContextCardPayload(name: ""))
        case .affect:
            return .affect(CaptureAffectCardPayload())
        case .journalingSuggestion:
            return .journalingSuggestion(CaptureJournalingSuggestionCardPayload(artifactCount: 0, affectCount: 0))
        case .status:
            return .status(CaptureStatusCardPayload())
        }
    }
}

private extension CaptureArtifactDraft {
    var journalingPreviewData: Data? {
        switch content {
        case let .photo(content):
            return content.thumbnailData ?? content.imageData
        case let .video(content):
            return content.thumbnailData
        case let .livePhoto(content):
            return content.thumbnailData ?? content.stillImageData
        case let .music(content):
            return content.artworkData
        case let .personContext(content):
            return content.photoData
        case .text, .audio, .location, .link, .todo, .promptAnswer, .weather:
            return nil
        }
    }

    var isPhotoContent: Bool {
        if case .photo = content { return true }
        return false
    }

    var isVideoContent: Bool {
        if case .video = content { return true }
        return false
    }

    var isLivePhotoContent: Bool {
        if case .livePhoto = content { return true }
        return false
    }

    var isLocationContent: Bool {
        if case .location = content { return true }
        return false
    }

    var isMusicContent: Bool {
        if case .music = content { return true }
        return false
    }

    var isPromptAnswerContent: Bool {
        if case .promptAnswer = content { return true }
        return false
    }
}
