import Foundation

enum CaptureCardPayload: Hashable, Sendable {
    case photo(CapturePhotoCardPayload)
    case video(CaptureVideoCardPayload)
    case livePhoto(CaptureLivePhotoCardPayload)
    case audio(CaptureAudioCardPayload)
    case place(CapturePlaceCardPayload)
    case weather(CaptureWeatherCardPayload)
    case music(CaptureMusicCardPayload)
    case link(CaptureLinkCardPayload)
    case todo(CaptureTodoCardPayload)
    case prompt(CapturePromptCardPayload)
    case person(CapturePersonContextCardPayload)
    case affect(CaptureAffectCardPayload)
    case journalingSuggestion(CaptureJournalingSuggestionCardPayload)
    case status(CaptureStatusCardPayload)

    var kind: CaptureCardKind {
        switch self {
        case .photo:
            return .photo
        case .video:
            return .video
        case .livePhoto:
            return .livePhoto
        case .audio:
            return .audio
        case .place:
            return .place
        case .weather:
            return .weather
        case .music:
            return .music
        case .link:
            return .link
        case .todo:
            return .todo
        case .prompt:
            return .prompt
        case .person:
            return .person
        case .affect:
            return .affect
        case .journalingSuggestion:
            return .journalingSuggestion
        case .status:
            return .status
        }
    }

}

struct CapturePhotoCardPayload: Hashable, Sendable {
    var thumbnailData: Data? = nil
    var mediaDimensions: ArtifactMediaDimensions? = nil
    var photoCount: Int = 1
}

struct CaptureVideoCardPayload: Hashable, Sendable {
    var thumbnailData: Data? = nil
    var durationSeconds: Int? = nil
    var mediaDimensions: ArtifactMediaDimensions? = nil
    var mediaCount: Int = 1
}

struct CaptureLivePhotoCardPayload: Hashable, Sendable {
    var thumbnailData: Data? = nil
    var pairedVideoByteCount: Int? = nil
    var mediaDimensions: ArtifactMediaDimensions? = nil
    var mediaCount: Int = 1
}

struct CaptureAudioCardPayload: Hashable, Sendable {
    var durationSeconds: Int? = nil
}

struct CapturePlaceCardPayload: Hashable, Sendable {
    var latitude: Double? = nil
    var longitude: Double? = nil
    var mapSnapshotData: Data? = nil
    var isPrivacyEnabled: Bool = false
}

struct CaptureWeatherCardPayload: Hashable, Sendable {
    var latitude: Double? = nil
    var longitude: Double? = nil
    var style: CaptureWeatherVisualStyle? = nil
    var conditionCode: String? = nil
    var symbolName: String? = nil
    var isDaylight: Bool? = nil
}

struct CaptureMusicCardPayload: Hashable, Sendable {
    var artworkURL: String? = nil
    var artworkData: Data? = nil
    var artworkPalette: MusicArtworkPalette? = nil
    var durationSeconds: Int? = nil
    var playbackState: CaptureMusicPlaybackState? = nil
    var catalogID: String? = nil
    var storeID: String? = nil
}

struct CaptureLinkCardPayload: Hashable, Sendable {
    var thumbnailData: Data? = nil
}

struct CaptureTodoCardPayload: Hashable, Sendable {}

struct CapturePromptCardPayload: Hashable, Sendable {
    var prompt: String
    var answer: String?
}

struct CapturePersonContextCardPayload: Hashable, Sendable {
    var name: String
    var photoData: Data? = nil
}

struct CaptureAffectCardPayload: Hashable, Sendable {
    var valence: Double? = nil
    var sourceDescription: String? = nil
}

struct CaptureJournalingSuggestionCardPayload: Hashable, Sendable {
    var artifactCount: Int
    var affectCount: Int
    var photoCount: Int = 0
    var videoCount: Int = 0
    var livePhotoCount: Int = 0
    var locationCount: Int = 0
    var musicCount: Int = 0
    var promptCount: Int = 0
    var thumbnailData: Data? = nil
}

struct CaptureStatusCardPayload: Hashable, Sendable {}

struct CaptureCardItem: Identifiable, Hashable, Sendable {
    let id: String
    var payload: CaptureCardPayload
    var origin: CaptureArtifactOrigin?
    var provenance: CaptureProvenance?
    var state: CaptureCardState
    var title: String?
    var detail: String
    var metadata: String?
    var isSelected: Bool
    var isRemovable: Bool

    var kind: CaptureCardKind {
        payload.kind
    }

    init(
        id: String = UUID().uuidString,
        payload: CaptureCardPayload,
        origin: CaptureArtifactOrigin? = .manual,
        provenance: CaptureProvenance? = nil,
        state: CaptureCardState = .normal,
        title: String? = nil,
        detail: String,
        metadata: String? = nil,
        isSelected: Bool = false,
        isRemovable: Bool = false
    ) {
        self.id = id
        self.payload = payload
        self.provenance = provenance
        self.origin = provenance?.artifactOrigin ?? origin
        self.state = state
        self.title = title
        self.detail = detail
        self.metadata = metadata
        self.isSelected = isSelected
        self.isRemovable = isRemovable
    }
}

extension CaptureCardItem {
    var commonDisplay: CaptureCardCommonDisplay {
        CaptureCardCommonDisplay(item: self)
    }
}

struct CaptureCardCommonDisplay: Hashable, Sendable {
    let id: String
    let kind: CaptureCardKind
    let origin: CaptureArtifactOrigin?
    let provenance: CaptureProvenance?
    let state: CaptureCardState
    let title: String?
    let detail: String
    let metadata: String?
    let isSelected: Bool
    let isRemovable: Bool

    init(
        id: String,
        kind: CaptureCardKind,
        origin: CaptureArtifactOrigin?,
        provenance: CaptureProvenance?,
        state: CaptureCardState,
        title: String?,
        detail: String,
        metadata: String?,
        isSelected: Bool,
        isRemovable: Bool
    ) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.provenance = provenance
        self.state = state
        self.title = title
        self.detail = detail
        self.metadata = metadata
        self.isSelected = isSelected
        self.isRemovable = isRemovable
    }

    init(item: CaptureCardItem) {
        id = item.id
        kind = item.kind
        origin = item.origin
        provenance = item.provenance
        state = item.state
        title = item.title
        detail = item.detail
        metadata = item.metadata
        isSelected = item.isSelected
        isRemovable = item.isRemovable
    }

    func replacingDetail(_ detail: String) -> CaptureCardCommonDisplay {
        CaptureCardCommonDisplay(
            id: id,
            kind: kind,
            origin: origin,
            provenance: provenance,
            state: state,
            title: title,
            detail: detail,
            metadata: metadata,
            isSelected: isSelected,
            isRemovable: isRemovable
        )
    }
}
