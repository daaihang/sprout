import Foundation
import CoreLocation

@MainActor
final class LocationContextService: NSObject, CLLocationManagerDelegate, @unchecked Sendable, ContextLocationProviding {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var activeRequestToken: UUID?

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
        guard let snapshot = try? await currentLocationSnapshot(timeout: 5) else { return nil }
        return await PlaceContextService().capturePlace(location: snapshot).draft
    }

    func currentLocation() async -> CLLocation? {
        guard let snapshot = try? await currentLocationSnapshot(timeout: 3) else { return nil }
        return snapshot.clLocation
    }

    func currentLocationSnapshot(timeout: TimeInterval = 3) async throws -> ContextLocationSnapshot {
        guard CLLocationManager.locationServicesEnabled() else {
            throw ContextCollectionError.locationServicesDisabled
        }
        guard isAuthorized else {
            throw ContextCollectionError.locationNotAuthorized
        }
        let location = try await requestSingleLocation(timeout: timeout)
        return ContextLocationSnapshot(location: location)
    }

    private func requestSingleLocation(timeout: TimeInterval) async throws -> CLLocation {
        if let continuation = locationContinuation {
            continuation.resume(throwing: ContextCollectionError.locationFailed("A newer location request started."))
            locationContinuation = nil
            activeRequestToken = nil
        }

        let token = UUID()
        activeRequestToken = token
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.finishLocationRequest(
                    token: token,
                    result: .failure(ContextCollectionError.locationTimeout)
                )
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let location = locations.last else {
                self?.finishLocationRequest(result: .failure(ContextCollectionError.noLocation))
                return
            }
            self?.finishLocationRequest(result: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.finishLocationRequest(result: .failure(ContextCollectionError.locationFailed(error.localizedDescription)))
        }
    }

    private func finishLocationRequest(token: UUID? = nil, result: Swift.Result<CLLocation, Error>) {
        if let token, token != activeRequestToken {
            return
        }
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        activeRequestToken = nil
        continuation.resume(with: result)
    }
}
