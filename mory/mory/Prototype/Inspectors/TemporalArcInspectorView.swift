import SwiftUI

struct TemporalArcInspectorView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    let arc: TemporalArc

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Temporal Arc")
                    .font(.headline)
                Text(arc.title)
                    .font(.title3.weight(.semibold))
                Text(arc.summary)
                    .font(.body)

                statusActions

                LabeledContent("Status", value: arc.status.rawValue)
                LabeledContent("Range", value: "\(arc.startDate.formatted(date: .abbreviated, time: .omitted)) - \(arc.endDate.formatted(date: .abbreviated, time: .omitted))")
                LabeledContent("Records", value: "\(linkedRecords.count)")
                LabeledContent("Artifacts", value: "\(linkedArtifacts.count)")
                LabeledContent("Entities", value: "\(linkedEntities.count)")
                LabeledContent("Strength", value: arc.clusterStrength.formatted(.number.precision(.fractionLength(2))))
                LabeledContent("Score", value: arc.intensityScore.formatted(.number.precision(.fractionLength(1))))
                LabeledContent("Merged From", value: "\(arc.mergedFromArcIDs.count)")
                LabeledContent("Merged Into", value: arc.mergedIntoArcID == nil ? "-" : "Linked")

                if let lastMergedAt = arc.lastMergedAt {
                    LabeledContent("Last Merged", value: lastMergedAt.formatted(date: .abbreviated, time: .shortened))
                }

                if let linkedReflection {
                    Divider()
                    sectionTitle("Phase Reflection")
                    Button {
                        selection.route = .reflections
                        selection.selectedEntity = .reflection(linkedReflection.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(linkedReflection.title)
                            Text(linkedReflection.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }

                if let mergePreview,
                   let mergeCandidate = workspace.temporalArc(for: mergePreview.candidateArcID) {
                    Divider()
                    sectionTitle("Merge Candidate")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mergeCandidate.title)
                        Text("Overlap \(mergePreview.overlapScore.formatted(.number.precision(.fractionLength(2))))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(mergeCandidate.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Button("Open Candidate") {
                                selection.route = .arcs
                                selection.selectedEntity = .arc(mergeCandidate.id)
                            }
                            .buttonStyle(.bordered)

                            Button("Merge") {
                                workspace.mergeTemporalArc(arc.id, with: mergeCandidate.id)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if !arc.mergedFromArcIDs.isEmpty {
                    Divider()
                    sectionTitle("Merged Sources")
                    ForEach(arc.mergedFromArcIDs, id: \.self) { mergedArcID in
                        if let mergedArc = workspace.temporalArc(for: mergedArcID) {
                            Button {
                                selection.route = .arcs
                                selection.selectedEntity = .arc(mergedArc.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mergedArc.title)
                                    Text(mergedArc.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let mergedIntoArcID = arc.mergedIntoArcID,
                   let mergedIntoArc = workspace.temporalArc(for: mergedIntoArcID) {
                    Divider()
                    sectionTitle("Merged Into")
                    Button {
                        selection.route = .arcs
                        selection.selectedEntity = .arc(mergedIntoArc.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mergedIntoArc.title)
                            Text(mergedIntoArc.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }

                if !arc.themeLabels.isEmpty {
                    Divider()
                    sectionTitle("Themes")
                    Text(arc.themeLabels.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !arc.entityNames.isEmpty {
                    Divider()
                    sectionTitle("Entities")
                    ForEach(linkedEntities.prefix(6)) { entity in
                        Button {
                            selection.route = .entities
                            selection.selectedEntity = .entity(entity.id)
                        } label: {
                            HStack {
                                Text(entity.displayName)
                                Spacer()
                                Text(entity.kind.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                sectionTitle("Records In Arc")
                if linkedRecords.isEmpty {
                    emptyCaption("No records linked to this arc.")
                } else {
                    ForEach(linkedRecords.prefix(6)) { record in
                        Button {
                            selection.route = .records
                            selection.selectedEntity = .record(record.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.rawText)
                                    .lineLimit(3)
                                HStack(spacing: 10) {
                                    Text(record.captureSource.rawValue)
                                    Text(record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                sectionTitle("Artifacts In Arc")
                if linkedArtifacts.isEmpty {
                    emptyCaption("No artifacts linked to this arc.")
                } else {
                    ForEach(linkedArtifacts.prefix(6)) { artifact in
                        Button {
                            selection.route = .artifacts
                            selection.selectedEntity = .artifact(artifact.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(artifact.title.isEmpty ? artifact.summary : artifact.title)
                                Text(artifact.kind.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !artifact.summary.isEmpty && !artifact.title.isEmpty {
                                    Text(artifact.summary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var linkedRecords: [RecordShell] {
        workspace.linkedRecords(forArcID: arc.id)
    }

    private var linkedArtifacts: [Artifact] {
        workspace.linkedArtifacts(forArcID: arc.id)
    }

    private var linkedEntities: [EntityNode] {
        workspace.linkedEntities(forArcID: arc.id)
    }

    private var linkedReflection: ReflectionSnapshot? {
        workspace.linkedReflection(forArcID: arc.id)
    }

    private var mergePreview: TemporalArcMergePreview? {
        workspace.mergePreview(for: arc.id)
    }

    private var statusActions: some View {
        HStack(spacing: 8) {
            statusButton(title: "Accept", status: .accepted)
            statusButton(title: "Archive", status: .archived)
        }
    }

    private func statusButton(title: String, status: TemporalArcStatus) -> some View {
        Button(title) {
            workspace.updateTemporalArcStatus(status, for: arc.id)
        }
        .buttonStyle(.bordered)
        .disabled(arc.status == status)
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
}
