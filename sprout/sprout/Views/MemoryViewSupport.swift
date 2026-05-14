import SwiftUI
import SwiftData

extension EntityKind {
    var badgeLabel: String {
        switch self {
        case .person:
            return "Person"
        case .place:
            return "Place"
        case .theme:
            return "Theme"
        case .decision:
            return "Decision"
        }
    }

    var tintColor: Color {
        switch self {
        case .person:
            return .blue
        case .place:
            return .green
        case .theme:
            return .orange
        case .decision:
            return .pink
        }
    }
}

extension EntityRelationKind {
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

extension RecordAnalysisSnapshot {
    var saliencePercentageText: String? {
        guard let salienceScore else { return nil }
        return "Salience \(Int((salienceScore * 100).rounded()))"
    }
}

extension ReflectionSnapshot {
    var confidencePercentageText: String? {
        guard let confidence else { return nil }
        return "Confidence \(Int((confidence * 100).rounded()))"
    }

    var statusDisplayText: String {
        switch status {
        case .active:
            return "Active"
        case .saved:
            return "Saved"
        case .dismissed:
            return "Dismissed"
        }
    }
}

extension View {
    func detailCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.white.opacity(0.85),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct SignalPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct TokenPillRow: View {
    let values: [String]
    let tint: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(values, id: \.self) { value in
                    SignalPill(title: value, tint: tint)
                }
            }
        }
    }
}

struct EvidenceCalloutCard: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(bodyText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct AnalysisCompactEvidenceView: View {
    @Environment(AppLocalization.self) private var localization
    let analysis: RecordAnalysisSnapshot
    var showInsight: Bool = true
    var showEntities: Bool = false
    var showRetrievalTerms: Bool = false
    var showReflectionHint: Bool = false
    var maxEntityCount: Int = 3
    var maxRetrievalTermCount: Int = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SignalPill(title: analysis.emotionLabel.capitalized, tint: .secondary)
                if let salienceText = analysis.saliencePercentageText {
                    SignalPill(title: salienceText, tint: .orange)
                }
            }

            if showInsight {
                Text(analysis.insight)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            if showEntities, !analysis.entities.isEmpty {
                Text(
                    analysis.entities
                        .prefix(maxEntityCount)
                        .map { "\($0.kind.badgeLabel): \($0.name)" }
                        .joined(separator: " · ")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            if showRetrievalTerms, !analysis.retrievalTerms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.string("common.retrieval_terms", default: "Retrieval Terms"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TokenPillRow(
                        values: Array(analysis.retrievalTerms.prefix(maxRetrievalTermCount)),
                        tint: .green
                    )
                }
            }

            if showReflectionHint,
               let reflectionHint = analysis.reflectionHint,
               !reflectionHint.isEmpty {
                EvidenceCalloutCard(title: "Reflection Hint", bodyText: reflectionHint)
            }
        }
    }
}

struct SectionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

@MainActor
struct RecordShellSummaryContent: View {
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let recordShell: RecordShell
    var includeMetaLine: Bool = true
    var includeAnalysis: Bool = true
    var maxHeadlineLines: Int = 3

    private var trimmedHeadline: String {
        let trimmed = recordShell.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Memory" : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(trimmedHeadline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(maxHeadlineLines)

            if includeMetaLine {
let metaParts: [String] = [
    recordShell.captureSource.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
    recordShell.userMood?.trimmingCharacters(in: .whitespacesAndNewlines),
].compactMap { value in
    guard let value, !value.isEmpty else { return nil }
    return value
}

                if !metaParts.isEmpty {
                    Text(metaParts.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if includeAnalysis,
               let analysis = memoryRepository.analysis(for: recordShell.id) {
                AnalysisCompactEvidenceView(
                    analysis: analysis,
                    showInsight: true,
                    showEntities: true,
                    showRetrievalTerms: true,
                    showReflectionHint: false,
                    maxEntityCount: 3,
                    maxRetrievalTermCount: 4
                )
            }

            Text(recordShell.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
struct MemoryRecordDetailView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let recordID: UUID
    var focusedSection: RecordSection = .text

    private var memoryView: SproutMemoryRepository.RecordMemoryView? {
        memoryRepository.memoryView(for: recordID)
    }

    private var linkedArcs: [TemporalArc] {
        memoryRepository.temporalArcs
            .filter { $0.sourceRecordIDs.contains(recordID) && $0.status == .accepted }
            .sorted { lhs, rhs in
                if lhs.endDate == rhs.endDate {
                    return lhs.intensityScore > rhs.intensityScore
                }
                return lhs.endDate > rhs.endDate
            }
    }

    var body: some View {
        if let memoryView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    shellSection(memoryView.recordShell)

                    if let analysis = memoryView.analysis {
                        analysisSection(analysis)
                    }

                    if !memoryView.artifacts.isEmpty {
                        artifactsSection(memoryView.artifacts)
                    }

                    if !memoryView.linkedEntities.isEmpty {
                        linkedEntitiesSection(memoryView.linkedEntities)
                    }

                    if !linkedArcs.isEmpty {
                        linkedPhasesSection(linkedArcs)
                    }

                    if let reflection = memoryView.reflection {
                        linkedReflectionSection(reflection)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle(localization.string("detail.navigation.record", default: "Entry"))
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView(
                localization.string("common.memory_unavailable", default: "Memory Unavailable"),
                systemImage: "exclamationmark.triangle",
                description: Text(localization.string("common.memory_unavailable_description", default: "This memory could not be resolved from the new architecture store."))
            )
        }
    }

    private func shellSection(_ recordShell: RecordShell) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", title: localization.string("common.memory_shell", default: "Memory Shell"))
            RecordShellSummaryContent(
                recordShell: recordShell,
                includeMetaLine: true,
                includeAnalysis: false,
                maxHeadlineLines: 4
            )

            HStack(spacing: 10) {
                SignalPill(
                    title: recordShell.captureSource.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                    tint: .blue
                )
                if let mood = recordShell.userMood, !mood.isEmpty {
                    SignalPill(title: mood.capitalized, tint: .orange)
                }
            }
        }
        .detailCard()
    }

    private func analysisSection(_ analysis: RecordAnalysisSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "sparkles", title: localization.string("common.analysis", default: "Analysis"))
            AnalysisCompactEvidenceView(
                analysis: analysis,
                showInsight: true,
                showEntities: true,
                showRetrievalTerms: true,
                showReflectionHint: true
            )
        }
        .detailCard()
    }

    private func artifactsSection(_ artifacts: [Artifact]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "shippingbox", title: localization.string("common.artifacts", default: "Artifacts"))
            ForEach(artifacts, id: \.id) { artifact in
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

    private func linkedEntitiesSection(_ entities: [EntityNode]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "person.2", title: localization.string("common.linked_entities", default: "Linked Entities"))
            TokenPillRow(values: entities.map(\.displayName), tint: .blue)
        }
        .detailCard()
    }

    private func linkedPhasesSection(_ arcs: [TemporalArc]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "timeline.selection", title: localization.string("common.related_phases", default: "Related Phases"))
            ForEach(arcs.prefix(3), id: \.id) { arc in
                NavigationLink {
                    TemporalArcDetailView(arc: arc)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(arc.title)
                            .font(.subheadline.weight(.semibold))
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
        }
        .detailCard()
    }

    private func linkedReflectionSection(_ reflection: ReflectionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "sparkles.rectangle.stack", title: localization.string("common.linked_reflection", default: "Linked Reflection"))
            NavigationLink {
                ReflectionDetailView(reflection: reflection)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reflection.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(reflection.body)
                        .font(.caption)
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
}
