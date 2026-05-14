import SwiftUI
import SwiftData

struct TemporalArcDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    let arc: TemporalArc

    @State private var showReflectionEditor = false

    private var currentArc: TemporalArc {
        memoryRepository.temporalArc(for: arc.id) ?? arc
    }

    private var evidenceView: SproutMemoryRepository.ArcEvidenceView? {
        memoryRepository.arcEvidenceView(for: arc.id)
    }

    private var relatedRecords: [Record] {
        let records = (try? modelContext.fetch(FetchDescriptor<Record>())) ?? []
        let ids = Set(currentArc.sourceRecordIDs)
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
                managementSection
                if let reflection = memoryRepository.linkedReflection(forArcID: currentArc.id) {
                    reflectionSection(reflection)
                }
                if let evidenceView, !evidenceView.linkedEntities.isEmpty {
                    entitySummarySection(evidenceView)
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
        .navigationTitle(currentArc.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReflectionEditor) {
            ReflectionEditView(recordID: nil, arcID: currentArc.id)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phase")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.12), in: Capsule())

            Text(currentArc.summary)
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

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase Lifecycle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(phaseLifecycleExplanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if currentArc.status != .archived {
                    Button("Archive Phase") {
                        memoryRepository.archiveTemporalArc(currentArc.id)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Restore Phase") {
                        memoryRepository.restoreTemporalArc(currentArc.id)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            Button(action: { showReflectionEditor = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Create Reflection for Phase")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Color.purple)
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

            if let evidenceSummary = reflection.evidenceSummary, !evidenceSummary.isEmpty {
                EvidenceCalloutCard(title: "Evidence Summary", bodyText: evidenceSummary)
            }

            HStack(spacing: 8) {
                if let confidenceText = reflection.confidencePercentageText {
                    SignalPill(title: confidenceText, tint: .orange)
                }
                SignalPill(title: reflection.statusDisplayText, tint: .secondary)
            }

            Text(reflectionSourceExplanation(reflection))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .detailCard()
    }

    private func entitySummarySection(_ evidenceView: SproutMemoryRepository.ArcEvidenceView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Entities in This Phase")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(evidenceView.linkedEntities, id: \.id) { entity in
                NavigationLink {
                    MemoryEntityDetailView(entityID: entity.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(entity.kind.badgeLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(entity.kind.tintColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(entity.kind.tintColor.opacity(0.12), in: Capsule())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entity.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if !entity.summary.isEmpty {
                                Text(entity.summary)
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

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signals")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if !currentArc.themeLabels.isEmpty {
                labelRow(title: "Themes", value: currentArc.themeLabels.prefix(4).joined(separator: ", "))
            }
            if !currentArc.entityNames.isEmpty {
                labelRow(title: "Entities", value: currentArc.entityNames.prefix(4).joined(separator: ", "))
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

            labelRow(title: "Memories", value: "\(currentArc.sourceRecordIDs.count)")
            labelRow(title: "Artifacts", value: "\(currentArc.sourceArtifactIDs.count)")
            labelRow(title: "Cluster", value: "\(Int((currentArc.clusterStrength * 100).rounded()))%")
            labelRow(title: "Intensity", value: String(format: "%.1f", currentArc.intensityScore))
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
        return formatter.string(from: currentArc.startDate, to: currentArc.endDate)
    }

    private func arcEvidenceSummary(for evidenceView: SproutMemoryRepository.ArcEvidenceView) -> String {
        let parts = [
            evidenceView.relatedRecordShells.isEmpty ? nil : "\(evidenceView.relatedRecordShells.count) memories",
            evidenceView.relatedAnalyses.isEmpty ? nil : "\(evidenceView.relatedAnalyses.count) analyses",
            evidenceView.linkedEntities.isEmpty ? nil : "\(evidenceView.linkedEntities.count) entities"
        ].compactMap { $0 }

        return parts.isEmpty ? "No linked evidence yet" : parts.joined(separator: " · ")
    }

    private var phaseLifecycleExplanation: String {
        switch currentArc.status {
        case .candidate:
            return "This phase is still provisional and should not yet drive the long-term memory layer."
        case .accepted:
            return "This phase is part of the active long-term memory structure and can power reflections, search, and entity context."
        case .archived:
            return "This phase has been archived from the active layer, but its evidence remains available for later review."
        }
    }

    private func reflectionSourceExplanation(_ reflection: ReflectionSnapshot) -> String {
        let parts = [
            "\(reflection.sourceRecordIDs.count) source memories",
            reflection.sourceEntityIDs.isEmpty ? nil : "\(reflection.sourceEntityIDs.count) source entities",
            currentArc.dominantTheme.map { "dominant theme: \($0)" }
        ].compactMap { $0 }

        return "Generated from " + parts.joined(separator: " · ")
    }
}
