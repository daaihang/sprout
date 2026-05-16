import Foundation
import MusicKit

final class MusicContextService: Sendable {

    func captureNowPlaying() async -> CaptureArtifactDraft? {
        let status = await MusicAuthorization.request()
        guard status == .authorized else { return nil }

        guard let entry = SystemMusicPlayer.shared.queue.currentEntry else { return nil }

        switch entry.item {
        case .song(let song):
            return .music(
                trackName: song.title,
                artistName: song.artistName,
                albumName: song.albumTitle ?? "",
                durationSeconds: Int(song.duration ?? 0),
                artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString
            )
        default:
            return nil
        }
    }
}
