import Foundation
import CoreLocation

final class ContextAutoCollector: Sendable {
    private let locationService = LocationContextService()
    private let weatherService = WeatherContextService()
    private let musicService = MusicContextService()

    func requestPermissionsIfNeeded() {
        locationService.requestPermission()
    }

    /// Collects location, weather, and music drafts with timeouts.
    /// Location and weather run sequentially (weather depends on location).
    /// Music runs in parallel with location/weather.
    func collectContextDrafts() async -> [CaptureArtifactDraft] {
        await withTaskGroup(of: [CaptureArtifactDraft].self) { group in
            group.addTask { await self.collectLocationAndWeather() }
            group.addTask { await self.collectMusic() }

            var drafts: [CaptureArtifactDraft] = []
            for await results in group {
                drafts.append(contentsOf: results)
            }
            return drafts
        }
    }

    private func collectLocationAndWeather() async -> [CaptureArtifactDraft] {
        var results: [CaptureArtifactDraft] = []
        guard let locationDraft = await withTimeoutNil(seconds: 5, operation: {
            await self.locationService.captureCurrentLocation()
        }) else {
            return results
        }
        results.append(locationDraft)

        if let location = await locationService.currentLocation() {
            if let weatherDraft = await withTimeoutNil(seconds: 3, operation: {
                await self.weatherService.captureCurrentWeather(location: location)
            }) {
                results.append(weatherDraft)
            }
        }
        return results
    }

    private func collectMusic() async -> [CaptureArtifactDraft] {
        guard let music = await withTimeoutNil(seconds: 2, operation: {
            await self.musicService.captureNowPlaying()
        }) else {
            return []
        }
        return [music]
    }
}

private func withTimeoutNil<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T?) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            await operation()
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        for await result in group {
            group.cancelAll()
            return result
        }
        return nil
    }
}
