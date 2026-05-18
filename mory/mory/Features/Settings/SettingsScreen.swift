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

                if runtimeEnvironment.allowsDebugTools {
                    SettingsIntelligenceDebugSection(memoryRepository: memoryRepository)
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

private struct SettingsIntelligenceDebugSection: View {
    let memoryRepository: any MoryMemoryRepositorying

    @State private var preferences = IntelligencePreferences.defaults
    @State private var flags = V6FeatureFlags.defaults
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Toggle("Local intelligence", isOn: Binding(
                get: { preferences.localIntelligenceEnabled },
                set: { newValue in
                    preferences.localIntelligenceEnabled = newValue
                    savePreferences()
                }
            ))

            Toggle("Home suggestions", isOn: Binding(
                get: { preferences.homeSuggestionsEnabled },
                set: { newValue in
                    preferences.homeSuggestionsEnabled = newValue
                    savePreferences()
                }
            ))

            Toggle("Intelligence jobs", isOn: Binding(
                get: { flags.intelligenceJobs },
                set: { newValue in
                    flags.intelligenceJobs = newValue
                    saveFlags()
                }
            ))

            Toggle("Entity profiles", isOn: Binding(
                get: { flags.entityProfiles },
                set: { newValue in
                    flags.entityProfiles = newValue
                    saveFlags()
                }
            ))

            Toggle("Clarification questions", isOn: Binding(
                get: { flags.clarificationQuestions },
                set: { newValue in
                    flags.clarificationQuestions = newValue
                    saveFlags()
                }
            ))

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("V6 Intelligence")
        } footer: {
            Text("Internal-only rollout controls for the V6 intelligence loop.")
        }
        .task {
            load()
        }
    }

    private func load() {
        do {
            preferences = try memoryRepository.fetchIntelligencePreferences()
            flags = try memoryRepository.fetchV6FeatureFlags()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePreferences() {
        do {
            preferences.updatedAt = .now
            try memoryRepository.saveIntelligencePreferences(preferences)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveFlags() {
        do {
            flags.updatedAt = .now
            try memoryRepository.saveV6FeatureFlags(flags)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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

private struct SettingsDataControlsSection: View {
    let memoryRepository: any MoryMemoryRepositorying

    @State private var exportURL: URL?
    @State private var exportSummary: String?
    @State private var isExporting = false
    @State private var isDeleting = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("settings.data.export.section") {
                Text("settings.data.export.body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await exportLocalData() }
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Label("settings.data.export.action", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting || isDeleting)

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("settings.data.export.share", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                if let exportSummary {
                    Text(exportSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("settings.data.delete.body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Label("settings.data.delete.action", systemImage: "trash")
                    }
                }
                .disabled(isDeleting || isExporting)
            } header: {
                Text("settings.data.delete.section")
            } footer: {
                Text("settings.data.delete.footer")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("settings.data.title")
        .alert("settings.data.delete.confirm.title", isPresented: $isConfirmingDelete) {
            Button("common.cancel", role: .cancel) {}
            Button("settings.data.delete.confirm.action", role: .destructive) {
                Task { await deleteLocalData() }
            }
        } message: {
            Text("settings.data.delete.confirm.message")
        }
    }

    @MainActor
    private func exportLocalData() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let snapshot = try SettingsLocalDataExportSnapshot.make(repository: memoryRepository)
            let data = try snapshot.encodedData()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mory-exports", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
            let timestamp = formatter.string(from: snapshot.exportedAt)
                .replacingOccurrences(of: ":", with: "-")
            let fileURL = directory.appendingPathComponent("mory-local-export-\(timestamp).json")
            try data.write(to: fileURL, options: [.atomic])
            exportURL = fileURL
            exportSummary = String(
                format: String(localized: "settings.data.export.summary.format"),
                snapshot.memories.count,
                snapshot.temporalArcs.count,
                snapshot.reflections.count
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteLocalData() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try memoryRepository.clearAllLocalData()
            exportURL = nil
            exportSummary = String(localized: "settings.data.delete.completed")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
    @State private var isConfirmingSignOut = false
    @State private var isSigningOut = false

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
                    isConfirmingSignOut = true
                } label: {
                    if isSigningOut {
                        ProgressView()
                    } else {
                        Label("settings.account.signOut", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                .disabled(authManager == nil || isSigningOut)
            }
        }
        .navigationTitle("settings.account.title")
        .task {
            await load()
        }
        .alert("settings.account.signOut.confirm.title", isPresented: $isConfirmingSignOut) {
            Button("common.cancel", role: .cancel) {}
            Button("settings.account.signOut", role: .destructive) {
                Task { await signOut() }
            }
        } message: {
            Text("settings.account.signOut.confirm.message")
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

    @MainActor
    private func signOut() async {
        guard let authManager else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        await authManager.signOut()
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
