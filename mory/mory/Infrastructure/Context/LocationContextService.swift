import Foundation
import CoreLocation

final class LocationContextService: NSObject, CLLocationManagerDelegate, Sendable {
    private let manager = CLLocationManager()

    struct Result: Sendable {
        let latitude: Double
        let longitude: Double
        let placeName: String?
        let localitySummary: String
    }

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
    }

    var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestPermission() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func captureCurrentLocation() async -> CaptureArtifactDraft? {
        guard isAuthorized else { return nil }
        guard let location = await requestSingleLocation(timeout: 5) else { return nil }

        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        let pm = placemarks?.first

        let summary = [pm?.subLocality, pm?.locality, pm?.administrativeArea, pm?.country]
            .compactMap { $0 }
            .joined(separator: " ")

        return .location(
            title: pm?.name,
            summary: summary.isEmpty ? "\(location.coordinate.latitude), \(location.coordinate.longitude)" : summary,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    func currentLocation() async -> CLLocation? {
        guard isAuthorized else { return nil }
        return await requestSingleLocation(timeout: 3)
    }

    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    private func requestSingleLocation(timeout: TimeInterval) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.locationContinuation?.resume(returning: nil)
                self?.locationContinuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            locationContinuation?.resume(returning: locations.first)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}
