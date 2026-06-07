import Foundation

extension CaptureCardPayload {
    var isMemoryCardMergeableMedia: Bool {
        switch self {
        case .photo, .video, .livePhoto:
            return true
        case .audio, .place, .weather, .music, .link, .todo, .prompt, .person, .affect, .journalingSuggestion, .status:
            return false
        }
    }
}
