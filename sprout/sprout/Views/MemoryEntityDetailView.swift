import SwiftUI
import SwiftData

struct MemoryEntityDetailView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let entityID: UUID

    private var entityView: SproutMemoryRepository.EntityMemoryView? {
        memoryRepository.entityView(for: entityID)
    }

    private var analysisMentions: [RecordAnalysisSnapshot] {
        memoryRepository.analyses(mentioning: entityID)
    }

    private var phaseEvidenceView: SproutMemoryRepository.EntityPhaseEvidenceView? {
        memoryRepository.entityPhaseEvidenceView(for: entityID)
    }

    var body: some View {
        Group {
            if let entityView {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header(entityView)
                        if !entityView.relatedEntities.isEmpty {
                            relatedEntitiesSection(entityView)
                        }
                        if !entityView.relatedRecords.isEmpty {
                            relatedRecordsSection(entityView)
                        }
                        if !entityView.relatedArtifacts.isEmpty {
                            relatedArtifactsSection(entityView)
                        }
                        if !analysisMentions.isEmpty {
                            analysisMentionsSection
                        }
                        if let phaseEvidenceView, !phaseEvidenceView.relatedArcs.isEmpty || !phaseEvidenceView.relatedReflections.isEmpty {
                            phaseContextSection(phaseEvidenceView)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .padding(.bottom, 40)
                }
                .navigationTitle(entityView.entity.displayName)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    localization.string("memory.entity.empty.title", default: "Entity Not Found"),
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            }
        }
    }

    private func header(_ entityView: SproutMemoryRepository.EntityMemoryView) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entityView.entity.kind.badgeLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(entityView.entity.kind.tintColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(entityView.entity.kind.tintColor.opacity(0.12), in: Capsule())

            if !entityView.entity.summary.isEmpty {
                Text(entityView.entity.summary)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            Text(
                localization.string(
                    "memory.entity.header.summary",
                    default: "%d related memories · %d related entities",
                    arguments: [entityView.relatedRecords.count, entityView.relatedEntities.count]
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .detailCard()
    }

    private func relatedEntitiesSection(_ entityView: SproutMemoryRepository.EntityMemoryView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("point.3.filled.connected.trianglepath.dotted", t("memory.entity.related_entities", "Related Entities"))
            ForEach(entityView.relatedEntities, id: \.id) { related in
                NavigationLink {
                    MemoryEntityDetailView(entityID: related.id)
                } label: {
                    HStack(spacing: 12) {
                        Text(related.kind.badgeLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(related.kind.tintColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(related.kind.tintColor.opacity(0.12), in: Capsule())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(related.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if let edge = entityView.supportingEdges.first(where: {
                                ($0.fromEntityID == entityView.entity.id && $0.toEntityID == related.id) ||
                                ($0.fromEntityID == related.id && $0.toEntityID == entityView.entity.id)
                            }) {
                                Text(edge.relationKind.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .detailCard()
    }

    private func relatedRecordsSection(_ entityView: SproutMemoryRepository.EntityMemoryView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("clock.arrow.trianglehead.counterclockwise.rotate.90", t("memory.entity.related_memories", "Related Memories"))
            ForEach(entityView.relatedRecords, id: \.id) { record in
                if let fullRecord = fetchRecord(id: record.id) {
                    NavigationLink {
                        RecordDetailView(record: fullRecord)
                    } label: {
                        relatedRecordRow(record)
                    }
                    .buttonStyle(.plain)
                } else {
                    relatedRecordRow(record)
                }
            }
        }
        .detailCard()
    }

    private func relatedArtifactsSection(_ entityView: SproutMemoryRepository.EntityMemoryView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("shippingbox", t("memory.entity.related_artifacts", "Related Artifacts"))
            ForEach(entityView.relatedArtifacts.prefix(6), id: \.id) { artifact in
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

    private var analysisMentionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("sparkles", t("memory.entity.analysis_mentions", "Analysis Mentions"))
            ForEach(analysisMentions.prefix(4), id: \.id) { analysis in
                VStack(alignment: .leading, spacing: 6) {
                    Text(analysis.insight)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(analysis.emotionLabel.capitalized)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(analysis.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !analysis.tags.isEmpty {
                        Text(analysis.tags.prefix(4).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .detailCard()
    }

    private func phaseContextSection(_ phaseEvidenceView: SproutMemoryRepository.EntityPhaseEvidenceView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("timeline.selection", t("memory.entity.phase_context", "Phase Context"))

            ForEach(phaseEvidenceView.relatedArcs.prefix(3), id: \.id) { arc in
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            ForEach(phaseEvidenceView.relatedReflections.prefix(2), id: \.id) { reflection in
                NavigationLink {
                    ReflectionDetailView(reflection: reflection)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reflection.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(reflection.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
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

    private func sectionTitle(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func relatedRecordRow(_ record: RecordShell) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.rawText.isEmpty ? t("memory.entity.memory.untitled", "Untitled Memory") : String(record.rawText.prefix(100)))
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

    private func fetchRecord(id: UUID) -> Record? {
        let records = (try? modelContext.fetch(FetchDescriptor<Record>())) ?? []
        return records.first { $0.id == id }
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

private extension EntityRelationKind {
    var label: String {
        switch self {
        case .mentionedWith:
            return "Mentioned together"
        case .repeatedIn:
            return "Repeated pattern"
        case .decidedAt:
            return "Decision context"
        case .relatedTo:
            return "Related"
        }
    }
}
