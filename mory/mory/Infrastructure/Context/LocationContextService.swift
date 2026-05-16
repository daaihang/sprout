import Foundation
import CoreLocation
import MapKit

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

        let mapItem = try? await MKReverseGeocodingRequest(location: location)?.mapItems.first
        let formattedAddress = mapItem?.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
        let localitySummary = formattedAddress
            ?? mapItem?.addressRepresentations?.cityWithContext(.full)
            ?? mapItem?.address?.shortAddress
            ?? mapItem?.address?.fullAddress

        return .location(
            title: mapItem?.name,
            summary: localitySummary?.trimmedOrNil ?? String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude),
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
