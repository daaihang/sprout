import AVFoundation
import Foundation
import Photos
import Speech
import SwiftUI
import UIKit

struct SettingsNotificationPreferencesSection: View {
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
