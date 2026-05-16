import SwiftUI

struct MemoryDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let recordID: UUID

    @State private var snapshot: MemoryDetailSnapshot?
    @State private var errorMessage: String?
    @State private var isRefreshingPipeline = false
    @State private var isReloading = false
    @State private var isEditing = false
    @State private var draftRawText = ""
    @State private var draftMood = ""
    @State private var draftInputContext = ""
    @State private var draftArtifactText = ""
    @State private var isSavingEdits = false

    var body: some View {
        List {
            if let snapshot {
                Section("memory.section.record") {
                    LabeledContent("memory.label.source", value: snapshot.record.captureSource.rawValue)
                    if let mood = snapshot.record.userMood {
                        LabeledContent("memory.label.mood", value: mood)
                    }
                    if let inputContext = snapshot.record.inputContext {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("memory.label.context")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(inputContext)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("memory.label.rawCapture")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(snapshot.record.rawText)
                            .font(.body)
                    }
                    Text(snapshot.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("memory.section.correction") {
                    if isEditing {
                        TextField("memory.label.rawCapture", text: $draftRawText, axis: .vertical)
                            .lineLimit(3...8)
                        TextField("memory.label.mood", text: $draftMood)
                        TextField("memory.label.context", text: $draftInputContext, axis: .vertical)
                            .lineLimit(2...5)
                        TextField("memory.edit.addAttachment", text: $draftArtifactText, axis: .vertical)
                            .lineLimit(2...5)

                        Button(isSavingEdits ? String(localized: "common.saving") : String(localized: "memory.edit.saveChanges")) {
                            Task { await saveEdits() }
                        }
                        .disabled(isSavingEdits || draftRawText.trimmedOrNil == nil)

                        Button("memory.edit.cancel", role: .cancel) {
                            resetEditDraft(from: snapshot.record)
                            isEditing = false
                        }
                        .disabled(isSavingEdits)
                    } else {
                        Text("memory.edit.hint")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("memory.edit.button") {
                            resetEditDraft(from: snapshot.record)
                            isEditing = true
                        }
                    }
                }

                Section("memory.section.attachments") {
                    if snapshot.artifacts.isEmpty {
                        Text("memory.empty.attachments")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.artifacts) { artifact in
                            ArtifactRowView(artifact: artifact)
                                .padding(.vertical, 4)
                        }
                    }
                }

                Section("memory.section.analysis") {
                    if let pipelineStatus = snapshot.pipelineStatus {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pipelineStatus.userLabel)
                                .font(.headline)
                            Text(pipelineStatus.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let lastError = pipelineStatus.lastError?.trimmedOrNil {
                                Text(lastError)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if pipelineStatus.stage == .failed || pipelineStatus.stage == .pending {
                                Button(isRefreshingPipeline ? String(localized: "memory.analysis.retrying") : String(localized: "memory.analysis.retry")) {
                                    Task { await refreshPipeline() }
                                }
                                .disabled(isRefreshingPipeline)
                            }
                        }
                    }

                    if let analysis = snapshot.analysis {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(analysis.summary)
                                .font(.body)
                            if !analysis.themes.isEmpty {
                                Text(analysis.themes.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !analysis.retrievalTerms.isEmpty {
                                Text(analysis.retrievalTerms.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("memory.empty.analysis")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("common.section.entities") {
                    if snapshot.entities.isEmpty {
                        Text("common.empty.entities")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.entities) { entity in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entity.displayName)
                                    .font(.headline)
                                Text(entity.kind.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let summary = entity.summary.trimmedOrNil {
                                    Text(summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("memory.section.edges") {
                    if snapshot.edges.isEmpty {
                        Text("memory.empty.edges")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.edges.prefix(6)) { edge in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(edge.relationKind.rawValue)
                                    .font(.headline)
                                Text("memory.edge.stats \(edge.sourceRecordIDs.count) \(edge.sourceArtifactIDs.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("common.section.arcs") {
                    if snapshot.arcs.isEmpty {
                        Text("common.empty.arcs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.arcs) { arc in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(arc.title)
                                    .font(.headline)
                                Text(arc.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("common.section.reflections") {
                    if snapshot.reflections.isEmpty {
                        Text("common.empty.reflections")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.reflections) { reflection in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reflection.title)
                                    .font(.headline)
                                Text(reflection.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            } else {
                Section {
                    ProgressView()
                }
            }
        }
        .navigationTitle("memory.nav.title")
        .task(id: recordID) {
            await load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pipelineDidComplete)) { notification in
            if let id = notification.userInfo?["recordID"] as? UUID, id == recordID {
                Task { await load() }
            }
        }
    }

    @MainActor
    private func load() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }

        do {
            snapshot = try memoryRepository.fetchMemoryDetail(recordID: recordID)
            if let snapshot {
                resetEditDraft(from: snapshot.record)
            }
            errorMessage = snapshot == nil ? String(localized: "memory.error.notFound") : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPipeline() async {
        guard !isRefreshingPipeline else { return }
        isRefreshingPipeline = true
        defer { isRefreshingPipeline = false }

        do {
            try await memoryRepository.refreshMemoryPipeline(recordID: recordID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    private func resetEditDraft(from record: RecordShell) {
        draftRawText = record.rawText
        draftMood = record.userMood ?? ""
        draftInputContext = record.inputContext ?? ""
        draftArtifactText = ""
    }

    private func saveEdits() async {
        guard !isSavingEdits else { return }
        isSavingEdits = true
        defer { isSavingEdits = false }

        do {
            snapshot = try await memoryRepository.updateMemory(
                recordID: recordID,
                draft: MemoryEditDraft(
                    rawText: draftRawText,
                    userMood: draftMood.trimmedOrNil,
                    inputContext: draftInputContext.trimmedOrNil,
                    appendedArtifactText: draftArtifactText.trimmedOrNil
                )
            )
            isEditing = false
            errorMessage = nil
            try await memoryRepository.refreshMemoryPipeline(recordID: recordID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }
}

private struct ArtifactRowView: View {
    let artifact: Artifact

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconName(for: artifact.kind))
                    .foregroundStyle(iconColor(for: artifact.kind))
                Text(artifact.title)
                    .font(.headline)
                Spacer(minLength: 12)
                Text(artifact.kind.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            switch artifact.kind {
            case .weather:
                WeatherArtifactBody(metadata: artifact.metadata, fallbackSummary: artifact.summary)
            case .music:
                MusicArtifactBody(metadata: artifact.metadata, fallbackSummary: artifact.summary)
            case .location:
                LocationArtifactBody(metadata: artifact.metadata, summary: artifact.summary)
            default:
                GenericArtifactBody(artifact: artifact)
            }
        }
    }

    private func iconName(for kind: ArtifactKind) -> String {
        switch kind {
        case .text: return "text.alignleft"
        case .photo: return "photo"
        case .audio: return "waveform"
        case .music: return "music.note"
        case .link: return "link"
        case .location: return "mappin.and.ellipse"
        case .weather: return "cloud.sun"
        case .todo: return "checkmark.circle"
        case .document: return "doc.text"
        }
    }

    private func iconColor(for kind: ArtifactKind) -> Color {
        switch kind {
        case .weather: return .blue
        case .music: return .pink
        case .location: return .green
        case .photo: return .orange
        case .audio: return .purple
        default: return .secondary
        }
    }
}

private struct WeatherArtifactBody: View {
    let metadata: [String: String]
    let fallbackSummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let condition = metadata["condition"], let tempStr = metadata["temperatureCelsius"], let temp = Double(tempStr) {
                Text("\(condition) · \(String(format: "%.0f", temp))°C")
                    .font(.subheadline)
            } else if let s = fallbackSummary.trimmedOrNil {
                Text(s).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if let humStr = metadata["humidity"], let hum = Double(humStr) {
                    Label("\(String(format: "%.0f", hum * 100))%", systemImage: "humidity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let windStr = metadata["windSpeedKmh"], let wind = Double(windStr) {
                    Label("\(String(format: "%.1f", wind)) km/h", systemImage: "wind")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let uv = metadata["uvIndex"] {
                    Label("UV \(uv)", systemImage: "sun.max")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct MusicArtifactBody: View {
    let metadata: [String: String]
    let fallbackSummary: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let urlString = metadata["artworkURL"], let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.secondary.opacity(0.1)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 2) {
                if let track = metadata["trackName"], !track.isEmpty {
                    Text(track).font(.subheadline).lineLimit(1)
                }
                if let artist = metadata["artistName"], !artist.isEmpty {
                    Text(artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if let album = metadata["albumName"], !album.isEmpty {
                    Text(album).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
                if metadata["trackName"] == nil, let s = fallbackSummary.trimmedOrNil {
                    Text(s).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LocationArtifactBody: View {
    let metadata: [String: String]
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let s = summary.trimmedOrNil {
                Text(s).font(.subheadline)
            }
            if let lat = metadata["latitude"], let lon = metadata["longitude"] {
                Text("\(lat), \(lon)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct GenericArtifactBody: View {
    let artifact: Artifact

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = artifact.summary.trimmedOrNil {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let body = artifact.textContent.trimmedOrNil {
                Text(body)
                    .font(.body)
                    .lineLimit(6)
            }

            if let mediaRef = artifact.mediaRef {
                VStack(alignment: .leading, spacing: 2) {
                    Text("memory.label.media")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(mediaRef.filename) • \(mediaRef.mimeType)")
                        .font(.caption)
                }
            }

            if !artifact.metadata.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("memory.label.metadata")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(artifact.metadata.keys.sorted(), id: \.self) { key in
                        if let value = artifact.metadata[key] {
                            Text("\(key): \(value)")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
}
