import AVFoundation
import Foundation
import Photos
import Speech
import SwiftUI
import UIKit

struct SettingsPermissionsSection: View {
    @Environment(\.openURL) private var openURL

    @StateObject private var permissionManager = ContextPermissionManager(locationService: LocationContextService())
    @State private var permissions: [SettingsPermissionSnapshot] = []
    @State private var isRequesting: SettingsPermissionID?

    var body: some View {
        List {
            Section {
                ForEach(permissions) { permission in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: permission.id.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(permission.id.titleKey)
                                    .font(.headline)
                                Text(permission.id.explanationKey)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(permission.status.titleKey)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(statusColor(permission.status))
                            }
                            Spacer()
                        }

                        HStack {
                            if permission.canRequest {
                                Button {
                                    Task { await request(permission.id) }
                                } label: {
                                    if isRequesting == permission.id {
                                        ProgressView()
                                    } else {
                                        Text("settings.permission.request")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isRequesting != nil)
                            }

                            if permission.canOpenSettings {
                                Button("settings.permission.openSettings") {
                                    openSystemSettings()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("settings.permissions.footer")
            }
        }
        .navigationTitle("settings.permissions.title")
        .task {
            refresh()
        }
        .refreshable {
            refresh()
        }
    }

    @MainActor
    private func refresh() {
        permissionManager.refresh()
        permissions = SettingsPermissionSnapshotBuilder.make(
            locationStatus: permissionManager.locationStatus,
            musicStatus: permissionManager.musicStatus
        )
    }

    @MainActor
    private func request(_ permission: SettingsPermissionID) async {
        isRequesting = permission
        defer {
            isRequesting = nil
            refresh()
        }

        switch permission {
        case .location:
            await permissionManager.requestLocationIfNeeded()
        case .photos:
            _ = await requestPhotos()
        case .microphone:
            _ = await requestMicrophone()
        case .speech:
            _ = await requestSpeech()
        case .music:
            await permissionManager.requestMusicIfNeeded()
        case .weather:
            break
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func statusColor(_ status: SettingsPermissionStatus) -> Color {
        switch status {
        case .authorized, .limited: .green
        case .notDetermined, .diagnosticRequired: .secondary
        case .denied, .restricted, .unavailable: .orange
        }
    }

    private func requestPhotos() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeech() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
