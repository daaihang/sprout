import SwiftUI

struct PersonMergeSplitView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var profiles: [PersonProfile] = []
    @State private var primaryID: UUID?
    @State private var mergingIDs = Set<UUID>()

    @State private var splitSourceID: UUID?
    @State private var splitDisplayName = ""
    @State private var splitAliasesText = ""
    @State private var splitSourceMemories: [MemorySummary] = []
    @State private var splitRecordSelection = Set<UUID>()

    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section("Merge People") {
                Picker("Primary", selection: $primaryID) {
                    Text("Select person").tag(UUID?.none)
                    ForEach(profiles) { profile in
                        Text(profile.displayName).tag(UUID?.some(profile.entityID))
                    }
                }

                let mergeCandidates = profiles.filter { profile in
                    guard let primaryID else { return false }
                    return profile.entityID != primaryID
                }
                if mergeCandidates.isEmpty {
                    Text("Select a primary person to choose merge candidates.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mergeCandidates) { profile in
                        Toggle(isOn: Binding(
                            get: { mergingIDs.contains(profile.entityID) },
                            set: { selected in
                                if selected {
                                    mergingIDs.insert(profile.entityID)
                                } else {
                                    mergingIDs.remove(profile.entityID)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.displayName)
                                Text("\(profile.sourceRecordIDs.count) memories")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button("Merge selected") {
                    performMerge()
                }
                .disabled(isWorking || primaryID == nil || mergingIDs.isEmpty)
            }

            Section("Split Person") {
                Picker("Source", selection: $splitSourceID) {
                    Text("Select person").tag(UUID?.none)
                    ForEach(profiles) { profile in
                        Text(profile.displayName).tag(UUID?.some(profile.entityID))
                    }
                }
                .onChange(of: splitSourceID) { _, newValue in
                    Task { await loadSplitMemories(entityID: newValue) }
                }

                TextField("New person name", text: $splitDisplayName)
                TextField("Aliases (comma separated)", text: $splitAliasesText)

                if splitSourceMemories.isEmpty {
                    Text("Select a source person with linked memories.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(splitSourceMemories) { memory in
                        Toggle(isOn: Binding(
                            get: { splitRecordSelection.contains(memory.record.id) },
                            set: { selected in
                                if selected {
                                    splitRecordSelection.insert(memory.record.id)
                                } else {
                                    splitRecordSelection.remove(memory.record.id)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(memory.title)
                                Text(memory.summaryText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                Button("Split selected memories") {
                    performSplit()
                }
                .disabled(isWorking || splitSourceID == nil || splitRecordSelection.isEmpty || splitDisplayName.trimmedOrNil == nil)
            }

            if let message {
                Section("Status") {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Manage People")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load()
        }
        .refreshable {
            load()
        }
    }

    @MainActor
    private func load() {
        isWorking = true
        defer { isWorking = false }
        do {
            profiles = try memoryRepository.fetchPersonProfiles(limit: nil)
                .sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending })
            if primaryID == nil {
                primaryID = profiles.first?.entityID
            }
            if splitSourceID == nil {
                splitSourceID = profiles.first?.entityID
            }
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func loadSplitMemories(entityID: UUID?) async {
        splitSourceMemories = []
        splitRecordSelection = []
        guard let entityID else { return }
        do {
            splitSourceMemories = try memoryRepository.fetchPersonDetail(entityID: entityID)?.summary.relatedMemories ?? []
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func performMerge() {
        guard let primaryID else {
            message = "Select a primary person."
            return
        }
        guard !mergingIDs.contains(primaryID) else {
            message = "Primary person cannot be merged into itself."
            return
        }
        do {
            _ = try memoryRepository.mergePersonEntities(
                primaryID: primaryID,
                mergingIDs: Array(mergingIDs),
                displayName: nil
            )
            message = "Merged \(mergingIDs.count) person(s)."
            mergingIDs = []
            load()
            Task { await loadSplitMemories(entityID: splitSourceID) }
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func performSplit() {
        guard let splitSourceID else {
            message = "Select a source person."
            return
        }
        guard let displayName = splitDisplayName.trimmedOrNil else {
            message = "New person name is required."
            return
        }
        let aliases = splitAliasesText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        do {
            let newProfile = try memoryRepository.splitPersonEntity(
                id: splitSourceID,
                movingRecordIDs: Array(splitRecordSelection),
                displayName: displayName,
                aliases: aliases
            )
            message = "Split created: \(newProfile.displayName)."
            splitDisplayName = ""
            splitAliasesText = ""
            splitRecordSelection = []
            load()
            Task { await loadSplitMemories(entityID: splitSourceID) }
        } catch {
            message = error.localizedDescription
        }
    }
}
