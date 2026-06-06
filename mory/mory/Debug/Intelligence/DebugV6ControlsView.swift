import SwiftUI

struct DebugV6ControlsView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var preferences: IntelligencePreferences?
    @State private var flags: V6FeatureFlags?
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button("Refresh V6 controls") {
                    refresh()
                }
                .disabled(isWorking)

                if isWorking {
                    DebugCenterProgressRow(text: "Saving V6 controls")
                }
                if let message {
                    Text(message)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("These controls are internal gates only. They do not request system permissions such as notifications.")
            }

            Section("Effective gate status") {
                if let preferences, let flags {
                    ForEach(V6DebugControls.gateDiagnostics(preferences: preferences, flags: flags)) { diagnostic in
                        DebugV6GateDiagnosticRow(diagnostic: diagnostic)
                    }
                } else {
                    DebugCenterProgressRow(text: "Loading V6 gates")
                }
            }

            Section("Bulk controls") {
                Button("Enable all V6 flags") {
                    enableAllFlags()
                }
                .disabled(flags == nil || isWorking)

                Button("Reset V6 flags to defaults") {
                    saveFlags(V6FeatureFlags.defaults, message: "Reset V6 flags to defaults.")
                }
                .disabled(isWorking)

                Button("Enable cloud-first strongest policy") {
                    enableCloudFirstStrongestPolicy()
                }
                .disabled(preferences == nil || isWorking)

                Button("Reset intelligence preferences to defaults") {
                    savePreferences(IntelligencePreferences.defaults, message: "Reset intelligence preferences to defaults.")
                }
                .disabled(isWorking)
            }

            Section {
                if preferences != nil {
                    Toggle("Local intelligence", isOn: preferenceBoolBinding(\.localIntelligenceEnabled))
                    Toggle("Cloud intelligence", isOn: preferenceBoolBinding(\.cloudIntelligenceEnabled))
                    Toggle("Voice refinement", isOn: preferenceBoolBinding(\.voiceRefinementEnabled))
                    Toggle("Semantic search", isOn: preferenceBoolBinding(\.semanticSearchEnabled))
                    Toggle("Home suggestions", isOn: preferenceBoolBinding(\.homeSuggestionsEnabled))
                    Toggle("Daily questions", isOn: preferenceBoolBinding(\.dailyQuestionsEnabled))

                    Picker("Question tone", selection: questionToneBinding) {
                        ForEach(DailyQuestionTone.allCases) { tone in
                            Text(debugControlLabel(tone.rawValue)).tag(tone)
                        }
                    }

                    Picker("Sensitive topic policy", selection: sensitiveTopicPolicyBinding) {
                        ForEach(SensitiveTopicPolicy.allCases) { policy in
                            Text(debugControlLabel(policy.rawValue)).tag(policy)
                        }
                    }
                } else {
                    DebugCenterProgressRow(text: "Loading preferences")
                }
            } header: {
                Text("Intelligence preferences")
            } footer: {
                if let preferences {
                    Text("Updated \(preferences.updatedAt.formatted(.iso8601))")
                }
            }

            Section {
                if flags != nil {
                    Toggle("intelligenceJobs", isOn: flagBoolBinding(\.intelligenceJobs))
                    Toggle("entityProfiles", isOn: flagBoolBinding(\.entityProfiles))
                    Toggle("clarificationQuestions", isOn: flagBoolBinding(\.clarificationQuestions))
                    Toggle("homeBoard", isOn: flagBoolBinding(\.homeBoard))
                    Toggle("semanticSearch", isOn: flagBoolBinding(\.semanticSearch))
                    Toggle("dailyQuestions", isOn: flagBoolBinding(\.dailyQuestions))
                    Toggle("localNotifications", isOn: flagBoolBinding(\.localNotifications))
                    Toggle("cloudQuestionSuggestions", isOn: flagBoolBinding(\.cloudQuestionSuggestions))
                    Toggle("cloudChapterSuggestions", isOn: flagBoolBinding(\.cloudChapterSuggestions))
                    Toggle("multimediaViews", isOn: flagBoolBinding(\.multimediaViews))
                    Text("Analysis is now the production pipeline; legacy Analyze controls are deprecated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    DebugCenterProgressRow(text: "Loading V6 flags")
                }
            } header: {
                Text("V6 feature flags")
            } footer: {
                if let flags {
                    Text("Updated \(flags.updatedAt.formatted(.iso8601))")
                }
            }
        }
        .navigationTitle("V6 Controls")
        .task {
            refresh()
        }
    }

    private var questionToneBinding: Binding<DailyQuestionTone> {
        Binding {
            preferences?.questionTone ?? .evidenceBased
        } set: { newValue in
            guard var updated = preferences else { return }
            updated.questionTone = newValue
            savePreferences(updated, message: "Saved question tone.")
        }
    }

    private var sensitiveTopicPolicyBinding: Binding<SensitiveTopicPolicy> {
        Binding {
            preferences?.sensitiveTopicPolicy ?? .askBeforeShowing
        } set: { newValue in
            guard var updated = preferences else { return }
            updated.sensitiveTopicPolicy = newValue
            savePreferences(updated, message: "Saved sensitive topic policy.")
        }
    }

    private func preferenceBoolBinding(_ keyPath: WritableKeyPath<IntelligencePreferences, Bool>) -> Binding<Bool> {
        Binding {
            preferences?[keyPath: keyPath] ?? false
        } set: { newValue in
            guard var updated = preferences else { return }
            updated[keyPath: keyPath] = newValue
            savePreferences(updated, message: "Saved intelligence preference.")
        }
    }

    private func flagBoolBinding(_ keyPath: WritableKeyPath<V6FeatureFlags, Bool>) -> Binding<Bool> {
        Binding {
            flags?[keyPath: keyPath] ?? false
        } set: { newValue in
            guard var updated = flags else { return }
            updated[keyPath: keyPath] = newValue
            saveFlags(updated, message: "Saved V6 feature flag.")
        }
    }

    @MainActor
    private func refresh() {
        do {
            preferences = try memoryRepository.fetchIntelligencePreferences()
            flags = try memoryRepository.fetchV6FeatureFlags()
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func savePreferences(_ updatedPreferences: IntelligencePreferences, message: String) {
        isWorking = true
        defer { isWorking = false }
        do {
            var stamped = updatedPreferences
            stamped.updatedAt = .now
            try memoryRepository.saveIntelligencePreferences(stamped)
            preferences = try memoryRepository.fetchIntelligencePreferences()
            self.message = message
        } catch {
            self.message = error.localizedDescription
        }
    }

    @MainActor
    private func saveFlags(_ updatedFlags: V6FeatureFlags, message: String) {
        isWorking = true
        defer { isWorking = false }
        do {
            var stamped = updatedFlags
            stamped.updatedAt = .now
            try memoryRepository.saveV6FeatureFlags(stamped)
            flags = try memoryRepository.fetchV6FeatureFlags()
            self.message = message
        } catch {
            self.message = error.localizedDescription
        }
    }

    @MainActor
    private func enableAllFlags() {
        guard let flags else { return }
        saveFlags(
            V6DebugControls.allFlagsEnabled(from: flags),
            message: "Enabled all V6 flags."
        )
    }

    @MainActor
    private func enableCloudFirstStrongestPolicy() {
        guard let preferences else { return }
        savePreferences(
            V6DebugControls.cloudFirstStrongestPolicy(from: preferences),
            message: "Enabled cloud-first strongest policy."
        )
    }
}
