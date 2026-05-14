import SwiftUI

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
                    Text("Retrieval Terms")
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
struct RecordEvidenceSummaryContent: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let record: Record
    var includeMetaLine: Bool = true
    var includeAnalysis: Bool = true
    var maxHeadlineLines: Int = 3

    private var evidence: RecordEvidenceProjector.Projection {
        RecordEvidenceProjector(localization: localization)
            .project(record: record, memoryView: memoryRepository.memoryView(for: record.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(evidence.headlineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Memory" : evidence.headlineText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(maxHeadlineLines)

            if includeMetaLine, let supporting = evidence.supportingText, !supporting.isEmpty {
                Text(supporting)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if includeMetaLine, !evidence.metaLabels.isEmpty {
                Text(evidence.metaLabels.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if includeAnalysis,
               let analysis = evidence.analysis {
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

            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
struct RecordShellFallbackSummaryContent: View {
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let recordShell: RecordShell
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
