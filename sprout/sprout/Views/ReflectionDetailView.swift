import SwiftUI
import SwiftData

struct ReflectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let reflection: ReflectionSnapshot

    private var currentReflection: ReflectionSnapshot {
        memoryRepository.reflectionEvidenceView(for: reflection.id)?.reflection ?? reflection
    }

    private var linkedArc: TemporalArc? {
        guard let arcID = currentReflection.linkedTemporalArcID else { return nil }
        return memoryRepository.temporalArc(for: arcID)
    }

    private var evidenceView: SproutMemoryRepository.ReflectionEvidenceView? {
        memoryRepository.reflectionEvidenceView(for: reflection.id)
    }

    private var relatedRecords: [Record] {
        let records = (try? modelContext.fetch(FetchDescriptor<Record>())) ?? []
        let ids = Set(currentReflection.sourceRecordIDs)
        return records
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var sourceAnalyses: [RecordAnalysisSnapshot] {
        currentReflection.sourceRecordIDs
            .compactMap(memoryRepository.analysis(for:))
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                managementSection
                if let linkedArc {
                    linkedPhaseSection(linkedArc)
                }
                if !sourceAnalyses.isEmpty {
                    sourceAnalysesSection
                }
                if let evidenceView, !evidenceView.linkedEntities.isEmpty {
                    linkedEntitiesSection(evidenceView.linkedEntities)
                }
                if let evidenceView, !evidenceView.linkedArtifacts.isEmpty {
                    linkedArtifactsSection(evidenceView.linkedArtifacts)
                }
                if !relatedRecords.isEmpty {
                    relatedRecordsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle(currentReflection.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(reflectionTypeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.12), in: Capsule())

                Text(currentReflection.statusDisplayText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
            }

            Text(currentReflection.body)
                .font(.body)
                .foregroundStyle(.primary)

            if let evidenceSummary = currentReflection.evidenceSummary, !evidenceSummary.isEmpty {
                EvidenceCalloutCard(title: "Evidence Summary", bodyText: evidenceSummary)
            }

            HStack(spacing: 8) {
                if let confidenceText = currentReflection.confidencePercentageText {
                    SignalPill(title: confidenceText, tint: .orange)
                }
                SignalPill(title: "\(currentReflection.sourceRecordIDs.count) memories", tint: .blue)
                if !currentReflection.sourceEntityIDs.isEmpty {
                    SignalPill(title: "\(currentReflection.sourceEntityIDs.count) entities", tint: .green)
                }
            }

            Text(currentReflection.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let leadAnalysis = sourceAnalyses.first {
                AnalysisCompactEvidenceView(
                    analysis: leadAnalysis,
                    showInsight: false,
                    showEntities: true,
                    showRetrievalTerms: true,
                    showReflectionHint: true
                )
            }
        }
        .detailCard()
    }

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Management")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(managementExplanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if currentReflection.status != .saved {
                    Button("Save Reflection") {
                        memoryRepository.saveReflection(currentReflection.id)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if currentReflection.status != .dismissed {
                    Button("Dismiss") {
                        memoryRepository.dismissReflection(currentReflection.id)
                    }
                    .buttonStyle(.bordered)
                }

                if currentReflection.status == .dismissed {
                    Button("Reactivate") {
                        memoryRepository.reactivateReflection(currentReflection.id)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let savedAt = currentReflection.savedAt, currentReflection.status == .saved {
                Text("Saved \(savedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let dismissedAt = currentReflection.dismissedAt, currentReflection.status == .dismissed {
                Text("Dismissed \(dismissedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .detailCard()
    }

    private func linkedPhaseSection(_ arc: TemporalArc) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Phase")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            NavigationLink {
                TemporalArcDetailView(arc: arc)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(arc.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(arc.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .detailCard()
    }

    private var relatedRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Memories")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(relatedRecords, id: \.id) { record in
                NavigationLink {
                    RecordDetailView(record: record)
                } label: {
                    RecordEvidenceSummaryContent(record: record, includeMetaLine: true, includeAnalysis: false, maxHeadlineLines: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .detailCard()
    }

    private var sourceAnalysesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Source Analyses")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(sourceAnalyses.prefix(3), id: \.id) { analysis in
                AnalysisCompactEvidenceView(
                    analysis: analysis,
                    showInsight: true,
                    showEntities: true,
                    showRetrievalTerms: true,
                    showReflectionHint: false
                )
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .detailCard()
    }

    private func linkedEntitiesSection(_ entities: [EntityNode]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Entities")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(entities.prefix(4), id: \.id) { entity in
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .detailCard()
    }

    private func linkedArtifactsSection(_ artifacts: [Artifact]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Artifacts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(artifacts.prefix(4), id: \.id) { artifact in
                NavigationLink {
                    ArtifactDetailView(artifact: artifact)
                } label: {
                    ArtifactRowView(artifact: artifact, style: .compact)
                }
                .buttonStyle(.plain)
            }
        }
        .detailCard()
    }

    private var reflectionTypeLabel: String {
        switch currentReflection.type {
        case .pattern:
            return "Pattern Reflection"
        case .relationship:
            return "Relationship Reflection"
        case .phase:
            return "Phase Reflection"
        case .record:
            return "Record Reflection"
        }
    }

    private var managementExplanation: String {
        switch currentReflection.status {
        case .active:
            return "This reflection is currently active and can still be reviewed, saved, or dismissed."
        case .saved:
            return "This reflection has been kept as a durable meaning layer on top of the underlying evidence."
        case .dismissed:
            return "This reflection has been hidden from the active layer, but the underlying memory structure still remains."
        }
    }
}
