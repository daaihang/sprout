import AVFoundation
import Foundation
import Photos
import Speech
import SwiftUI
import UIKit

struct SettingsCapturePreferencesSection: View {
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
