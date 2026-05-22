import Foundation

protocol ContextAutoCollecting: Sendable {
    func collectContext(policy: UserSettingsContextSelection) async -> ContextCollectionResult
    func collectContextDrafts(policy: UserSettingsContextSelection) async -> [CaptureArtifactDraft]
}

final class ContextAutoCollector: ContextAutoCollecting, @unchecked Sendable {
    private let locationService: any ContextLocationProviding
    private let placeService: any ContextPlaceDraftProviding
    private let weatherService: any ContextWeatherProviding
    private let musicService: any ContextMusicProviding
    private let locationTimeoutSeconds: TimeInterval
    private let placeTimeoutSeconds: TimeInterval
    private let weatherTimeoutSeconds: TimeInterval
    private let musicTimeoutSeconds: TimeInterval

    init(
        locationService: any ContextLocationProviding,
        placeService: any ContextPlaceDraftProviding,
        weatherService: any ContextWeatherProviding,
        musicService: any ContextMusicProviding,
        locationTimeoutSeconds: TimeInterval = 5,
        placeTimeoutSeconds: TimeInterval = 3,
        weatherTimeoutSeconds: TimeInterval = 4,
        musicTimeoutSeconds: TimeInterval = 1
    ) {
        self.locationService = locationService
        self.placeService = placeService
        self.weatherService = weatherService
        self.musicService = musicService
        self.locationTimeoutSeconds = locationTimeoutSeconds
        self.placeTimeoutSeconds = placeTimeoutSeconds
        self.weatherTimeoutSeconds = weatherTimeoutSeconds
        self.musicTimeoutSeconds = musicTimeoutSeconds
    }

    @MainActor
    convenience init(
        locationTimeoutSeconds: TimeInterval = 5,
        placeTimeoutSeconds: TimeInterval = 3,
        weatherTimeoutSeconds: TimeInterval = 4,
        musicTimeoutSeconds: TimeInterval = 1
    ) {
        self.init(
            locationService: LocationContextService(),
            placeService: PlaceContextService(),
            weatherService: WeatherContextService(),
            musicService: MusicContextService(),
            locationTimeoutSeconds: locationTimeoutSeconds,
            placeTimeoutSeconds: placeTimeoutSeconds,
            weatherTimeoutSeconds: weatherTimeoutSeconds,
            musicTimeoutSeconds: musicTimeoutSeconds
        )
    }

    @MainActor
    convenience init(collectionTimeoutSeconds: TimeInterval) {
        self.init(
            locationTimeoutSeconds: collectionTimeoutSeconds,
            placeTimeoutSeconds: collectionTimeoutSeconds,
            weatherTimeoutSeconds: collectionTimeoutSeconds,
            musicTimeoutSeconds: min(collectionTimeoutSeconds, 1)
        )
    }

    func collectContextDrafts(policy: UserSettingsContextSelection = .allAvailable) async -> [CaptureArtifactDraft] {
        await collectContext(policy: policy).drafts
    }

    func collectContext(policy: UserSettingsContextSelection = .allAvailable) async -> ContextCollectionResult {
        let startedAt = Date()
        guard policy != .manual else {
            return .empty(
                startedAt: startedAt,
                diagnostics: [
                    .skipped(.location, message: "Automatic context is disabled.", startedAt: startedAt),
                    .skipped(.placeGeocoding, message: "Automatic context is disabled.", startedAt: startedAt),
                    .skipped(.weather, message: "Automatic context is disabled.", startedAt: startedAt),
                    .skipped(.music, message: "Automatic context is disabled.", startedAt: startedAt)
                ]
            )
        }

        async let locationResult = collectLocationWeatherContext()
        async let musicResult = collectMusicContextIfNeeded(policy: policy)

        let (locationDrafts, locationDiagnostics) = await locationResult
        let (musicDrafts, musicDiagnostics) = await musicResult
        return ContextCollectionResult(
            drafts: locationDrafts + musicDrafts,
            diagnostics: locationDiagnostics + musicDiagnostics,
            elapsedMilliseconds: max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
        )
    }

    private func collectLocationWeatherContext() async -> ([CaptureArtifactDraft], [ContextCollectionDiagnostic]) {
        let locationStartedAt = Date()
        let locationOutcome = await withTimeoutOutcome(seconds: locationTimeoutSeconds) {
            try await self.locationService.currentLocationSnapshot(timeout: self.locationTimeoutSeconds)
        }

        switch locationOutcome {
        case let .success(location):
            let locationDiagnostic = ContextCollectionDiagnostic.success(
                .location,
                message: location.coordinateSummary,
                startedAt: locationStartedAt
            )
            async let place = collectPlaceContext(location: location)
            async let weather = collectWeatherContext(location: location)
            let (placeDrafts, placeDiagnostics) = await place
            let (weatherDrafts, weatherDiagnostics) = await weather
            return (
                placeDrafts + weatherDrafts,
                [locationDiagnostic] + placeDiagnostics + weatherDiagnostics
            )
        case .timeout:
            let diagnostic = ContextCollectionDiagnostic.timeout(
                .location,
                message: ContextCollectionError.locationTimeout.localizedDescription,
                startedAt: locationStartedAt
            )
            return (
                [],
                [
                    diagnostic,
                    .skipped(.placeGeocoding, message: "Skipped because location was unavailable.", startedAt: Date()),
                    .skipped(.weather, message: "Skipped because location was unavailable.", startedAt: Date())
                ]
            )
        case let .failure(error):
            let diagnostic = ContextCollectionDiagnostic.failed(.location, error: error, startedAt: locationStartedAt)
            return (
                [],
                [
                    diagnostic,
                    .skipped(.placeGeocoding, message: "Skipped because location was unavailable.", startedAt: Date()),
                    .skipped(.weather, message: "Skipped because location was unavailable.", startedAt: Date())
                ]
            )
        }
    }

    private func collectPlaceContext(location: ContextLocationSnapshot) async -> ([CaptureArtifactDraft], [ContextCollectionDiagnostic]) {
        let startedAt = Date()
        let outcome = await withTimeoutOutcome(seconds: placeTimeoutSeconds) {
            await self.placeService.capturePlace(location: location)
        }
        switch outcome {
        case let .success(result):
            return ([result.draft.withOrigin(.context)], [result.diagnostic])
        case .timeout:
            return (
                [PlaceContextService.fallbackDraft(location: location).withOrigin(.context)],
                [.timeout(.placeGeocoding, message: "Place reverse geocoding timed out.", startedAt: startedAt)]
            )
        case let .failure(error):
            return (
                [PlaceContextService.fallbackDraft(location: location).withOrigin(.context)],
                [.failed(.placeGeocoding, error: error, startedAt: startedAt)]
            )
        }
    }

    private func collectWeatherContext(location: ContextLocationSnapshot) async -> ([CaptureArtifactDraft], [ContextCollectionDiagnostic]) {
        let startedAt = Date()
        let outcome = await withTimeoutOutcome(seconds: weatherTimeoutSeconds) {
            try await self.weatherService.captureWeather(location: location)
        }
        switch outcome {
        case let .success(draft):
            return (
                [draft.withOrigin(.context)],
                [.success(.weather, message: draft.captureSummary, startedAt: startedAt)]
            )
        case .timeout:
            return (
                [],
                [.timeout(.weather, message: "WeatherKit request timed out.", startedAt: startedAt)]
            )
        case let .failure(error):
            return (
                [],
                [.failed(.weather, error: error, startedAt: startedAt)]
            )
        }
    }

    private func collectMusicContextIfNeeded(policy: UserSettingsContextSelection) async -> ([CaptureArtifactDraft], [ContextCollectionDiagnostic]) {
        let startedAt = Date()
        guard policy == .allAvailable else {
            return (
                [],
                [.skipped(.music, message: "Music context is disabled by capture preference.", startedAt: startedAt)]
            )
        }

        let outcome = await withTimeoutOutcome(seconds: musicTimeoutSeconds) {
            await self.musicService.captureNowPlaying(origin: .context, requireActivePlayback: true)
        }
        switch outcome {
        case let .success(draft?):
            return (
                [draft],
                [.success(.music, message: draft.captureSummary, startedAt: startedAt)]
            )
        case .success(nil):
            return (
                [],
                [.skipped(.music, message: "No active now-playing music was available.", startedAt: startedAt)]
            )
        case .timeout:
            return (
                [],
                [.timeout(.music, message: "Music context request timed out.", startedAt: startedAt)]
            )
        case let .failure(error):
            return (
                [],
                [.failed(.music, error: error, startedAt: startedAt)]
            )
        }
    }
}

private enum TimedOperationOutcome<T: Sendable>: Sendable {
    case success(T)
    case timeout
    case failure(Error)
}

private func withTimeoutOutcome<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async -> TimedOperationOutcome<T> {
    await withTaskGroup(of: TimedOperationOutcome<T>.self) { group in
        group.addTask {
            do {
                return .success(try await operation())
            } catch {
                return .failure(error)
            }
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return .timeout
        }

        guard let result = await group.next() else {
            group.cancelAll()
            return .timeout
        }
        group.cancelAll()
        return result
    }
}
