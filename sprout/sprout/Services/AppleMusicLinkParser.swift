import Foundation
import MusicKit
import UIKit

enum AppleMusicLinkType {
    case song(id: String)
    case album(id: String)
    case artist(id: String)
    case playlist(id: String)
    case unknown
}

struct ParsedMusicItem {
    var id: String
    var linkType: AppleMusicLinkType
    var title: String
    var artistName: String
    var albumName: String?
    var artworkURL: URL?
    var appleMusicURL: URL?
}

final class AppleMusicLinkParser {
    static let shared = AppleMusicLinkParser()

    private init() {}

    func parse(url: URL) -> ParsedMusicItem? {
        let urlString = url.absoluteString.lowercased()

        guard urlString.contains("music.apple.com") else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pathComponents = components?.path.split(separator: "/").map(String.init) ?? []

        guard pathComponents.count >= 2 else { return nil }

        let type = pathComponents[0]
        let id = pathComponents[1]

        let linkType: AppleMusicLinkType
        switch type {
        case "song": linkType = .song(id: id)
        case "album": linkType = .album(id: id)
        case "artist": linkType = .artist(id: id)
        case "playlist": linkType = .playlist(id: id)
        default: linkType = .unknown
        }

        return ParsedMusicItem(
            id: id,
            linkType: linkType,
            title: "",
            artistName: "",
            albumName: nil,
            artworkURL: nil,
            appleMusicURL: url
        )
    }

    func isAppleMusicURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        let urlString = url.absoluteString.lowercased()
        return urlString.contains("music.apple.com")
    }

    @MainActor
    func fetchSongDetails(from url: URL) async throws -> MusicCardData {
        guard let parsed = parse(url: url) else {
            throw NSError(domain: "AppleMusicLinkParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple Music URL"])
        }

        switch parsed.linkType {
        case .song(let id):
            return try await fetchSongByID(id)
        case .album(let id):
            return try await fetchAlbumByID(id)
        default:
            throw NSError(domain: "AppleMusicLinkParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unsupported link type"])
        }
    }

    @MainActor
    private func fetchSongByID(_ id: String) async throws -> MusicCardData {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
        let response = try await request.response()

        guard let song = response.items.first else {
            throw NSError(domain: "AppleMusicLinkParser", code: 3, userInfo: [NSLocalizedDescriptionKey: "Song not found"])
        }

        var artwork: UIImage?
        if let artworkAsset = song.artwork {
            let size = CGSize(width: 300, height: 300)
            if let url = artworkAsset.url(width: Int(size.width), height: Int(size.height)) {
                artwork = await loadImage(from: url)
            }
        }

        return MusicCardData(
            trackName: song.title,
            artistName: song.artistName,
            albumName: song.albumTitle ?? "",
            albumArtwork: artwork,
            appleMusicURL: song.url,
            isPlaying: false
        )
    }

    @MainActor
    private func fetchAlbumByID(_ id: String) async throws -> MusicCardData {
        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: MusicItemID(id))
        let response = try await request.response()

        guard let album = response.items.first else {
            throw NSError(domain: "AppleMusicLinkParser", code: 4, userInfo: [NSLocalizedDescriptionKey: "Album not found"])
        }

        var artwork: UIImage?
        if let artworkAsset = album.artwork {
            let size = CGSize(width: 300, height: 300)
            if let url = artworkAsset.url(width: Int(size.width), height: Int(size.height)) {
                artwork = await loadImage(from: url)
            }
        }

        let artistName = album.artistName

        return MusicCardData(
            trackName: album.title,
            artistName: artistName,
            albumName: album.title,
            albumArtwork: artwork,
            appleMusicURL: album.url,
            isPlaying: false
        )
    }

    @MainActor
    private func loadImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}