#if DEBUG
import SwiftUI
import SwiftData
import Photos
import AVFoundation
import Speech

struct DebugPermissionMatrixView: View {
    @StateObject private var permissionManager = ContextPermissionManager(locationService: LocationContextService())
    @State private var rows: [DebugPermissionRow] = []
    @State private var isTestingWeather = false
    @State private var weatherStatus = String(localized: "debug.permission.weather.notTested")

    var body: some View {
        List {
            Section {
                Button {
                    refreshRows()
                } label: {
                    Label("debug.permission.refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    Task { await requestPhotos() }
                } label: {
                    Label("debug.permission.request.photos", systemImage: "photo")
                }

                Button {
                    Task { await requestMicrophone() }
                } label: {
                    Label("debug.permission.request.microphone", systemImage: "mic")
                }

                Button {
                    Task { await requestSpeech() }
                } label: {
                    Label("debug.permission.request.speech", systemImage: "waveform")
                }

                Button {
                    Task {
                        await permissionManager.requestLocationIfNeeded()
                        refreshRows()
                    }
                } label: {
                    Label("debug.permission.request.location", systemImage: "location")
                }

                Button {
                    Task {
                        await permissionManager.requestMusicIfNeeded()
                        refreshRows()
                    }
                } label: {
                    Label("debug.permission.request.music", systemImage: "music.note")
                }

                Button {
                    Task { await testWeatherKit() }
                } label: {
                    Label(isTestingWeather ? String(localized: "debug.permission.weather.testing") : String(localized: "debug.permission.weather.test"), systemImage: "cloud.sun")
                }
                .disabled(isTestingWeather)
            } footer: {
                Text("debug.permission.footer")
            }

            Section("debug.permission.matrix") {
                ForEach(rows) { row in
                    DebugCapabilityChecklistRow(title: row.title, detail: row.detail)
                }
                DebugCapabilityChecklistRow(title: String(localized: "debug.permission.weather"), detail: weatherStatus)
            }
        }
        .navigationTitle("debug.capability.permissions")
        .task {
            refreshRows()
        }
    }

    @MainActor
    private func refreshRows() {
        permissionManager.refresh()
        rows = [
            DebugPermissionRow(title: String(localized: "debug.permission.photos"), detail: photosStatusText()),
            DebugPermissionRow(title: String(localized: "debug.permission.microphone"), detail: microphoneStatusText()),
            DebugPermissionRow(title: String(localized: "debug.permission.speech"), detail: speechStatusText()),
            DebugPermissionRow(title: String(localized: "debug.permission.location"), detail: permissionLabel(permissionManager.locationStatus)),
            DebugPermissionRow(title: String(localized: "debug.permission.music"), detail: permissionLabel(permissionManager.musicStatus))
        ]
    }

    @MainActor
    private func requestPhotos() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        refreshRows()
    }

    @MainActor
    private func requestMicrophone() async {
        _ = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        refreshRows()
    }

    @MainActor
    private func requestSpeech() async {
        _ = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        refreshRows()
    }

    @MainActor
    private func testWeatherKit() async {
        isTestingWeather = true
        weatherStatus = String(localized: "debug.permission.weather.testing")
        defer { isTestingWeather = false }

        let locationService = LocationContextService()
        guard locationService.isAuthorized else {
            weatherStatus = String(localized: "debug.permission.weather.locationRequired")
            return
        }
        let location: ContextLocationSnapshot
        do {
            location = try await locationService.currentLocationSnapshot(timeout: 5)
        } catch {
            weatherStatus = "\(String(localized: "debug.permission.weather.noLocation"))\n\(error.localizedDescription)"
            return
        }

        let placeStartedAt = Date()
        let place = await PlaceContextService().capturePlace(location: location)
        let placeElapsed = Int(Date().timeIntervalSince(placeStartedAt) * 1_000)
        let placeLine = [
            "Place: \(place.draft.captureSummary)",
            "\(place.diagnostic.status.rawValue) · \(placeElapsed)ms · \(place.diagnostic.message)"
        ].joined(separator: "\n")

        do {
            let startedAt = Date()
            let draft = try await WeatherContextService().captureWeather(location: location)
            let elapsed = Int(Date().timeIntervalSince(startedAt) * 1_000)
            weatherStatus = [
                "Location: \(location.coordinateSummary)",
                placeLine,
                "Weather: \(draft.captureSummary)\nsuccess · \(elapsed)ms"
            ].joined(separator: "\n")
        } catch {
            weatherStatus = [
                "Location: \(location.coordinateSummary)",
                placeLine,
                "\(String(localized: "debug.permission.weather.failed"))\n\(error.localizedDescription)"
            ].joined(separator: "\n")
        }
    }

    private func photosStatusText() -> String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: String(localized: "debug.value.notDetermined")
        case .restricted: String(localized: "debug.value.restricted")
        case .denied: String(localized: "debug.value.denied")
        case .authorized: String(localized: "debug.value.authorized")
        case .limited: String(localized: "debug.value.limited")
        @unknown default: String(localized: "debug.value.unknown")
        }
    }

    private func microphoneStatusText() -> String {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: String(localized: "debug.value.notDetermined")
        case .denied: String(localized: "debug.value.denied")
        case .granted: String(localized: "debug.value.authorized")
        @unknown default: String(localized: "debug.value.unknown")
        }
    }

    private func speechStatusText() -> String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: String(localized: "debug.value.notDetermined")
        case .denied: String(localized: "debug.value.denied")
        case .restricted: String(localized: "debug.value.restricted")
        case .authorized: String(localized: "debug.value.authorized")
        @unknown default: String(localized: "debug.value.unknown")
        }
    }

    private func permissionLabel(_ status: ContextPermissionManager.Status) -> String {
        switch status {
        case .notDetermined: String(localized: "debug.value.notDetermined")
        case .denied: String(localized: "debug.value.denied")
        case .authorized: String(localized: "debug.value.authorized")
        }
    }
}
#endif
