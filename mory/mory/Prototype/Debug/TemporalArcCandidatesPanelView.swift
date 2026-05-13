import SwiftUI

struct TemporalArcCandidatesPanelView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    @State private var expandedCandidateIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Phase Candidates")
                    .font(.headline)
                Spacer()
                Text("\(candidates.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if candidates.isEmpty {
                ContentUnavailableView("No Candidates", systemImage: "timeline.selection")
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(candidates) { candidate in
                    candidateCard(candidate)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var candidates: [TemporalArcCandidate] {
        workspace.temporalArcCandidates(limit: 4)
    }

    @ViewBuilder
    private func candidateCard(_ candidate: TemporalArcCandidate) -> some View {
        let isExpanded = expandedCandidateIDs.contains(candidate.id)

        VStack(alignment: .leading, spacing: 10) {
            Button {
                toggle(candidate.id)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(candidate.titleHint)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(dateRangeText(for: candidate))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Text("Strength \(candidate.clusterStrength.formatted(.number.precision(.fractionLength(2))))")
                            Text("Score \(candidate.intensityScore.formatted(.number.precision(.fractionLength(1))))")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Text("Records \(candidate.recordIDs.count) • Artifacts \(candidate.artifactIDs.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !candidate.themeLabels.isEmpty {
                flowLine("Themes", values: candidate.themeLabels, expanded: isExpanded)
            }

            if !candidate.entityNames.isEmpty {
                flowLine("Entities", values: candidate.entityNames, expanded: isExpanded)
            }

            if isExpanded {
                Divider()

                Button {
                    let arcID = workspace.promoteTemporalArc(from: candidate)
                    selection.route = .arcs
                    selection.selectedEntity = .arc(arcID)
                } label: {
                    Label("Promote To Arc", systemImage: "sparkles.rectangle.stack")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Included Records")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(candidate.recordIDs, id: \.self) { recordID in
                        if let record = workspace.record(for: recordID) {
                            Button {
                                selection.route = .records
                                selection.selectedEntity = .record(record.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.rawText)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(3)

                                    HStack(spacing: 10) {
                                        Text(record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        Text(record.captureSource.rawValue)
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !candidate.artifactIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Included Artifacts")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(candidate.artifactIDs, id: \.self) { artifactID in
                            if let artifact = workspace.artifact(for: artifactID) {
                                Button {
                                    selection.route = .artifacts
                                    selection.selectedEntity = .artifact(artifact.id)
                                } label: {
                                    HStack {
                                        Text(artifact.kind.rawValue.capitalized)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text(artifact.title.isEmpty ? artifact.summary : artifact.title)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else if let focusRecordID = candidate.recordIDs.first,
                      let record = workspace.record(for: focusRecordID) {
                Button {
                    selection.route = .records
                    selection.selectedEntity = .record(record.id)
                } label: {
                    Text(record.rawText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func toggle(_ candidateID: UUID) {
        if expandedCandidateIDs.contains(candidateID) {
            expandedCandidateIDs.remove(candidateID)
        } else {
            expandedCandidateIDs.insert(candidateID)
        }
    }

    private func dateRangeText(for candidate: TemporalArcCandidate) -> String {
        "\(candidate.startDate.formatted(date: .abbreviated, time: .omitted)) - \(candidate.endDate.formatted(date: .abbreviated, time: .omitted))"
    }

    @ViewBuilder
    private func flowLine(_ title: String, values: [String], expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(displayValues(values, expanded: expanded).joined(separator: ", "))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func displayValues(_ values: [String], expanded: Bool) -> [String] {
        if expanded { return values }
        return Array(values.prefix(3))
    }
}
