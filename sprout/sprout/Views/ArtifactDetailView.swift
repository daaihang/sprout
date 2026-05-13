import SwiftUI
import SwiftData

struct ArtifactDetailView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let artifact: Artifact

    private var relatedRecords: [Record] {
        let records = (try? modelContext.fetch(FetchDescriptor<Record>())) ?? []
        let ids = Set(
            memoryRepository.recordShells
                .filter { $0.artifactIDs.contains(artifact.id) }
                .map(\.id)
        )
        return records
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var relatedEntities: [EntityNode] {
        let entityIDs = Set(
            memoryRepository.artifactEntityLinks
                .filter { $0.artifactID == artifact.id }
                .map(\.entityID)
        )
        return memoryRepository.entityNodes
            .filter { entityIDs.contains($0.id) }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }
    }

    private var relatedArcs: [TemporalArc] {
        memoryRepository.temporalArcs
            .filter { $0.sourceArtifactIDs.contains(artifact.id) }
            .sorted {
                if $0.endDate == $1.endDate {
                    return $0.intensityScore > $1.intensityScore
                }
                return $0.endDate > $1.endDate
            }
    }

    private var relatedAnalyses: [(record: Record, analysis: RecordAnalysisSnapshot)] {
        relatedRecords.compactMap { record in
            guard let analysis = memoryRepository.analysis(for: record.id) else { return nil }
            return (record: record, analysis: analysis)
        }
    }

    private var leadAnalysis: RecordAnalysisSnapshot? {
        relatedAnalyses.first?.analysis
    }

    private var evidenceSummary: String {
        let parts = [
            relatedRecords.isEmpty ? nil : "\(relatedRecords.count) memories",
            relatedEntities.isEmpty ? nil : "\(relatedEntities.count) entities",
            relatedArcs.isEmpty ? nil : "\(relatedArcs.count) phases"
        ].compactMap { $0 }
        return parts.isEmpty ? "No linked evidence yet" : parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                evidenceSection
                if !relatedRecords.isEmpty {
                    relatedRecordsSection
                }
                if !relatedEntities.isEmpty {
                    relatedEntitiesSection
                }
                if !relatedAnalyses.isEmpty {
                    relatedAnalysesSection
                }
                if !relatedArcs.isEmpty {
                    relatedPhasesSection
                }
                metadataSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle(artifact.title.isEmpty ? artifact.kind.rawValue.capitalized : artifact.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtifactRowView(artifact: artifact, style: .card)
            Text(evidenceSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .detailCard()
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "magnifyingglass", title: "Evidence")
            Text("This artifact is part of the record graph and can be traced back to its source memories, entities, and phases.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let leadAnalysis {
                AnalysisCompactEvidenceView(
                    analysis: leadAnalysis,
                    showInsight: true,
                    showEntities: true,
                    showRetrievalTerms: true,
                    showReflectionHint: true
                )
            }
        }
        .detailCard()
    }

    private var relatedRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", title: "Source Memories")
            ForEach(relatedRecords, id: \.id) { record in
                NavigationLink {
                    RecordDetailView(record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.body.isEmpty ? t("detail.navigation.record", "Entry") : String(record.body.prefix(100)))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .detailCard()
    }

    private var relatedEntitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "person.2", title: "Linked Entities")
            ForEach(relatedEntities, id: \.id) { entity in
                NavigationLink {
                    MemoryEntityDetailView(entityID: entity.id)
                } label: {
                    HStack {
                        Text(entity.kind.badgeLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(entity.kind.tintColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(entity.kind.tintColor.opacity(0.12), in: Capsule())
                        Text(entity.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .detailCard()
    }

    private var relatedAnalysesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "sparkles", title: "Source Analyses")
            ForEach(relatedAnalyses.prefix(4), id: \.record.id) { item in
                VStack(alignment: .leading, spacing: 6) {
                    AnalysisCompactEvidenceView(
                        analysis: item.analysis,
                        showInsight: true,
                        showEntities: true,
                        showRetrievalTerms: true,
                        showReflectionHint: false
                    )

                    Text(item.record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .detailCard()
    }

    private var relatedPhasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "timeline.selection", title: "Related Phases")
            ForEach(relatedArcs.prefix(3), id: \.id) { arc in
                NavigationLink {
                    TemporalArcDetailView(arc: arc)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(arc.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(arc.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if let reflection = memoryRepository.linkedReflection(forArcID: arc.id) {
                            Text(reflection.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .detailCard()
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(icon: "info.circle", title: "Metadata")
            Text("Kind: \(artifact.kind.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Created: \(artifact.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !artifact.metadata.isEmpty {
                ForEach(artifact.metadata.keys.sorted(), id: \.self) { key in
                    Text("\(key): \(artifact.metadata[key] ?? "")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .detailCard()
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}
