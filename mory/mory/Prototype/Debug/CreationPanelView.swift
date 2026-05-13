import SwiftUI

struct CreationPanelView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create")
                .font(.headline)

            HStack {
                Button("New Artifact") {
                    workspace.beginArtifactDraft()
                }
                Button("New Record") {
                    workspace.beginRecordDraft()
                }
            }

            if let draftArtifact = workspace.draftArtifact {
                ArtifactDraftEditor(draft: draftArtifact)
            }

            if let draftRecord = workspace.draftRecord {
                RecordDraftEditor(draft: draftRecord)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ArtifactDraftEditor: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    let draft: Artifact

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Artifact Draft")
                .font(.subheadline.weight(.semibold))

            if let selectedRecordID = selectedRecordID,
               let record = workspace.records.first(where: { $0.id == selectedRecordID }) {
                linkedHint("Will link to selected record", detail: record.rawText)
            }

            TextField(
                "Title",
                text: Binding(
                    get: { draft.title },
                    set: { workspace.updateDraftArtifact(title: $0) }
                )
            )
            TextField(
                "Summary",
                text: Binding(
                    get: { draft.summary },
                    set: { workspace.updateDraftArtifact(summary: $0) }
                )
            )
            Picker(
                "Kind",
                selection: Binding(
                    get: { draft.kind },
                    set: { workspace.updateDraftArtifact(kind: $0) }
                )
            ) {
                ForEach(ArtifactKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            TextField(
                "Text Content",
                text: Binding(
                    get: { draft.textContent },
                    set: { workspace.updateDraftArtifact(textContent: $0) }
                ),
                axis: .vertical
            )
            HStack {
                Button("Save Artifact") {
                    if let artifactID = workspace.saveDraftArtifact(linkToRecordID: selectedRecordID) {
                        selection.route = .artifacts
                        selection.selectedEntity = .artifact(artifactID)
                    }
                }
                Button("Cancel") {
                    workspace.cancelDraftArtifact()
                }
            }
        }
    }

    private var selectedRecordID: UUID? {
        guard case let .record(recordID) = selection.selectedEntity else { return nil }
        return recordID
    }
}

private struct RecordDraftEditor: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    let draft: RecordShell

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Record Draft")
                .font(.subheadline.weight(.semibold))

            if let selectedArtifact = selectedArtifact {
                linkedHint("Will attach selected artifact", detail: selectedArtifact.title)
            }

            TextField(
                "Raw Text",
                text: Binding(
                    get: { draft.rawText },
                    set: { workspace.updateDraftRecord(rawText: $0) }
                ),
                axis: .vertical
            )
            Picker(
                "Capture Source",
                selection: Binding(
                    get: { draft.captureSource },
                    set: { workspace.updateDraftRecord(captureSource: $0) }
                )
            ) {
                ForEach(CaptureSource.allCases, id: \.rawValue) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            TextField(
                "Mood",
                text: Binding(
                    get: { draft.userMood ?? "" },
                    set: { workspace.updateDraftRecord(userMood: $0.isEmpty ? nil : $0) }
                )
            )
            Stepper(
                "Intensity: \(draft.userIntensity ?? 0)",
                value: Binding(
                    get: { draft.userIntensity ?? 0 },
                    set: { workspace.updateDraftRecord(userIntensity: $0) }
                ),
                in: 0...5
            )
            HStack {
                Button("Save Record") {
                    if let recordID = workspace.saveDraftRecord(
                        linkedArtifactIDs: selectedArtifact.map { [$0.id] } ?? []
                    ) {
                        selection.route = .records
                        selection.selectedEntity = .record(recordID)
                    }
                }
                Button("Cancel") {
                    workspace.cancelDraftRecord()
                }
            }
        }
    }

    private var selectedArtifact: Artifact? {
        guard case let .artifact(artifactID) = selection.selectedEntity else { return nil }
        return workspace.artifacts.first(where: { $0.id == artifactID })
    }
}

private func linkedHint(_ title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
}
