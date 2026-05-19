import Foundation
import MusicKit

struct MusicCatalogSongCandidate: Identifiable, Hashable, Sendable {
    let id: MusicItemID
    let title: String
    let artistName: String
    let albumTitle: String
    let durationSeconds: Int
    let artworkURL: String?

    func toDraft(origin: CaptureArtifactOrigin = .manual) -> CaptureArtifactDraft {
        .music(
            trackName: title,
            artistName: artistName,
            albumName: albumTitle,
            durationSeconds: durationSeconds,
            artworkURL: artworkURL,
            origin: origin
        )
    }
}

final class MusicContextService: Sendable {
    func requestAuthorizationIfNeeded() async -> MusicAuthorization.Status {
        let current = MusicAuthorization.currentStatus
        if current == .authorized {
            return current
        }
        return await MusicAuthorization.request()
    }

    func captureNowPlaying(origin: CaptureArtifactOrigin = .manual) async -> CaptureArtifactDraft? {
        let status = await requestAuthorizationIfNeeded()
        guard status == .authorized else { return nil }
        let player = SystemMusicPlayer.shared
        guard Self.shouldCaptureNowPlaying(playbackStatus: player.state.playbackStatus) else { return nil }

        guard let entry = player.queue.currentEntry else { return nil }

        switch entry.item {
        case .song(let song):
            return makeDraft(from: song, origin: origin)
        default:
            return nil
        }
    }

    func searchSongs(query: String, limit: Int = 10) async -> [MusicCatalogSongCandidate] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        let status = await requestAuthorizationIfNeeded()
        guard status == .authorized else { return [] }

        do {
            var request = MusicCatalogSearchRequest(term: normalized, types: [Song.self])
            request.limit = limit
            let response = try await request.response()
            return response.songs.prefix(limit).map { song in
                MusicCatalogSongCandidate(
                    id: song.id,
                    title: song.title,
                    artistName: song.artistName,
                    albumTitle: song.albumTitle ?? "",
                    durationSeconds: Int(song.duration ?? 0),
                    artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString
                )
            }
        } catch {
            return []
        }
    }

    private func makeDraft(from song: Song, origin: CaptureArtifactOrigin) -> CaptureArtifactDraft {
        .music(
            trackName: song.title,
            artistName: song.artistName,
            albumName: song.albumTitle ?? "",
            durationSeconds: Int(song.duration ?? 0),
            artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
            origin: origin
        )
    }

    static func shouldCaptureNowPlaying(playbackStatus: MusicPlayer.PlaybackStatus) -> Bool {
        playbackStatus == .playing
    }
}
