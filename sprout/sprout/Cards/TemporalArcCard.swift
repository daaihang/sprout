import SwiftUI

struct TemporalArcCardData {
    var title: String
    var summary: String
    var dominantTheme: String?
    var dominantEntityName: String?
    var dateRangeText: String
    var recordCount: Int
    var artifactCount: Int

    var badgeText: String {
        "\(recordCount) memories"
    }
}

struct TemporalArcCard: View {
    let data: TemporalArcCardData?

    var body: some View {
        AdaptiveCardRoot(content: arcContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
    }

    private var arcContent: AdaptiveCardContent? {
        guard let data else { return nil }

        let subtitleParts = [data.dominantTheme, data.dominantEntityName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let footerParts = [data.dateRangeText, "\(data.artifactCount) artifacts"]
            .filter { !$0.isEmpty }

        return AdaptiveCardContent(
            preferredLayout: .stackedInfo,
            accent: .orange,
            visual: .symbol("timeline.selection", tint: .orange, renderingMode: .hierarchical),
            title: "Current Phase",
            subtitle: subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " · "),
            body: data.summary.isEmpty ? data.title : data.summary,
            badge: AdaptiveCardBadge(text: data.badgeText, systemImage: "sparkles"),
            footer: footerParts.joined(separator: " · ")
        )
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "timeline.selection")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No active phase yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
