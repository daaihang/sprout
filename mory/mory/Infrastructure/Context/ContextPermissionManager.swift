import Foundation
import Combine
import CoreLocation
import MusicKit

@MainActor
final class ContextPermissionManager: ObservableObject {
    enum Status: Equatable {
        case notDetermined
        case denied
        case authorized
    }

    @Published private(set) var locationStatus: Status = .notDetermined
    @Published private(set) var musicStatus: Status = .notDetermined

    private let locationService: LocationContextService

    init(locationService: LocationContextService) {
        self.locationService = locationService
        refresh()
    }

    func refresh() {
        locationStatus = mapLocationStatus(locationService.authorizationStatus)
        musicStatus = mapMusicStatus(MusicAuthorization.currentStatus)
    }

    func requestLocationIfNeeded() async {
        if locationStatus == .notDetermined {
            locationService.requestPermission()
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        refresh()
    }

    func requestMusicIfNeeded() async {
        if musicStatus == .notDetermined {
            _ = await MusicAuthorization.request()
        }
        refresh()
    }

    var anyMissing: Bool {
        locationStatus != .authorized || musicStatus != .authorized
    }

    private func mapLocationStatus(_ status: CLAuthorizationStatus) -> Status {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted, .denied: return .denied
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        @unknown default: return .notDetermined
        }
    }

    private func mapMusicStatus(_ status: MusicAuthorization.Status) -> Status {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        case .authorized: return .authorized
        @unknown default: return .notDetermined
        }
    }
}
