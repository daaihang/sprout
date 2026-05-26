import Foundation

enum CaptureMusicPlaybackState: String, CaseIterable, Hashable, Sendable, Identifiable {
    case playing
    case paused
    case stopped
    case unavailable
    case searchResult

    var id: String { rawValue }

    var label: String {
        switch self {
        case .playing: return String(localized: "capture.card.music.playing")
        case .paused: return String(localized: "capture.card.music.paused")
        case .stopped: return String(localized: "capture.card.music.stopped")
        case .unavailable: return String(localized: "capture.card.music.unavailable")
        case .searchResult: return String(localized: "capture.card.music.searchResult")
        }
    }
}

enum CaptureMusicCardStyle: String, CaseIterable, Hashable, Sendable, Identifiable {
    case compactRow
    case compactTile
    case cover
    case auto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compactRow: return String(localized: "capture.card.music.style.compactRow")
        case .compactTile: return String(localized: "capture.card.music.style.compactTile")
        case .cover: return String(localized: "capture.card.music.style.cover")
        case .auto: return String(localized: "capture.card.music.style.auto")
        }
    }

    func resolved(for item: CaptureCardItem) -> CaptureMusicCardStyle {
        switch self {
        case .compactRow:
            return .compactRow
        case .compactTile:
            return .compactTile
        case .cover:
            return .cover
        case .auto:
            return .compactRow
        }
    }
}

enum CapturePlaceCardStyle: String, CaseIterable, Hashable, Sendable, Identifiable {
    case standard
    case immersive
    case auto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return String(localized: "capture.card.place.style.standard")
        case .immersive: return String(localized: "capture.card.place.style.immersive")
        case .auto: return String(localized: "capture.card.place.style.auto")
        }
    }

    func resolved(for item: CaptureCardItem) -> CapturePlaceCardStyle {
        switch self {
        case .standard:
            return .standard
        case .immersive:
            return .immersive
        case .auto:
            return .standard
        }
    }
}

enum CapturePhotoGroupStyle: String, CaseIterable, Hashable, Sendable, Identifiable {
    case mosaic
    case stack
    case carousel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mosaic: return String(localized: "capture.card.photoGroup.mosaic")
        case .stack: return String(localized: "capture.card.photoGroup.stack")
        case .carousel: return String(localized: "capture.card.photoGroup.carousel")
        }
    }
}
