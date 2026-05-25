import XCTest
@testable import mory

@MainActor
final class ContextAutoCollectorTests: XCTestCase {
    func testSuccessfulLocationAndWeatherUseSingleLocationSnapshot() async {
        let location = ContextLocationSnapshot(latitude: 31.2304, longitude: 121.4737)
        let locationProvider = FakeLocationProvider(result: .success(location))
        let collector = ContextAutoCollector(
            locationService: locationProvider,
            placeService: FakePlaceProvider(),
            weatherService: FakeWeatherProvider(result: .success(Self.weatherDraft(latitude: location.latitude, longitude: location.longitude))),
            musicService: FakeMusicProvider(draft: Self.musicDraft()),
            locationTimeoutSeconds: 0.5,
            placeTimeoutSeconds: 0.5,
            weatherTimeoutSeconds: 0.5,
            musicTimeoutSeconds: 0.5
        )

        let result = await collector.collectContext(policy: .allAvailable)

        XCTAssertEqual(locationProvider.requestCount, 1)
        XCTAssertEqual(result.drafts.count, 3)
        XCTAssertTrue(result.drafts.contains { draft in
            guard case let .location(_, _, latitude, longitude, _, _) = draft else { return false }
            return latitude == location.latitude && longitude == location.longitude
        })
        XCTAssertTrue(result.drafts.contains { draft in
            guard case let .weather(_, _, _, _, _, latitude, longitude, _, _, _, _, _) = draft else { return false }
            return latitude == location.latitude && longitude == location.longitude
        })
        XCTAssertEqual(result.diagnostics.first(where: { $0.component == .location })?.status, .success)
        XCTAssertEqual(result.diagnostics.first(where: { $0.component == .weather })?.status, .success)
    }

    func testWeatherFailureKeepsPlaceDraftAndDiagnostic() async {
        let location = ContextLocationSnapshot(latitude: 40.7128, longitude: -74.006)
        let collector = ContextAutoCollector(
            locationService: FakeLocationProvider(result: .success(location)),
            placeService: FakePlaceProvider(),
            weatherService: FakeWeatherProvider(result: .failure(FakeContextError.weatherUnavailable)),
            musicService: FakeMusicProvider(draft: nil),
            locationTimeoutSeconds: 0.5,
            placeTimeoutSeconds: 0.5,
            weatherTimeoutSeconds: 0.5,
            musicTimeoutSeconds: 0.5
        )

        let result = await collector.collectContext(policy: .locationWeatherOnly)

        XCTAssertTrue(result.drafts.contains { draft in
            guard case .location = draft else { return false }
            return true
        })
        XCTAssertFalse(result.drafts.contains { draft in
            guard case .weather = draft else { return false }
            return true
        })
        XCTAssertEqual(result.diagnostics.first(where: { $0.component == .weather })?.status, .failed)
        XCTAssertEqual(result.diagnostics.first(where: { $0.component == .music })?.status, .skipped)
    }

    func testLocationFailureSkipsPlaceAndWeather() async {
        let collector = ContextAutoCollector(
            locationService: FakeLocationProvider(result: .failure(ContextCollectionError.locationTimeout)),
            placeService: FakePlaceProvider(),
            weatherService: FakeWeatherProvider(result: .success(Self.weatherDraft(latitude: 0, longitude: 0))),
            musicService: FakeMusicProvider(draft: nil),
            locationTimeoutSeconds: 0.5,
            placeTimeoutSeconds: 0.5,
            weatherTimeoutSeconds: 0.5,
            musicTimeoutSeconds: 0.5
        )

        let result = await collector.collectContext(policy: .locationWeatherOnly)

        XCTAssertTrue(result.drafts.isEmpty)
        XCTAssertEqual(result.diagnostics.first(where: { $0.component == .location })?.status, .failed)
        XCTAssertEqual(result.diagnostics.first(where: { $0.component == .placeGeocoding })?.status, .skipped)
        XCTAssertEqual(result.diagnostics.first(where: { $0.component == .weather })?.status, .skipped)
    }

    func testManualPolicySkipsAllAutomaticContext() async {
        let locationProvider = FakeLocationProvider(result: .success(ContextLocationSnapshot(latitude: 1, longitude: 2)))
        let collector = ContextAutoCollector(
            locationService: locationProvider,
            placeService: FakePlaceProvider(),
            weatherService: FakeWeatherProvider(result: .success(Self.weatherDraft(latitude: 1, longitude: 2))),
            musicService: FakeMusicProvider(draft: Self.musicDraft())
        )

        let result = await collector.collectContext(policy: .manual)

        XCTAssertEqual(locationProvider.requestCount, 0)
        XCTAssertTrue(result.drafts.isEmpty)
        XCTAssertEqual(Set(result.diagnostics.map(\.status)), [.skipped])
    }

    func testLocationWeatherOnlyDoesNotCollectMusic() async {
        let musicProvider = FakeMusicProvider(draft: Self.musicDraft())
        let collector = ContextAutoCollector(
            locationService: FakeLocationProvider(result: .success(ContextLocationSnapshot(latitude: 1, longitude: 2))),
            placeService: FakePlaceProvider(),
            weatherService: FakeWeatherProvider(result: .success(Self.weatherDraft(latitude: 1, longitude: 2))),
            musicService: musicProvider
        )

        let result = await collector.collectContext(policy: .locationWeatherOnly)

        XCTAssertEqual(musicProvider.requestCount, 0)
        XCTAssertFalse(result.drafts.contains { draft in
            guard case .music = draft else { return false }
            return true
        })
        XCTAssertEqual(result.diagnostics.first(where: { $0.component == .music })?.status, .skipped)
    }

    private static func weatherDraft(latitude: Double, longitude: Double) -> CaptureArtifactDraft {
        .weather(
            condition: "Clear",
            temperatureCelsius: 22,
            humidity: 0.4,
            windSpeedKmh: 8,
            uvIndex: 3,
            latitude: latitude,
            longitude: longitude,
            conditionCode: "clear",
            symbolName: "sun.max.fill",
            isDaylight: true,
            origin: .context
        )
    }

    private static func musicDraft() -> CaptureArtifactDraft {
        .music(
            trackName: "Track",
            artistName: "Artist",
            albumName: "Album",
            durationSeconds: 180,
            artworkURL: nil,
            origin: .context
        )
    }
}

private enum FakeContextError: Error, LocalizedError {
    case weatherUnavailable

    var errorDescription: String? {
        "Weather unavailable"
    }
}

@MainActor
private final class FakeLocationProvider: ContextLocationProviding, @unchecked Sendable {
    var requestCount = 0
    let result: Result<ContextLocationSnapshot, Error>

    init(result: Result<ContextLocationSnapshot, Error>) {
        self.result = result
    }

    func currentLocationSnapshot(timeout: TimeInterval) async throws -> ContextLocationSnapshot {
        requestCount += 1
        return try result.get()
    }
}

private struct FakePlaceProvider: ContextPlaceDraftProviding {
    func capturePlace(location: ContextLocationSnapshot) async -> PlaceContextCollection {
        let draft = CaptureArtifactDraft.location(
            title: "Place",
            summary: location.coordinateSummary,
            latitude: location.latitude,
            longitude: location.longitude,
            origin: .context
        )
        return PlaceContextCollection(
            draft: draft,
            diagnostic: .success(.placeGeocoding, message: "Place", startedAt: .now)
        )
    }
}

private struct FakeWeatherProvider: ContextWeatherProviding {
    let result: Result<CaptureArtifactDraft, Error>

    func captureWeather(location: ContextLocationSnapshot) async throws -> CaptureArtifactDraft {
        try result.get()
    }
}

@MainActor
private final class FakeMusicProvider: ContextMusicProviding, @unchecked Sendable {
    var requestCount = 0
    let draft: CaptureArtifactDraft?

    init(draft: CaptureArtifactDraft?) {
        self.draft = draft
    }

    func captureNowPlaying(origin: CaptureArtifactOrigin, requireActivePlayback: Bool) async -> CaptureArtifactDraft? {
        requestCount += 1
        return draft
    }
}
