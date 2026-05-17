import AVFoundation
import Foundation
import MusicKit
import Photos
import Speech
import SwiftUI
import UIKit

enum SettingsPermissionID: String, CaseIterable, Identifiable, Sendable {
    case location
    case photos
    case microphone
    case speech
    case music
    case weather

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .location: "settings.permission.location"
        case .photos: "settings.permission.photos"
        case .microphone: "settings.permission.microphone"
        case .speech: "settings.permission.speech"
        case .music: "settings.permission.music"
        case .weather: "settings.permission.weather"
        }
    }

    var explanationKey: LocalizedStringKey {
        switch self {
        case .location: "settings.permission.location.explain"
        case .photos: "settings.permission.photos.explain"
        case .microphone: "settings.permission.microphone.explain"
        case .speech: "settings.permission.speech.explain"
        case .music: "settings.permission.music.explain"
        case .weather: "settings.permission.weather.explain"
        }
    }

    var systemImage: String {
        switch self {
        case .location: "location"
        case .photos: "photo"
        case .microphone: "mic"
        case .speech: "waveform"
        case .music: "music.note"
        case .weather: "cloud.sun"
        }
    }
}

enum SettingsPermissionStatus: String, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case limited
    case unavailable

    var titleKey: LocalizedStringKey {
        switch self {
        case .notDetermined: "settings.permission.status.notDetermined"
        case .authorized: "settings.permission.status.authorized"
        case .denied: "settings.permission.status.denied"
        case .restricted: "settings.permission.status.restricted"
        case .limited: "settings.permission.status.limited"
        case .unavailable: "settings.permission.status.unavailable"
        }
    }

    var canRequest: Bool {
        self == .notDetermined
    }

    var canOpenSettings: Bool {
        self == .denied || self == .restricted || self == .limited
    }
}

struct SettingsPermissionSnapshot: Identifiable, Hashable, Sendable {
    let id: SettingsPermissionID
    let status: SettingsPermissionStatus

    var canRequest: Bool { status.canRequest && id != .weather }
    var canOpenSettings: Bool { status.canOpenSettings }
}

enum SettingsPermissionSnapshotBuilder {
    static func make(
        locationStatus: ContextPermissionManager.Status,
        musicStatus: ContextPermissionManager.Status,
        photosStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite),
        microphoneStatus: AVAudioApplication.recordPermission = AVAudioApplication.shared.recordPermission,
        speechStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
    ) -> [SettingsPermissionSnapshot] {
        let mappedLocation = mapContextPermission(locationStatus)
        return [
            SettingsPermissionSnapshot(id: .location, status: mappedLocation),
            SettingsPermissionSnapshot(id: .photos, status: mapPhotos(photosStatus)),
            SettingsPermissionSnapshot(id: .microphone, status: mapMicrophone(microphoneStatus)),
            SettingsPermissionSnapshot(id: .speech, status: mapSpeech(speechStatus)),
            SettingsPermissionSnapshot(id: .music, status: mapContextPermission(musicStatus)),
            SettingsPermissionSnapshot(id: .weather, status: weatherStatus(locationStatus: mappedLocation))
        ]
    }

    private static func mapContextPermission(_ status: ContextPermissionManager.Status) -> SettingsPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        }
    }

    private static func mapPhotos(_ status: PHAuthorizationStatus) -> SettingsPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorized: .authorized
        case .limited: .limited
        @unknown default: .unavailable
        }
    }

    private static func mapMicrophone(_ status: AVAudioApplication.recordPermission) -> SettingsPermissionStatus {
        switch status {
        case .undetermined: .notDetermined
        case .denied: .denied
        case .granted: .authorized
        @unknown default: .unavailable
        }
    }

    private static func mapSpeech(_ status: SFSpeechRecognizerAuthorizationStatus) -> SettingsPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorized: .authorized
        @unknown default: .unavailable
        }
    }

    private static func weatherStatus(locationStatus: SettingsPermissionStatus) -> SettingsPermissionStatus {
        switch locationStatus {
        case .authorized, .limited: .authorized
        case .denied, .restricted: .unavailable
        case .notDetermined: .notDetermined
        case .unavailable: .unavailable
        }
    }
}

extension UserSettingsAppearanceMode {
    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "settings.appearance.mode.system"
        case .light: "settings.appearance.mode.light"
        case .dark: "settings.appearance.mode.dark"
        }
    }
}

extension UserSettingsContextSelection {
    var titleKey: LocalizedStringKey {
        switch self {
        case .allAvailable: "settings.capture.context.all"
        case .locationWeatherOnly: "settings.capture.context.locationWeather"
        case .manual: "settings.capture.context.manual"
        }
    }
}

extension UserSettingsInsightFrequency {
    var titleKey: LocalizedStringKey {
        switch self {
        case .low: "settings.capture.insight.low"
        case .balanced: "settings.capture.insight.balanced"
        case .high: "settings.capture.insight.high"
        }
    }
}

extension UserSettingsPromptTone {
    var titleKey: LocalizedStringKey {
        switch self {
        case .concise: "settings.capture.tone.concise"
        case .balanced: "settings.capture.tone.balanced"
        case .reflective: "settings.capture.tone.reflective"
        }
    }
}
