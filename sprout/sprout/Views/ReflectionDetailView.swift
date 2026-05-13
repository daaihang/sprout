import SwiftUI
import SwiftData

struct ReflectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let reflection: ReflectionSnapshot

    private var linkedArc: TemporalArc? {
        guard let arcID = reflection.linkedTemporalArcID else { return nil }
        return memoryRepository.temporalArc(for: arcID)
    }

    private var evidenceView: SproutMemoryRepository.ReflectionEvidenceView? {
        memoryRepository.reflectionEvidenceView(for: reflection.id)
    }

    private var relatedRecords: [Record] {
        let records = (try? modelContext.fetch(FetchDescriptor<Record>())) ?? []
        let ids = Set(reflection.sourceRecordIDs)
        return records
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var sourceAnalyses: [RecordAnalysisSnapshot] {
        reflection.sourceRecordIDs
            .compactMap(memoryRepository.analysis(for:))
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
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
        .navigationTitle(reflection.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase Reflection")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.12), in: Capsule())

            Text(reflection.body)
                .font(.body)
                .foregroundStyle(.primary)

            Text(reflection.createdAt.formatted(date: .abbreviated, time: .shortened))
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.body.isEmpty ? "Untitled Memory" : String(record.body.prefix(100)))
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
}
