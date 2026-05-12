import Foundation
import MusicKit
import Observation
import UIKit

@Observable
@MainActor
final class MusicService {
    var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    var nowPlayingData: MusicCardData? = nil

    private var pollingTask: Task<Void, Never>?
    private var isAppActive = true
    private var lifecycleObservers: [NSObjectProtocol] = []

    init() {
        registerLifecycleObservers()
        if authorizationStatus == .authorized {
            Task { await refreshNowPlaying() }
            startPollingIfNeeded()
        }
    }

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        if status == .authorized {
            await refreshNowPlaying()
            startPollingIfNeeded()
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
        var artworkURL: URL? = nil
        if let artworkAsset = song.artwork {
            artworkURL = artworkAsset.url(width: 300, height: 300)
        }
        nowPlayingData = MusicCardData(
            trackName: song.title,
            artistName: song.artistName,
            albumName: song.albumTitle ?? "",
            albumArtworkURL: artworkURL,
            appleMusicURL: song.url,
            isPlaying: isPlaying
        )
    }

    private func startPolling() {
        guard isAppActive, authorizationStatus == .authorized else { return }
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

    private func startPollingIfNeeded() {
        if isAppActive {
            startPolling()
        } else {
            pollingTask?.cancel()
            pollingTask = nil
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func registerLifecycleObservers() {
        let center = NotificationCenter.default
        lifecycleObservers.append(
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isAppActive = true
                    self?.startPollingIfNeeded()
                }
            }
        )
        lifecycleObservers.append(
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isAppActive = false
                    self?.stopPolling()
                }
            }
        )
    }
}
