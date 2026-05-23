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

private struct SettingsNotificationPreferencesSection: View {
    @Environment(\.openURL) private var openURL

    let memoryRepository: any MoryMemoryRepositorying

    @State private var snapshot: NotificationSettingsSnapshot?
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var lastResultMessage: String?

    private let settingsService = NotificationSettingsService()

    var body: some View {
        Form {
            Section {
                LabeledContent(
                    "settings.notifications.system.status",
                    value: authorizationTitle(snapshot?.authorizationState)
                )

                if snapshot?.authorizationState == .denied {
                    Button("settings.permission.openSettings") {
                        openSystemSettings()
                    }
                } else if snapshot?.authorizationState == .notDetermined {
                    Button {
                        Task { await setGlobalEnabled(true, requestAuthorization: true) }
                    } label: {
                        Label("settings.notifications.requestPermission", systemImage: "bell")
                    }
                    .disabled(isUpdating)
                }
            } header: {
                Text("settings.notifications.system.section")
            } footer: {
                Text("settings.notifications.system.footer")
            }

            Section {
                Toggle("settings.notifications.enabled", isOn: Binding(
                    get: { notificationPreferences.enabled },
                    set: { newValue in
                        Task { await setGlobalEnabled(newValue, requestAuthorization: newValue) }
                    }
                ))
                .disabled(isUpdating || snapshot == nil)

                Toggle("settings.notifications.dailyQuestion", isOn: Binding(
                    get: { notificationPreferences.dailyQuestionEnabled },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                preferences.dailyQuestionsEnabled = newValue
                                preferences.notificationPreferences.dailyQuestionEnabled = newValue
                            }
                        }
                    }
                ))
                .disabled(!notificationPreferences.enabled || isUpdating)

                Toggle("settings.notifications.backgroundDone", isOn: Binding(
                    get: { notificationPreferences.backgroundDoneEnabled },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                preferences.notificationPreferences.backgroundDoneEnabled = newValue
                            }
                        }
                    }
                ))
                .disabled(!notificationPreferences.enabled || isUpdating)

                Toggle("settings.notifications.repeatedTheme", isOn: Binding(
                    get: { notificationPreferences.repeatedThemeEnabled },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                preferences.notificationPreferences.repeatedThemeEnabled = newValue
                            }
                        }
                    }
                ))
                .disabled(!notificationPreferences.enabled || isUpdating)

                Toggle("settings.notifications.stageForming", isOn: Binding(
                    get: { notificationPreferences.stageFormingEnabled },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                preferences.notificationPreferences.stageFormingEnabled = newValue
                            }
                        }
                    }
                ))
                .disabled(!notificationPreferences.enabled || isUpdating)

                Toggle("settings.notifications.revisit", isOn: Binding(
                    get: { notificationPreferences.revisitEnabled },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                preferences.notificationPreferences.revisitEnabled = newValue
                            }
                        }
                    }
                ))
                .disabled(!notificationPreferences.enabled || isUpdating)
            } header: {
                Text("settings.notifications.controls.section")
            }

            Section {
                Picker("Delivery pace", selection: Binding(
                    get: { notificationPreferences.resolvedFrequencyStrategy },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                preferences.notificationPreferences.frequencyStrategy = newValue
                                if newValue != .custom {
                                    preferences.notificationPreferences.maxPerDay = newValue.defaultMaxPerDay
                                    preferences.notificationPreferences.minimumMinutesBetweenNotifications = newValue.defaultMinimumMinutesBetweenNotifications
                                }
                            }
                        }
                    }
                )) {
                    ForEach(NotificationFrequencyStrategy.allCases) { strategy in
                        Text(frequencyStrategyTitle(strategy)).tag(strategy)
                    }
                }

                Stepper(maxPerDayTitle(notificationPreferences.maxPerDay), value: Binding(
                    get: { notificationPreferences.maxPerDay },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                preferences.notificationPreferences.frequencyStrategy = .custom
                                preferences.notificationPreferences.maxPerDay = newValue
                            }
                        }
                    }
                ), in: 0...8)

                Stepper(minimumIntervalTitle(notificationPreferences.resolvedMinimumMinutesBetweenNotifications), value: Binding(
                    get: { notificationPreferences.resolvedMinimumMinutesBetweenNotifications },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                preferences.notificationPreferences.frequencyStrategy = .custom
                                preferences.notificationPreferences.minimumMinutesBetweenNotifications = newValue
                            }
                        }
                    }
                ), in: 0...720, step: 30)

                Toggle("settings.notifications.richPreviews", isOn: Binding(
                    get: { notificationPreferences.richPreviewsEnabled },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                preferences.notificationPreferences.richPreviewsEnabled = newValue
                            }
                        }
                    }
                ))

                Toggle("Quiet hours", isOn: Binding(
                    get: { notificationPreferences.quietHoursStartHour != nil && notificationPreferences.quietHoursEndHour != nil },
                    set: { newValue in
                        Task {
                            await updatePreferences { preferences in
                                if newValue {
                                    preferences.notificationPreferences.quietHoursStartHour = 22
                                    preferences.notificationPreferences.quietHoursStartMinute = 0
                                    preferences.notificationPreferences.quietHoursEndHour = 8
                                    preferences.notificationPreferences.quietHoursEndMinute = 0
                                } else {
                                    preferences.notificationPreferences.quietHoursStartHour = nil
                                    preferences.notificationPreferences.quietHoursStartMinute = nil
                                    preferences.notificationPreferences.quietHoursEndHour = nil
                                    preferences.notificationPreferences.quietHoursEndMinute = nil
                                }
                            }
                        }
                    }
                ))

                if notificationPreferences.quietHoursStartHour != nil && notificationPreferences.quietHoursEndHour != nil {
                    DatePicker(
                        "Quiet start",
                        selection: quietHoursDateBinding(isStart: true),
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "Quiet end",
                        selection: quietHoursDateBinding(isStart: false),
                        displayedComponents: .hourAndMinute
                    )
                }

                LabeledContent("settings.notifications.quietHours", value: quietHoursTitle(notificationPreferences))
            } header: {
                Text("settings.notifications.frequency.section")
            } footer: {
                Text("settings.notifications.frequency.footer")
            }
            .disabled(!notificationPreferences.enabled || isUpdating)

            Section {
                LabeledContent(
                    "settings.notifications.rollout.local",
                    value: snapshot?.featureFlags.localNotifications == true ? String(localized: "common.yes") : String(localized: "common.no")
                )
                LabeledContent(
                    "settings.notifications.rollout.dailyQuestions",
                    value: snapshot?.featureFlags.dailyQuestions == true ? String(localized: "common.yes") : String(localized: "common.no")
                )
            } header: {
                Text("settings.notifications.rollout.section")
            } footer: {
                Text("settings.notifications.rollout.footer")
            }

            if let lastResultMessage {
                Section {
                    Text(lastResultMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("settings.notifications.title")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private var notificationPreferences: NotificationPreferences {
        snapshot?.preferences.notificationPreferences ?? NotificationPreferences()
    }

    @MainActor
    private func load() async {
        do {
            snapshot = try await settingsService.loadSnapshot(repository: memoryRepository)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func setGlobalEnabled(_ enabled: Bool, requestAuthorization: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        do {
            let result = try await settingsService.setNotificationsEnabled(
                enabled,
                repository: memoryRepository,
                requestSystemAuthorization: requestAuthorization
            )
            snapshot = result.snapshot
            lastResultMessage = resultSummary(result)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updatePreferences(_ mutation: @escaping (inout IntelligencePreferences) -> Void) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        do {
            let result = try await settingsService.updatePreferences(
                repository: memoryRepository,
                mutation: mutation
            )
            snapshot = result.snapshot
            lastResultMessage = resultSummary(result)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resultSummary(_ result: NotificationSettingsUpdateResult) -> String {
        if result.cancellationReport.cancelledCount > 0 {
            return String(
                format: String(localized: "settings.notifications.result.cancelled.format"),
                result.cancellationReport.cancelledCount
            )
        }
        if result.scheduleReport.scheduledCount > 0 {
            return String(
                format: String(localized: "settings.notifications.result.scheduled.format"),
                result.scheduleReport.scheduledCount
            )
        }
        if result.systemAuthorizationRequested && !result.systemAuthorizationGranted {
            return String(localized: "settings.notifications.result.permissionDenied")
        }
        return String(localized: "settings.notifications.result.saved")
    }

    private func authorizationTitle(_ state: LocalNotificationAuthorizationState?) -> String {
        guard let state else {
            return String(localized: "settings.notifications.status.loading")
        }
        switch state {
        case .notDetermined:
            return String(localized: "settings.permission.status.notDetermined")
        case .denied:
            return String(localized: "settings.permission.status.denied")
        case .authorized:
            return String(localized: "settings.permission.status.authorized")
        case .provisional:
            return String(localized: "settings.notifications.status.provisional")
        case .ephemeral:
            return String(localized: "settings.notifications.status.ephemeral")
        }
    }

    private func maxPerDayTitle(_ count: Int) -> String {
        if count == 0 {
            return String(localized: "settings.notifications.maxPerDay.none")
        }
        return String(
            format: String(localized: "settings.notifications.maxPerDay.format"),
            count
        )
    }

    private func minimumIntervalTitle(_ minutes: Int) -> String {
        if minutes == 0 {
            return "No spacing limit"
        }
        if minutes < 60 {
            return "\(minutes) min between notifications"
        }
        let hours = Double(minutes) / 60.0
        return "\(hours.formatted(.number.precision(.fractionLength(hours.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1))))h between notifications"
    }

    private func frequencyStrategyTitle(_ strategy: NotificationFrequencyStrategy) -> String {
        switch strategy {
        case .quiet:
            return "Quiet"
        case .balanced:
            return "Balanced"
        case .active:
            return "Active"
        case .custom:
            return "Custom"
        }
    }

    private func quietHoursTitle(_ preferences: NotificationPreferences) -> String {
        guard let start = preferences.quietHoursStartHour,
              let end = preferences.quietHoursEndHour else {
            return String(localized: "settings.notifications.quietHours.none")
        }
        let startMinute = preferences.quietHoursStartMinute ?? 0
        let endMinute = preferences.quietHoursEndMinute ?? 0
        return "\(twoDigit(start)):\(twoDigit(startMinute)) - \(twoDigit(end)):\(twoDigit(endMinute))"
    }

    private func quietHoursDateBinding(isStart: Bool) -> Binding<Date> {
        Binding(
            get: {
                let hour = isStart
                    ? notificationPreferences.quietHoursStartHour ?? 22
                    : notificationPreferences.quietHoursEndHour ?? 8
                let minute = isStart
                    ? notificationPreferences.quietHoursStartMinute ?? 0
                    : notificationPreferences.quietHoursEndMinute ?? 0
                return makeTimeDate(hour: hour, minute: minute)
            },
            set: { date in
                let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
                Task {
                    await updatePreferences { preferences in
                        if isStart {
                            preferences.notificationPreferences.quietHoursStartHour = components.hour ?? 22
                            preferences.notificationPreferences.quietHoursStartMinute = components.minute ?? 0
                        } else {
                            preferences.notificationPreferences.quietHoursEndHour = components.hour ?? 8
                            preferences.notificationPreferences.quietHoursEndMinute = components.minute ?? 0
                        }
                    }
                }
            }
        )
    }

    private func makeTimeDate(hour: Int, minute: Int) -> Date {
        var components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: .now)
        components.hour = hour
        components.minute = minute
        return Calendar.autoupdatingCurrent.date(from: components) ?? .now
    }

    private func twoDigit(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
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

            Section {
                Picker("Default layout", selection: $preference.detailPresentationStrategy) {
                    ForEach(MemoryDetailPresentationStrategy.userVisibleCases) { strategy in
                        Text(strategy.title).tag(strategy)
                    }
                }

                if preference.detailPresentationStrategy == .fixed {
                    Picker("Fixed mode", selection: $preference.fixedDetailPresentationMode) {
                        ForEach(MemoryDetailPresentationMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                }
            } header: {
                Text("Memory detail layout")
            } footer: {
                Text("Automatic uses local rules in this version. AI automatic is reserved for a later cloud intelligence loop.")
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
        .onChange(of: preference.detailPresentationStrategy) { _, _ in
            save()
        }
        .onChange(of: preference.fixedDetailPresentationMode) { _, _ in
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
    @Environment(\.localDataDiagnostics) private var localDataDiagnostics

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
                    LabeledContent("Local data owner", value: diagnostics.localDataOwnerID ?? "None")
                    if let localDataDiagnostics {
                        LabeledContent("Local data scope", value: localDataDiagnostics.scopeLabel)
                        LabeledContent("Local data store", value: localDataDiagnostics.storeURLDescription)
                    }
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
