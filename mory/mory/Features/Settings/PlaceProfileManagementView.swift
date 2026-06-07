import SwiftUI

struct PlaceProfileManagementView: View {
    let memoryRepository: any MoryMemoryRepositorying
    var showsDebugDetails = false
    var title = "Places"

    @State private var profiles: [PlaceProfile] = []
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        List {
            if profiles.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No places",
                    systemImage: "mappin.slash",
                    description: Text("Location memories will appear here after Mory resolves them into saved places.")
                )
            } else {
                Section {
                    ForEach(profiles) { profile in
                        NavigationLink {
                            PlaceProfileDetailManagementView(
                                memoryRepository: memoryRepository,
                                profileID: profile.id,
                                showsDebugDetails: showsDebugDetails
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.displayName)
                                    .font(.headline)
                                Text("\(profile.mentionCount) mentions · \(profile.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if showsDebugDetails {
                                    Text(profile.id.uuidString)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            load()
        }
        .task {
            load()
        }
    }

    @MainActor
    private func load() {
        isLoading = true
        defer { isLoading = false }
        do {
            profiles = try memoryRepository.fetchPlaceProfiles(limit: nil)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct PlaceProfileDetailManagementView: View {
    let memoryRepository: any MoryMemoryRepositorying
    let profileID: UUID
    let showsDebugDetails: Bool

    @State private var profile: PlaceProfile?
    @State private var allProfiles: [PlaceProfile] = []
    @State private var artifacts: [Artifact] = []
    @State private var displayName = ""
    @State private var aliasesText = ""
    @State private var mergeSelection = Set<UUID>()
    @State private var splitSelection = Set<UUID>()
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        Form {
            if let profile {
                Section("Summary") {
                    LabeledContent("Name", value: profile.displayName)
                    LabeledContent("Mentions", value: "\(profile.mentionCount)")
                    LabeledContent("Artifacts", value: "\(profile.sourceArtifactIDs.count)")
                    LabeledContent("Updated", value: profile.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Rename") {
                    if showsDebugDetails {
                        DebugActionNotice(
                            .mutating,
                            message: "Saving changes updates the persistent place profile name and aliases."
                        )
                    }
                    TextField("Name", text: $displayName)
                    TextField("Aliases, separated by commas", text: $aliasesText, axis: .vertical)
                        .lineLimit(2...4)
                    Button("Save name") {
                        performRename()
                    }
                    .disabled(isWorking)
                }

                Section("Merge into this place") {
                    if showsDebugDetails {
                        DebugActionNotice(
                            .mutating,
                            message: "Merging rewrites persistent place profile links and tombstone state."
                        )
                    }
                    let candidates = allProfiles.filter { $0.id != profile.id }
                    if candidates.isEmpty {
                        Text("No other places to merge.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(candidates) { candidate in
                            Toggle(isOn: Binding(
                                get: { mergeSelection.contains(candidate.id) },
                                set: { isSelected in
                                    if isSelected {
                                        mergeSelection.insert(candidate.id)
                                    } else {
                                        mergeSelection.remove(candidate.id)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.displayName)
                                    Text("\(candidate.mentionCount) mentions")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button("Merge selected places") {
                            performMerge()
                        }
                        .disabled(isWorking || mergeSelection.isEmpty)
                    }
                }

                Section("Split selected artifacts") {
                    if showsDebugDetails {
                        DebugActionNotice(
                            .mutating,
                            message: "Splitting moves selected artifacts into a new persistent place profile."
                        )
                    }
                    if artifacts.count <= 1 {
                        Text("This place does not have enough linked location artifacts to split.")
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("New place name", text: $displayName)
                        ForEach(artifacts) { artifact in
                            Toggle(isOn: Binding(
                                get: { splitSelection.contains(artifact.id) },
                                set: { isSelected in
                                    if isSelected {
                                        splitSelection.insert(artifact.id)
                                    } else {
                                        splitSelection.remove(artifact.id)
                                    }
                                }
                            )) {
                                PlaceArtifactSummaryRow(artifact: artifact, showsDebugDetails: showsDebugDetails)
                            }
                        }
                        Button("Split selected artifacts") {
                            performSplit()
                        }
                        .disabled(isWorking || splitSelection.isEmpty)
                    }
                }

                if showsDebugDetails {
                    Section("Debug IDs") {
                        LabeledContent("Profile ID", value: profile.id.uuidString)
                        LabeledContent("Entity ID", value: profile.entityID.uuidString)
                        LabeledContent("State", value: profile.confirmationState.rawValue)
                        LabeledContent("Confidence", value: profile.confidence.map { "\($0)" } ?? "none")
                    }

                    Section("Coordinates") {
                        LabeledContent("Latitude", value: profile.centroidLatitude.map { "\($0)" } ?? "none")
                        LabeledContent("Longitude", value: profile.centroidLongitude.map { "\($0)" } ?? "none")
                        LabeledContent("Radius meters", value: "\(profile.radiusMeters)")
                    }

                    Section("Sources") {
                        Text(profile.sourceRecordIDs.map(\.uuidString).joined(separator: "\n"))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text(profile.sourceArtifactIDs.map(\.uuidString).joined(separator: "\n"))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            } else if isWorking {
                ProgressView()
            } else {
                ContentUnavailableView("Place not found", systemImage: "mappin.slash")
            }

            if let message {
                Section {
                    Text(message)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(profile?.displayName ?? "Place")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load(preferredProfileID: profileID)
        }
    }

    @MainActor
    private func load(preferredProfileID: UUID) {
        isWorking = true
        defer { isWorking = false }
        do {
            allProfiles = try memoryRepository.fetchPlaceProfiles(limit: nil)
            profile = try memoryRepository.fetchPlaceProfile(id: preferredProfileID)
            if let profile {
                artifacts = try memoryRepository.fetchPlaceProfileArtifacts(id: profile.id)
                displayName = profile.displayName
                aliasesText = profile.aliases.joined(separator: ", ")
            }
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func refreshCurrent() {
        load(preferredProfileID: profile?.id ?? profileID)
    }

    @MainActor
    private func performRename() {
        guard let profile else { return }
        do {
            _ = try memoryRepository.renamePlaceProfile(
                id: profile.id,
                displayName: displayName,
                aliases: aliasesText
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
            message = "Renamed place."
            refreshCurrent()
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func performMerge() {
        guard let profile else { return }
        do {
            _ = try memoryRepository.mergePlaceProfiles(
                primaryID: profile.id,
                mergingIDs: Array(mergeSelection),
                displayName: displayName
            )
            mergeSelection.removeAll()
            message = "Merged selected places."
            refreshCurrent()
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func performSplit() {
        guard let profile else { return }
        do {
            let newProfile = try memoryRepository.splitPlaceProfile(
                id: profile.id,
                movingArtifactIDs: Array(splitSelection),
                displayName: displayName
            )
            splitSelection.removeAll()
            message = "Created split place: \(newProfile.displayName)."
            refreshCurrent()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct PlaceArtifactSummaryRow: View {
    let artifact: Artifact
    let showsDebugDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(artifact.title)
            Text(artifact.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let coordinateText {
                Text(coordinateText)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            if showsDebugDetails {
                Text(artifact.id.uuidString)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private var coordinateText: String? {
        guard let coordinate = PlaceContextResolver.coordinate(for: artifact) else { return nil }
        return "\(coordinate.latitude), \(coordinate.longitude)"
    }
}
