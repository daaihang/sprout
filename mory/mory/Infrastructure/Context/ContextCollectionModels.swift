import CoreLocation
import Foundation

struct ContextLocationSnapshot: Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let timestamp: Date

    init(location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        horizontalAccuracy = location.horizontalAccuracy
        timestamp = location.timestamp
    }

    init(
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double = kCLLocationAccuracyHundredMeters,
        timestamp: Date = .now
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
    }

    var clLocation: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }

    var coordinateSummary: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}

enum ContextCollectionComponent: String, CaseIterable, Hashable, Sendable {
    case location
    case placeGeocoding
    case weather
    case music
}

enum ContextCollectionDiagnosticStatus: String, Hashable, Sendable {
    case success
    case skipped
    case timeout
    case failed
}

struct ContextCollectionDiagnostic: Identifiable, Hashable, Sendable {
    var id: ContextCollectionComponent { component }
    let component: ContextCollectionComponent
    let status: ContextCollectionDiagnosticStatus
    let message: String
    let elapsedMilliseconds: Int

    static func success(_ component: ContextCollectionComponent, message: String, startedAt: Date) -> ContextCollectionDiagnostic {
        ContextCollectionDiagnostic(component: component, status: .success, message: message, elapsedMilliseconds: elapsedMilliseconds(since: startedAt))
    }

    static func skipped(_ component: ContextCollectionComponent, message: String, startedAt: Date = .now) -> ContextCollectionDiagnostic {
        ContextCollectionDiagnostic(component: component, status: .skipped, message: message, elapsedMilliseconds: elapsedMilliseconds(since: startedAt))
    }

    static func timeout(_ component: ContextCollectionComponent, message: String, startedAt: Date) -> ContextCollectionDiagnostic {
        ContextCollectionDiagnostic(component: component, status: .timeout, message: message, elapsedMilliseconds: elapsedMilliseconds(since: startedAt))
    }

    static func failed(_ component: ContextCollectionComponent, error: Error, startedAt: Date) -> ContextCollectionDiagnostic {
        ContextCollectionDiagnostic(component: component, status: .failed, message: error.localizedDescription, elapsedMilliseconds: elapsedMilliseconds(since: startedAt))
    }

    private static func elapsedMilliseconds(since startedAt: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
    }
}

struct ContextCollectionResult: Hashable, Sendable {
    let drafts: [CaptureArtifactDraft]
    let diagnostics: [ContextCollectionDiagnostic]
    let elapsedMilliseconds: Int

    static func empty(startedAt: Date, diagnostics: [ContextCollectionDiagnostic] = []) -> ContextCollectionResult {
        ContextCollectionResult(
            drafts: [],
            diagnostics: diagnostics,
            elapsedMilliseconds: max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
        )
    }
}

enum ContextCollectionError: LocalizedError, Hashable, Sendable {
    case locationNotAuthorized
    case locationServicesDisabled
    case locationTimeout
    case locationFailed(String)
    case noLocation

    var errorDescription: String? {
        switch self {
        case .locationNotAuthorized:
            "Location authorization is required."
        case .locationServicesDisabled:
            "Location Services are disabled."
        case .locationTimeout:
            "Location request timed out."
        case let .locationFailed(message):
            "Location failed: \(message)"
        case .noLocation:
            "No location was returned."
        }
    }
}

struct PlaceContextCollection: Hashable, Sendable {
    let draft: CaptureArtifactDraft
    let diagnostic: ContextCollectionDiagnostic
}

protocol ContextLocationProviding: Sendable {
    @MainActor
    func currentLocationSnapshot(timeout: TimeInterval) async throws -> ContextLocationSnapshot
}

protocol ContextPlaceDraftProviding: Sendable {
    func capturePlace(location: ContextLocationSnapshot) async -> PlaceContextCollection
}

protocol ContextWeatherProviding: Sendable {
    func captureWeather(location: ContextLocationSnapshot) async throws -> CaptureArtifactDraft
}

protocol ContextMusicProviding: Sendable {
    func captureNowPlaying(origin: CaptureArtifactOrigin, requireActivePlayback: Bool) async -> CaptureArtifactDraft?
}
