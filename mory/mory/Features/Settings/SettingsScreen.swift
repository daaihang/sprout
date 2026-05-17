import AVFoundation
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
        case .privacy:
            SettingsPrivacySection(runtimeEnvironment: runtimeEnvironment)
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

private struct SettingsPermissionsSection: View {
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
        case .notDetermined: .secondary
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

private struct SettingsPrivacySection: View {
    let runtimeEnvironment: AppRuntimeEnvironment

    var body: some View {
        List {
            Section("settings.privacy.localFirst.title") {
                Text("settings.privacy.localFirst.body")
                Text("settings.privacy.ai.body")
                Text("settings.privacy.context.body")
            }

            Section("settings.privacy.deletion.title") {
                Text("settings.privacy.deletion.body")
            }

            Section("settings.privacy.debug.title") {
                Text(runtimeEnvironment.allowsDebugTools ? "settings.privacy.debug.internal" : "settings.privacy.debug.public")
            }
        }
        .navigationTitle("settings.privacy.title")
    }
}

private struct SettingsCapturePreferencesSection: View {
    let memoryRepository: any MoryMemoryRepositorying

    @State private var preference = UserSettingsPreference.defaults
    @State private var voiceLanguageChoice = "system"
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("settings.capture.link.section") {
                Toggle("settings.capture.linkAutoDetect", isOn: $preference.linkAutoDetectEnabled)
            }

            Section("settings.capture.context.section") {
                Picker("settings.capture.context.default", selection: $preference.defaultContextSelection) {
                    ForEach(UserSettingsContextSelection.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
            }

            Section("settings.capture.voice.section") {
                Picker("settings.capture.voiceLanguage", selection: $voiceLanguageChoice) {
                    Text("settings.capture.voice.system").tag("system")
                    Text("中文").tag("zh-Hans")
                    Text("English").tag("en-US")
                    Text("日本語").tag("ja-JP")
                    Text("한국어").tag("ko-KR")
                }
            }

            Section("settings.capture.insight.section") {
                Picker("settings.capture.insight.frequency", selection: $preference.insightFrequency) {
                    ForEach(UserSettingsInsightFrequency.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }

                Picker("settings.capture.tone", selection: $preference.promptTone) {
                    ForEach(UserSettingsPromptTone.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
            }

            Section {
                LabeledContent("settings.preference.updatedAt", value: preference.updatedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("settings.preference.syncKey", value: preference.syncKey)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("settings.capture.title")
        .task {
            load()
        }
        .onChange(of: preference) { _, newValue in
            save(newValue)
        }
        .onChange(of: voiceLanguageChoice) { _, newValue in
            preference.voiceLanguageIdentifier = newValue == "system" ? nil : newValue
        }
    }

    @MainActor
    private func load() {
        do {
            preference = try memoryRepository.fetchUserSettingsPreference()
            voiceLanguageChoice = preference.voiceLanguageIdentifier ?? "system"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func save(_ value: UserSettingsPreference) {
        do {
            var updated = value
            updated.updatedAt = .now
            try memoryRepository.saveUserSettingsPreference(updated)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SettingsAppearanceLanguageSection: View {
    @Environment(\.openURL) private var openURL

    let memoryRepository: any MoryMemoryRepositorying

    @State private var preference = UserSettingsPreference.defaults
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("settings.appearance.mode.section") {
                Picker("settings.appearance.mode", selection: $preference.appearanceMode) {
                    ForEach(UserSettingsAppearanceMode.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
            }

            Section("settings.language.section") {
                LabeledContent("settings.language.current", value: Locale.current.localizedString(forIdentifier: Locale.current.identifier) ?? Locale.current.identifier)
                Button("settings.language.openSettings") {
                    openSystemSettings()
                }
            }

            Section {
                LabeledContent("settings.preference.updatedAt", value: preference.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("settings.appearance.title")
        .task {
            load()
        }
        .onChange(of: preference.appearanceMode) { _, _ in
            save()
        }
    }

    @MainActor
    private func load() {
        do {
            preference = try memoryRepository.fetchUserSettingsPreference()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func save() {
        do {
            preference.updatedAt = .now
            try memoryRepository.saveUserSettingsPreference(preference)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

private struct SettingsAccountSection: View {
    let authManager: AuthSessionManager?

    @State private var diagnostics: AuthDiagnosticsSnapshot?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("settings.account.title") {
                if let diagnostics {
                    LabeledContent("settings.account.state", value: diagnostics.state)
                    LabeledContent("settings.account.userID", value: diagnostics.userID ?? String(localized: "settings.account.localUser"))
                    LabeledContent("settings.account.guest", value: diagnostics.isGuest ? String(localized: "common.yes") : String(localized: "common.no"))
                } else {
                    ProgressView()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        await authManager?.signOut()
                    }
                } label: {
                    Label("settings.account.signOut", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("settings.account.title")
        .task {
            await load()
        }
    }

    @MainActor
    private func load() async {
        guard let authManager else {
            errorMessage = String(localized: "settings.account.noManager")
            return
        }
        diagnostics = await authManager.fetchDiagnostics()
        errorMessage = nil
    }
}

private struct SettingsPlaceholderSection: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .navigationTitle(title)
    }
}
