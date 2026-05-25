import AVFoundation
import Foundation
import Photos
import Speech
import SwiftUI
import UIKit

struct SettingsAppearanceLanguageSection: View {
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
