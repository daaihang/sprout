import Foundation

extension Artifact {
    nonisolated var isMemoryCardMergeableMedia: Bool {
        kind == .photo || kind == .video || kind == .livePhoto
    }
}

extension CaptureArtifactDraft {
    nonisolated var isMemoryCardMergeableMedia: Bool {
        switch content {
        case .photo, .video, .livePhoto:
            return true
        case .text, .audio, .location, .link, .todo, .promptAnswer, .personContext, .weather, .music:
            return false
        }
    }
}
