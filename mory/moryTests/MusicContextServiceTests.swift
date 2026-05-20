import MusicKit
import MediaPlayer
import XCTest
@testable import mory

final class MusicContextServiceTests: XCTestCase {
    func testShouldCaptureNowPlayingOnlyWhenPlaying() {
        XCTAssertTrue(MusicContextService.shouldCaptureNowPlaying(playbackStatus: MusicKit.MusicPlayer.PlaybackStatus.playing))
        XCTAssertFalse(MusicContextService.shouldCaptureNowPlaying(playbackStatus: MusicKit.MusicPlayer.PlaybackStatus.paused))
        XCTAssertFalse(MusicContextService.shouldCaptureNowPlaying(playbackStatus: MusicKit.MusicPlayer.PlaybackStatus.stopped))

        XCTAssertTrue(MusicContextService.shouldCaptureNowPlaying(playbackState: .playing))
        XCTAssertFalse(MusicContextService.shouldCaptureNowPlaying(playbackState: .paused))
        XCTAssertFalse(MusicContextService.shouldCaptureNowPlaying(playbackState: .stopped))
    }

    func testNowPlayingSnapshotDraftKeepsMusicOriginWithoutAlbumIdentifiers() {
        let snapshot = MusicNowPlayingSnapshot(
            title: "A song without identifiers",
            artistName: "Unknown Artist",
            albumTitle: "",
            durationSeconds: 181
        )

        let draft = MusicContextService.makeDraft(from: snapshot, origin: .context)

        guard case let .music(trackName, artistName, albumName, durationSeconds, artworkURL, artworkPalette, origin) = draft else {
            return XCTFail("Expected music draft.")
        }
        XCTAssertEqual(trackName, "A song without identifiers")
        XCTAssertEqual(artistName, "Unknown Artist")
        XCTAssertEqual(albumName, "")
        XCTAssertEqual(durationSeconds, 181)
        XCTAssertNil(artworkURL)
        XCTAssertNil(artworkPalette)
        XCTAssertEqual(origin, .context)
    }

    func testNowPlayingSnapshotDraftPersistsArtworkPalette() {
        let palette = MusicArtworkPalette(
            backgroundColorHex: "#123456",
            primaryTextColorHex: "#FFFFFF",
            secondaryTextColorHex: "#DDDDDD"
        )
        let snapshot = MusicNowPlayingSnapshot(
            title: "Color song",
            artistName: "Artist",
            albumTitle: "Album",
            durationSeconds: 200,
            artworkPalette: palette
        )

        let draft = MusicContextService.makeDraft(from: snapshot, origin: .manual)

        guard case let .music(_, _, _, _, _, artworkPalette, origin) = draft else {
            return XCTFail("Expected music draft.")
        }
        XCTAssertEqual(artworkPalette, palette)
        XCTAssertEqual(origin, .manual)
    }

    func testNowPlayingSnapshotRequiresTitle() {
        let snapshot = MusicNowPlayingSnapshot(
            title: "   ",
            artistName: "Unknown Artist",
            albumTitle: "Album",
            durationSeconds: 181
        )

        XCTAssertNil(MusicContextService.makeDraft(from: snapshot, origin: .manual))
    }
}
