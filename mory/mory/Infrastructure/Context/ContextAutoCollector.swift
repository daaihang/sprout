import Foundation
import CoreLocation

protocol ContextAutoCollecting: Sendable {
    func collectContextDrafts() async -> [CaptureArtifactDraft]
}

final class ContextAutoCollector: ContextAutoCollecting {
    private let locationService = LocationContextService()
    private let weatherService = WeatherContextService()
    private let musicService = MusicContextService()
    private let collectionTimeoutSeconds: TimeInterval

    init(collectionTimeoutSeconds: TimeInterval = 3) {
        self.collectionTimeoutSeconds = collectionTimeoutSeconds
    }

    /// Collects location, weather, and music drafts without blocking capture save.
    func collectContextDrafts() async -> [CaptureArtifactDraft] {
        await withTimeoutValue(seconds: collectionTimeoutSeconds, fallback: [], operation: {
            await self.collectAvailableDrafts()
        })
    }

    private func collectAvailableDrafts() async -> [CaptureArtifactDraft] {
        await withTaskGroup(of: [CaptureArtifactDraft].self) { group in
            group.addTask { await self.collectLocationAndWeather(timeout: self.collectionTimeoutSeconds) }
            group.addTask { await self.collectMusic(timeout: min(self.collectionTimeoutSeconds, 1)) }

            var drafts: [CaptureArtifactDraft] = []
            for await results in group {
                drafts.append(contentsOf: results)
            }
            return drafts
        }
    }

    private func collectLocationAndWeather(timeout: TimeInterval) async -> [CaptureArtifactDraft] {
        var results: [CaptureArtifactDraft] = []
        guard let locationDraft = await withTimeoutNil(seconds: timeout, operation: {
            await self.locationService.captureCurrentLocation()
        }) else {
            return results
        }
        results.append(locationDraft.withOrigin(.context))

        if let location = await locationService.currentLocation() {
            if let weatherDraft = await withTimeoutNil(seconds: timeout, operation: {
                await self.weatherService.captureCurrentWeather(location: location)
            }) {
                results.append(weatherDraft.withOrigin(.context))
            }
        }
        return results
    }

    private func collectMusic(timeout: TimeInterval) async -> [CaptureArtifactDraft] {
        guard let music = await withTimeoutNil(seconds: timeout, operation: {
            await self.musicService.captureNowPlaying(origin: .context)
        }) else {
            return []
        }
        return [music]
    }
}

private func withTimeoutNil<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T?) async -> T? {
    await withTimeoutValue(seconds: seconds, fallback: nil, operation: operation)
}

private func withTimeoutValue<T: Sendable>(
    seconds: TimeInterval,
    fallback: T,
    operation: @escaping @Sendable () async -> T
) async -> T {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            await operation()
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return fallback
        }
        for await result in group {
            group.cancelAll()
            return result ?? fallback
        }
        return fallback
    }
}
