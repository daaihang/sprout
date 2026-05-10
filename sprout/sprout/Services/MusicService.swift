import Foundation
import MusicKit
import UIKit
import Observation

@Observable
@MainActor
final class MusicService {
    var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    var nowPlayingData: MusicCardData? = nil

    private var pollingTask: Task<Void, Never>?

    init() {
        if authorizationStatus == .authorized {
            Task { await refreshNowPlaying() }
            startPolling()
        }
    }

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        if status == .authorized {
            await refreshNowPlaying()
            startPolling()
        }
    }

    func refreshNowPlaying() async {
        guard authorizationStatus == .authorized else { return }
        guard let entry = SystemMusicPlayer.shared.queue.currentEntry,
              case let .song(song) = entry.item else {
            nowPlayingData = nil
            return
        }
        let isPlaying = SystemMusicPlayer.shared.state.playbackStatus == .playing
        var artwork: UIImage? = nil
        if let artworkAsset = song.artwork,
           let url = artworkAsset.url(width: 300, height: 300) {
            artwork = await loadImage(from: url)
        }
        nowPlayingData = MusicCardData(
            trackName: song.title,
            artistName: song.artistName,
            albumName: song.albumTitle ?? "",
            albumArtwork: artwork,
            appleMusicURL: song.url,
            isPlaying: isPlaying
        )
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled {
                    await refreshNowPlaying()
                }
            }
        }
    }

    private func loadImage(from url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}
