import Foundation

extension Artifact {
    var isMemoryCardMergeableMedia: Bool {
        kind == .photo || kind == .video || kind == .livePhoto
    }
}

extension CaptureArtifactDraft {
    var isMemoryCardMergeableMedia: Bool {
        switch content {
        case .photo, .video, .livePhoto:
            return true
        case .text, .audio, .location, .link, .todo, .promptAnswer, .personContext, .weather, .music:
            return false
        }
    }
}
