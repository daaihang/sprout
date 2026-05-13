import SwiftUI

struct EntityInspectorView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    let entity: EntityNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Entity")
                    .font(.headline)
                Text(entity.displayName)
                    .font(.title3.weight(.semibold))
                LabeledContent("Kind", value: entity.kind.displayName)
                LabeledContent("Canonical", value: entity.canonicalName)
                LabeledContent("Artifacts", value: "\(linkedArtifacts.count)")
                LabeledContent("Records", value: "\(linkedRecords.count)")
                LabeledContent("Edges", value: "\(connectedEdges.count)")
                LabeledContent("Mentions", value: "\(mentionCount)")
                LabeledContent("Last Seen", value: lastSeenText)
                if !entity.summary.isEmpty {
                    Divider()
                    Text(entity.summary)
                        .font(.body)
                }
                if let confidence = entity.confidence {
                    LabeledContent("Confidence", value: confidence.formatted(.percent.precision(.fractionLength(0))))
                }

                Divider()
                sectionTitle("Recent Artifacts")
                if linkedArtifacts.isEmpty {
                    emptyCaption("No linked artifacts yet.")
                } else {
                    ForEach(linkedArtifacts.prefix(5)) { artifact in
                        Button {
                            selection.route = .artifacts
                            selection.selectedEntity = .artifact(artifact.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(artifact.title)
                                Text(artifact.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(artifact.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                sectionTitle("Recent Records")
                if linkedRecords.isEmpty {
                    emptyCaption("No linked records yet.")
                } else {
                    ForEach(linkedRecords.prefix(5)) { record in
                        Button {
                            selection.route = .records
                            selection.selectedEntity = .record(record.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.rawText)
                                    .lineLimit(2)
                                Text(record.captureSource.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                sectionTitle("Connected Edges")
                if connectedEdges.isEmpty {
                    emptyCaption("No graph edges yet.")
                } else {
                    ForEach(connectedEdges) { edge in
                        edgeRow(edge)
                    }
                }
            }
        }
    }

    private var linkedArtifacts: [Artifact] {
        workspace.linkedArtifacts(forEntityID: entity.id)
    }

    private var linkedRecords: [RecordShell] {
        workspace.linkedRecords(forEntityID: entity.id)
    }

    private var connectedEdges: [EntityEdge] {
        workspace.connectedEdges(forEntityID: entity.id)
    }

    private var mentionCount: Int {
        workspace.entityOccurrenceCount(for: entity.id)
    }

    private var lastSeenText: String {
        guard let date = workspace.entityLastSeenDate(for: entity.id) else { return "-" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func emptyCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func edgeRow(_ edge: EntityEdge) -> some View {
        if let counterpartID = workspace.counterpartEntityID(for: edge, relativeTo: entity.id),
           let counterpart = workspace.entityNode(for: counterpartID) {
            Button {
                selection.route = .entities
                selection.selectedEntity = .entity(counterpart.id)
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(counterpart.displayName)
                        Text(edge.relationKind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(edgeEvidenceSummary(for: edge))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("evidence \(edge.evidenceCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(edge.weight.formatted(.number.precision(.fractionLength(1))))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func edgeEvidenceSummary(for edge: EntityEdge) -> String {
        let artifacts = workspace.sharedArtifacts(for: edge)
        let records = workspace.sharedRecords(for: edge)

        let artifactSummary: String
        if artifacts.isEmpty {
            artifactSummary = "artifacts 0"
        } else {
            artifactSummary = artifacts
                .prefix(2)
                .map(\.title)
                .joined(separator: ", ")
        }

        return "\(artifactSummary) • records \(records.count)"
    }
}
