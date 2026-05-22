import Foundation
import CoreLocation

@MainActor
final class LocationContextService: NSObject, CLLocationManagerDelegate, @unchecked Sendable, ContextLocationProviding {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var activeAuthorizationToken: UUID?
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
        try await resolveAuthorization(timeout: max(5, timeout))
        let location = try await requestSingleLocation(timeout: timeout)
        return ContextLocationSnapshot(location: location)
    }

    private func resolveAuthorization(timeout: TimeInterval) async throws {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .denied, .restricted:
            throw ContextCollectionError.locationNotAuthorized
        case .notDetermined:
            try await requestAuthorization(timeout: timeout)
        @unknown default:
            throw ContextCollectionError.locationNotAuthorized
        }
    }

    private func requestAuthorization(timeout: TimeInterval) async throws {
        if let continuation = authorizationContinuation {
            continuation.resume(throwing: ContextCollectionError.locationFailed("A newer authorization request started."))
            authorizationContinuation = nil
            activeAuthorizationToken = nil
        }

        let token = UUID()
        activeAuthorizationToken = token
        try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.finishAuthorizationRequest(
                    token: token,
                    result: .failure(ContextCollectionError.locationTimeout)
                )
            }
        }
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

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.handleAuthorizationStatusChanged()
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

    private func handleAuthorizationStatusChanged() {
        guard authorizationContinuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            finishAuthorizationRequest(result: .success(()))
        case .denied, .restricted:
            finishAuthorizationRequest(result: .failure(ContextCollectionError.locationNotAuthorized))
        case .notDetermined:
            break
        @unknown default:
            finishAuthorizationRequest(result: .failure(ContextCollectionError.locationNotAuthorized))
        }
    }

    private func finishAuthorizationRequest(token: UUID? = nil, result: Swift.Result<Void, Error>) {
        if let token, token != activeAuthorizationToken {
            return
        }
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        activeAuthorizationToken = nil
        continuation.resume(with: result)
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
