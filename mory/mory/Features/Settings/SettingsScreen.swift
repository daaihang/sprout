import AVFoundation
import Foundation
import Photos
import Speech
import SwiftUI
import UIKit

struct SettingsScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SettingsRoute.visibleRoutes(allowsDebugTools: runtimeEnvironment.allowsDebugTools)) { route in
                        NavigationLink {
                            destination(for: route)
                        } label: {
                            MoryHubRow(
                                title: LocalizedStringKey(route.titleKey),
                                subtitle: LocalizedStringKey(route.subtitleKey),
                                systemImage: route.systemImage
                            )
                        }
                    }
                }

                Section("settings.runtime.section") {
                    LabeledContent("settings.runtime.environment", value: runtimeEnvironment.label)
                    LabeledContent("settings.runtime.version", value: "\(runtimeEnvironment.version) (\(runtimeEnvironment.buildNumber))")
                }

            }
            .navigationTitle("settings.nav.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: SettingsRoute) -> some View {
        switch route {
        case .account:
            SettingsAccountSection(authManager: authManager)
        case .permissions:
            SettingsPermissionsSection()
        case .notifications:
            SettingsNotificationPreferencesSection(memoryRepository: memoryRepository)
        case .memoryIntelligence:
            MemoryIntelligenceSettingsView()
        case .places:
            PlaceProfileManagementView(memoryRepository: memoryRepository)
        case .privacy:
            SettingsPrivacySection(runtimeEnvironment: runtimeEnvironment)
        case .dataControls:
            SettingsDataControlsSection(memoryRepository: memoryRepository)
        case .capturePreferences:
            SettingsCapturePreferencesSection(memoryRepository: memoryRepository)
        case .appearanceLanguage:
            SettingsAppearanceLanguageSection(memoryRepository: memoryRepository)
        case .diagnostics:
            if runtimeEnvironment.allowsDebugTools {
                DebugDiagnosticsView(
                    authManager: authManager,
                    runtimeEnvironment: runtimeEnvironment
                )
            } else {
                SettingsPlaceholderSection(
                    title: "settings.diagnostics.title",
                    message: "settings.diagnostics.unavailable",
                    systemImage: "stethoscope"
                )
            }
        }
    }
}

