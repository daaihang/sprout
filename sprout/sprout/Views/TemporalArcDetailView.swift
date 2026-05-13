import SwiftUI
import SwiftData

struct TemporalArcDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    let arc: TemporalArc

    private var evidenceView: SproutMemoryRepository.ArcEvidenceView? {
        memoryRepository.arcEvidenceView(for: arc.id)
    }

    private var relatedRecords: [Record] {
        let records = (try? modelContext.fetch(FetchDescriptor<Record>())) ?? []
        let ids = Set(arc.sourceRecordIDs)
        return records
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var leadAnalysis: RecordAnalysisSnapshot? {
        evidenceView?.relatedAnalyses.first
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let reflection = memoryRepository.linkedReflection(forArcID: arc.id) {
                    reflectionSection(reflection)
                }
                metadata
                if !relatedRecords.isEmpty {
                    relatedRecordsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle(arc.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phase")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.12), in: Capsule())

            Text(arc.summary)
                .font(.body)
                .foregroundStyle(.primary)

            Text(dateRangeText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let evidenceView {
                Text(arcEvidenceSummary(for: evidenceView))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let leadAnalysis {
                AnalysisCompactEvidenceView(
                    analysis: leadAnalysis,
                    showInsight: false,
                    showEntities: false,
                    showRetrievalTerms: true,
                    showReflectionHint: true
                )
            }
        }
        .detailCard()
    }

    private func reflectionSection(_ reflection: ReflectionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reflection")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(reflection.title)
                .font(.headline)

            Text(reflection.body)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .detailCard()
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signals")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if !arc.themeLabels.isEmpty {
                labelRow(title: "Themes", value: arc.themeLabels.prefix(4).joined(separator: ", "))
            }
            if !arc.entityNames.isEmpty {
                labelRow(title: "Entities", value: arc.entityNames.prefix(4).joined(separator: ", "))
            }
            if let leadAnalysis, !leadAnalysis.retrievalTerms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Retrieval Terms")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TokenPillRow(values: Array(leadAnalysis.retrievalTerms.prefix(6)), tint: .green)
                }
            }
            if let evidenceView, !evidenceView.relatedAnalyses.isEmpty {
                labelRow(title: "Analyses", value: "\(evidenceView.relatedAnalyses.count)")
            }

            labelRow(title: "Memories", value: "\(arc.sourceRecordIDs.count)")
            labelRow(title: "Artifacts", value: "\(arc.sourceArtifactIDs.count)")
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

    private func labelRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    private var dateRangeText: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: arc.startDate, to: arc.endDate)
    }

    private func arcEvidenceSummary(for evidenceView: SproutMemoryRepository.ArcEvidenceView) -> String {
        let parts = [
            evidenceView.relatedRecordShells.isEmpty ? nil : "\(evidenceView.relatedRecordShells.count) memories",
            evidenceView.relatedAnalyses.isEmpty ? nil : "\(evidenceView.relatedAnalyses.count) analyses",
            evidenceView.linkedEntities.isEmpty ? nil : "\(evidenceView.linkedEntities.count) entities"
        ].compactMap { $0 }

        return parts.isEmpty ? "No linked evidence yet" : parts.joined(separator: " · ")
    }
}
