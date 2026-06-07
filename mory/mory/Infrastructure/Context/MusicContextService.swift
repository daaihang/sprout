import Foundation
import CoreImage
import MediaPlayer
import MusicKit
import UIKit

struct MusicNowPlayingSnapshot: Equatable, Sendable {
    let title: String
    let artistName: String
    let albumTitle: String
    let durationSeconds: Int
    var storeID: String? = nil
    var artworkData: Data? = nil
    var artworkPalette: MusicArtworkPalette? = nil
}

struct MusicCatalogSongCandidate: Identifiable, Hashable, Sendable {
    let id: MusicItemID
    let title: String
    let artistName: String
    let albumTitle: String
    let durationSeconds: Int
    let artworkURL: String?
    let artworkPalette: MusicArtworkPalette?

    func toDraft(origin: CaptureArtifactOrigin = .manual) -> CaptureArtifactDraft {
        .music(
            trackName: title,
            artistName: artistName,
            albumName: albumTitle,
            durationSeconds: durationSeconds,
            artworkURL: artworkURL,
            artworkData: nil,
            artworkPalette: artworkPalette,
            catalogID: id.rawValue,
            storeID: id.rawValue,
            origin: origin
        )
    }
}

final class MusicContextService: Sendable, ContextMusicProviding {
    func requestAuthorizationIfNeeded() async -> MusicAuthorization.Status {
        let current = MusicAuthorization.currentStatus
        if current == .authorized {
            return current
        }
        return await MusicAuthorization.request()
    }

    func captureNowPlaying(
        origin: CaptureArtifactOrigin = .manual,
        requireActivePlayback: Bool = true
    ) async -> CaptureArtifactDraft? {
        let status = await requestAuthorizationIfNeeded()
        guard status == .authorized else { return nil }
        return Self.captureNowPlayingFromMediaPlayer(origin: origin, requireActivePlayback: requireActivePlayback)
    }

    func captureCurrentMusicItem(origin: CaptureArtifactOrigin = .manual) async -> CaptureArtifactDraft? {
        await captureNowPlaying(origin: origin, requireActivePlayback: false)
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
                    artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                    artworkPalette: Self.makeArtworkPalette(from: song.artwork)
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
            artworkData: nil,
            artworkPalette: Self.makeArtworkPalette(from: song.artwork),
            catalogID: song.id.rawValue,
            storeID: song.id.rawValue,
            origin: origin
        )
    }

    static func shouldCaptureNowPlaying(playbackStatus: MusicKit.MusicPlayer.PlaybackStatus) -> Bool {
        playbackStatus == .playing
    }

    @MainActor
    private static func captureNowPlayingFromMediaPlayer(
        origin: CaptureArtifactOrigin,
        requireActivePlayback: Bool
    ) -> CaptureArtifactDraft? {
        let player = MPMusicPlayerController.systemMusicPlayer
        guard shouldCaptureCurrentItem(playbackState: player.playbackState, requireActivePlayback: requireActivePlayback),
              let item = player.nowPlayingItem,
              let snapshot = makeSnapshot(from: item) else {
            return nil
        }
        return makeDraft(from: snapshot, origin: origin)
    }

    static func shouldCaptureNowPlaying(playbackState: MPMusicPlaybackState) -> Bool {
        playbackState == .playing
    }

    static func shouldCaptureCurrentItem(
        playbackState: MPMusicPlaybackState,
        requireActivePlayback: Bool
    ) -> Bool {
        requireActivePlayback ? shouldCaptureNowPlaying(playbackState: playbackState) : playbackState != .stopped
    }

    static func makeDraft(from snapshot: MusicNowPlayingSnapshot, origin: CaptureArtifactOrigin = .manual) -> CaptureArtifactDraft? {
        guard !snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return .music(
            trackName: snapshot.title,
            artistName: snapshot.artistName,
            albumName: snapshot.albumTitle,
            durationSeconds: snapshot.durationSeconds,
            artworkURL: nil,
            artworkData: snapshot.artworkData,
            artworkPalette: snapshot.artworkPalette,
            catalogID: snapshot.storeID,
            storeID: snapshot.storeID,
            origin: origin
        )
    }

    @MainActor
    private static func makeSnapshot(from item: MPMediaItem) -> MusicNowPlayingSnapshot? {
        let title = (item.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let artworkImage = item.artwork?.image(at: CGSize(width: 180, height: 180))
        return MusicNowPlayingSnapshot(
            title: title,
            artistName: (item.artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            albumTitle: (item.albumTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            durationSeconds: Int(item.playbackDuration),
            storeID: item.playbackStoreID.trimmedOrNil,
            artworkData: artworkImage?.jpegData(compressionQuality: 0.82),
            artworkPalette: artworkImage.flatMap(Self.makeArtworkPalette(from:))
        )
    }

    nonisolated private static func makeArtworkPalette(from artwork: Artwork?) -> MusicArtworkPalette? {
        guard let artwork else { return nil }
        let background = artwork.backgroundColor.flatMap(hexString(from:))
        let primary = artwork.primaryTextColor.flatMap(hexString(from:))
        let secondary = artwork.secondaryTextColor.flatMap(hexString(from:))
        let palette = MusicArtworkPalette(
            backgroundColorHex: background,
            primaryTextColorHex: primary ?? background.flatMap(contrastingTextHex(for:)),
            secondaryTextColorHex: secondary
        )
        return palette.isEmpty ? nil : palette
    }

    private static func makeArtworkPalette(from image: UIImage) -> MusicArtworkPalette? {
        guard let background = averageHexColor(from: image) else { return nil }
        return MusicArtworkPalette(
            backgroundColorHex: background,
            primaryTextColorHex: contrastingTextHex(for: background),
            secondaryTextColorHex: contrastingSecondaryTextHex(for: background)
        )
    }

    nonisolated private static func hexString(from color: CGColor) -> String? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        let resolvedColor = colorSpace.flatMap {
            color.converted(to: $0, intent: .defaultIntent, options: nil)
        } ?? color
        guard let components = resolvedColor.components else { return nil }

        if components.count >= 3 {
            return hexString(red: components[0], green: components[1], blue: components[2])
        }
        if components.count == 2 {
            return hexString(red: components[0], green: components[0], blue: components[0])
        }
        return nil
    }

    private static func averageHexColor(from image: UIImage) -> String? {
        guard let inputImage = CIImage(image: image) else { return nil }
        let extent = inputImage.extent
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: inputImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let outputImage = filter?.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return String(format: "#%02X%02X%02X", bitmap[0], bitmap[1], bitmap[2])
    }

    nonisolated private static func hexString(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        String(
            format: "#%02X%02X%02X",
            Int(max(0, min(1, red)) * 255),
            Int(max(0, min(1, green)) * 255),
            Int(max(0, min(1, blue)) * 255)
        )
    }

    nonisolated private static func contrastingTextHex(for backgroundHex: String) -> String {
        luminance(for: backgroundHex).map { $0 > 0.54 ? "#111111" : "#FFFFFF" } ?? "#FFFFFF"
    }

    nonisolated private static func contrastingSecondaryTextHex(for backgroundHex: String) -> String {
        luminance(for: backgroundHex).map { $0 > 0.54 ? "#333333" : "#EDEDED" } ?? "#EDEDED"
    }

    nonisolated private static func luminance(for hex: String) -> Double? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }
}
