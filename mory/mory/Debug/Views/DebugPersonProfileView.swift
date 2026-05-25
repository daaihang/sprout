#if DEBUG
import Foundation
import SwiftUI

struct DebugPersonProfileView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var profiles: [PersonProfile] = []
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button("Refresh person profiles") {
                    refresh()
                }
                .disabled(isWorking)

                Button("Refresh portraits for all person entities") {
                    Task { await refreshAllPortraits() }
                }
                .disabled(isWorking)

                if isWorking {
                    ProgressView("Working on person profiles")
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
                Text("Phase 3 uses local deterministic refresh. Cloud portrait proposals are part of the v7 Analyze contract phase.")
            }

            Section("Profiles") {
                if profiles.isEmpty {
                    Text("No person profiles")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(profiles) { profile in
                        DebugPersonProfileRow(profile: profile)
                    }
                }
            }
        }
        .navigationTitle("Person Profiles")
        .task {
            refresh()
        }
    }

    @MainActor
    private func refresh() {
        do {
            profiles = try memoryRepository.fetchPersonProfiles(limit: nil)
            message = "Loaded \(profiles.count) person profile(s)."
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func refreshAllPortraits() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let people = try memoryRepository.fetchEntityDetails(kind: .person, limit: nil)
            var refreshedCount = 0
            for person in people {
                if try memoryRepository.refreshPersonProfile(entityID: person.entity.id, now: .now) != nil {
                    refreshedCount += 1
                }
            }
            profiles = try memoryRepository.fetchPersonProfiles(limit: nil)
            message = "Refreshed \(refreshedCount) profile(s)."
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct DebugPersonProfileRow: View {
    let profile: PersonProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(profile.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(profile.sensitivity.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            DebugPersonProfileValue(title: "Entity", value: profile.entityID.uuidString)
            DebugPersonProfileValue(title: "Aliases", value: profile.aliases.joined(separator: ", "))
            DebugPersonProfileValue(title: "Relationship", value: profile.relationshipToUser?.rawValue ?? "none")
            DebugPersonProfileValue(title: "Importance / frequency", value: "\(profile.importanceScore.map { String(format: "%.2f", $0) } ?? "none") / \(profile.interactionFrequency.rawValue)")
            DebugPersonProfileValue(title: "Contexts", value: profile.commonContextLabels.joined(separator: ", "))
            DebugPersonProfileValue(title: "Evidence", value: "\(profile.fieldEvidence.count) field evidence item(s)")
            DebugPersonProfileValue(title: "Cloud brief", value: cloudBriefText)
            if let portrait = profile.aiPortrait {
                DebugPersonProfileBlock(title: "Portrait", content: portrait.summary)
                if !portrait.openUncertainties.isEmpty {
                    DebugPersonProfileBlock(title: "Open uncertainties", content: portrait.openUncertainties.joined(separator: "\n"))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var cloudBriefText: String {
        let brief = PersonProfileContextBrief(profile: profile, includeSensitive: false)
        return [
            "action=\(brief.cloudAction.rawValue)",
            "portrait=\(brief.portraitSummary ?? "nil")",
            "notes=\(brief.userNotes ?? "nil")",
        ].joined(separator: ", ")
    }
}

private struct DebugPersonProfileValue: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "none" : value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DebugPersonProfileBlock: View {
    var title: String
    var content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(content)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
