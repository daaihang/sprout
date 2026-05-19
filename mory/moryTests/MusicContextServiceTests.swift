import MusicKit
import XCTest
@testable import mory

final class MusicContextServiceTests: XCTestCase {
    func testShouldCaptureNowPlayingOnlyWhenPlaying() {
        XCTAssertTrue(MusicContextService.shouldCaptureNowPlaying(playbackStatus: .playing))
        XCTAssertFalse(MusicContextService.shouldCaptureNowPlaying(playbackStatus: .paused))
        XCTAssertFalse(MusicContextService.shouldCaptureNowPlaying(playbackStatus: .stopped))
    }
}
