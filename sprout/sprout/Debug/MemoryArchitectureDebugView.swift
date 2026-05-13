import SwiftUI

struct MemoryArchitectureDebugView: View {
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    private var recentAnalyses: [RecordAnalysisSnapshot] {
        memoryRepository.analyses
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(6)
            .map { $0 }
    }

    private var strongestEdges: [EntityEdge] {
        memoryRepository.entityEdges
            .sorted { lhs, rhs in
                if lhs.evidenceCount == rhs.evidenceCount {
                    if lhs.weight == rhs.weight {
                        return lhs.lastSeenAt > rhs.lastSeenAt
                    }
                    return lhs.weight > rhs.weight
                }
                return lhs.evidenceCount > rhs.evidenceCount
            }
            .prefix(8)
            .map { $0 }
    }

    private var recentArcs: [TemporalArc] {
        memoryRepository.temporalArcs
            .sorted {
                if $0.endDate == $1.endDate {
                    return $0.intensityScore > $1.intensityScore
                }
                return $0.endDate > $1.endDate
            }
            .prefix(6)
            .map { $0 }
    }

    private var recentReflections: [ReflectionSnapshot] {
        memoryRepository.reflections
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        List {
            summarySection
            recentAnalysesSection
            graphSection
            arcSection
            reflectionSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Memory Architecture")
    }

    private var summarySection: some View {
        Section {
            debugRow("Capture Shells", "\(memoryRepository.recordShells.count)")
            debugRow("Artifacts", "\(memoryRepository.artifacts.count)")
            debugRow("Analyses", "\(memoryRepository.analyses.count)")
            debugRow("Entity Nodes", "\(memoryRepository.entityNodes.count)")
            debugRow("Entity Edges", "\(memoryRepository.entityEdges.count)")
            debugRow("Artifact Links", "\(memoryRepository.artifactEntityLinks.count)")
            debugRow("Temporal Arcs", "\(memoryRepository.temporalArcs.count)")
            debugRow("Reflections", "\(memoryRepository.reflections.count)")
        } header: {
            Text("Snapshot")
        } footer: {
            Text("This page mirrors the v3 memory stack directly: capture shells, artifacts, analyses, graph, arcs, and reflections.")
        }
    }

    private var recentAnalysesSection: some View {
        Section {
            if recentAnalyses.isEmpty {
                Text("No analysis snapshots stored yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentAnalyses, id: \.id) { analysis in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(analysis.summary.isEmpty ? "Untitled analysis" : analysis.summary)
                            .font(.subheadline.weight(.semibold))
                        Text(analysis.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            SignalPill(title: analysis.emotionLabel.capitalized, tint: .secondary)
                            SignalPill(title: "\(analysis.entities.count) entities", tint: .blue)
                            SignalPill(title: "\(analysis.candidateEdges.count) AI edges", tint: .orange)
                        }
                        if !analysis.tags.isEmpty {
                            TokenPillRow(values: Array(analysis.tags.prefix(5)), tint: .green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Recent Analyses")
        } footer: {
            Text("Candidate edge count shows whether AI is proposing graph structure, not just prose.")
        }
    }

    private var graphSection: some View {
        Section {
            if strongestEdges.isEmpty {
                Text("No entity relationships accumulated yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(strongestEdges, id: \.id) { edge in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(edgeTitle(edge))
                            .font(.subheadline.weight(.semibold))
                        Text(edge.relationKind.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            SignalPill(title: "\(edge.evidenceCount) evidence", tint: .blue)
                            SignalPill(title: "\(edge.sourceRecordIDs.count) records", tint: .green)
                            SignalPill(title: "\(edge.sourceArtifactIDs.count) artifacts", tint: .orange)
                        }
                        Text("Last seen \(edge.lastSeenAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Graph Evidence")
        } footer: {
            Text("This is the long-term semantic layer. If this stays empty, entity pages and phase building remain shallow.")
        }
    }

    private var arcSection: some View {
        Section {
            if recentArcs.isEmpty {
                Text("No temporal arcs built yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentArcs, id: \.id) { arc in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(arc.title)
                            .font(.subheadline.weight(.semibold))
                        Text(arc.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            SignalPill(title: arc.status.rawValue.capitalized, tint: .orange)
                            SignalPill(title: "\(arc.sourceRecordIDs.count) memories", tint: .blue)
                            SignalPill(title: "\(arc.sourceEntityIDs.count) entities", tint: .green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Temporal Arcs")
        } footer: {
            Text("Arcs should emerge from repeated structure. If records are analyzed but arcs stay empty, Phase 5 is not really alive yet.")
        }
    }

    private var reflectionSection: some View {
        Section {
            if recentReflections.isEmpty {
                Text("No reflections generated yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentReflections, id: \.id) { reflection in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reflection.title)
                            .font(.subheadline.weight(.semibold))
                        Text(reflection.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        HStack(spacing: 8) {
                            SignalPill(title: reflection.type.rawValue.capitalized, tint: .purple)
                            SignalPill(title: reflection.statusDisplayText, tint: .secondary)
                            SignalPill(title: "\(reflection.sourceRecordIDs.count) memories", tint: .blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Reflections")
        } footer: {
            Text("Reflection is the top layer. It should sit on top of analysis, graph, and arcs instead of replacing them.")
        }
    }

    private func edgeTitle(_ edge: EntityEdge) -> String {
        let from = memoryRepository.entityNode(for: edge.fromEntityID)?.displayName ?? edge.fromEntityID.uuidString
        let to = memoryRepository.entityNode(for: edge.toEntityID)?.displayName ?? edge.toEntityID.uuidString
        return "\(from) -> \(to)"
    }

    private func debugRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        MemoryArchitectureDebugView()
    }
}
