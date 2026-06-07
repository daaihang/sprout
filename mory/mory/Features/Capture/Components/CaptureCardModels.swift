import Foundation

enum CaptureCardKind: String, CaseIterable, Hashable, Sendable {
    case photo
    case video
    case livePhoto
    case audio
    case place
    case weather
    case music
    case link
    case todo
    case prompt
    case person
    case affect
    case journalingSuggestion
    case status

    var label: String {
        switch self {
        case .photo: return String(localized: "capture.card.kind.photo")
        case .video: return String(localized: "capture.card.kind.video")
        case .livePhoto: return String(localized: "capture.card.kind.livePhoto")
        case .audio: return String(localized: "capture.card.kind.audio")
        case .place: return String(localized: "capture.card.kind.place")
        case .weather: return String(localized: "capture.card.kind.weather")
        case .music: return String(localized: "capture.card.kind.music")
        case .link: return String(localized: "capture.card.kind.link")
        case .todo: return String(localized: "capture.card.kind.todo")
        case .prompt: return String(localized: "capture.card.kind.prompt")
        case .person: return String(localized: "capture.card.kind.person")
        case .affect: return String(localized: "capture.card.kind.affect")
        case .journalingSuggestion: return String(localized: "capture.card.kind.journalingSuggestion")
        case .status: return String(localized: "capture.card.kind.status")
        }
    }

    var iconName: String {
        switch self {
        case .photo: return "photo.fill"
        case .video: return "video.fill"
        case .livePhoto: return "livephoto"
        case .audio: return "waveform"
        case .place: return "mappin.and.ellipse"
        case .weather: return "cloud.sun.fill"
        case .music: return "music.note"
        case .link: return "link"
        case .todo: return "checklist"
        case .prompt: return "questionmark.bubble"
        case .person: return "person.crop.circle"
        case .affect: return "heart.text.square"
        case .journalingSuggestion: return "sparkles.rectangle.stack.fill"
        case .status: return "hourglass"
        }
    }
}

enum CaptureCardState: String, CaseIterable, Hashable, Sendable {
    case normal
    case loading
    case error
    case disabled
}
