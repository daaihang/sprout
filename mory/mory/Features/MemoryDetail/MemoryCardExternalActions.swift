import Foundation
import MapKit
import MediaPlayer
import MusicKit
import UIKit

@MainActor
enum MemoryCardExternalActions {
    static func openPlace(_ artifact: Artifact) {
        let latitude = artifact.metadata["latitude"].flatMap(Double.init)
        let longitude = artifact.metadata["longitude"].flatMap(Double.init)
        let mapItem: MKMapItem
        if let latitude, let longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        } else {
            mapItem = MKMapItem()
        }
        mapItem.name = artifact.title.trimmedOrNil ?? artifact.summary.trimmedOrNil
        mapItem.openInMaps(launchOptions: nil)
    }

    static func openLink(_ artifact: Artifact) {
        guard let urlString = artifact.metadata["url"]?.trimmedOrNil
            ?? artifact.textContent.trimmedOrNil
            ?? artifact.summary.trimmedOrNil,
            let url = URL(string: urlString)
        else { return }
        UIApplication.shared.open(url)
    }
}

@MainActor
enum MoryMusicPlaybackController {
    enum PlaybackError: LocalizedError {
        case missingPlayableID
        case authorizationDenied

        var errorDescription: String? {
            switch self {
            case .missingPlayableID:
                return String(localized: "memory.card.music.unplayable")
            case .authorizationDenied:
                return String(localized: "memory.card.music.authorizationDenied")
            }
        }
    }

    static func togglePlayback(for artifact: Artifact) async throws -> CaptureMusicPlaybackState {
        try await togglePlayback(
            catalogID: artifact.metadata["catalogID"]?.trimmedOrNil,
            storeID: artifact.metadata["storeID"]?.trimmedOrNil
        )
    }

    static func togglePlayback(for payload: CaptureMusicCardPayload) async throws -> CaptureMusicPlaybackState {
        try await togglePlayback(catalogID: payload.catalogID, storeID: payload.storeID)
    }

    static func togglePlayback(catalogID: String?, storeID: String?) async throws -> CaptureMusicPlaybackState {
        let status = MusicAuthorization.currentStatus == .authorized
            ? MusicAuthorization.currentStatus
            : await MusicAuthorization.request()
        guard status == .authorized else {
            throw PlaybackError.authorizationDenied
        }

        let playbackID = storeID?.trimmedOrNil ?? catalogID?.trimmedOrNil
        guard let playbackID else {
            throw PlaybackError.missingPlayableID
        }

        let player = MPMusicPlayerController.systemMusicPlayer
        if player.playbackState == .playing,
           player.nowPlayingItem?.playbackStoreID == playbackID {
            player.pause()
            return .paused
        }

        player.setQueue(with: [playbackID])
        player.play()
        return .playing
    }
}
