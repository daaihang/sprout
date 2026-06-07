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
