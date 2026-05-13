import SwiftUI

struct PhaseReflectionCardData {
    var title: String
    var body: String
    var phaseTitle: String
    var dateText: String
    var recordCount: Int

    var badgeText: String {
        "\(recordCount) memories"
    }
}

struct PhaseReflectionCard: View {
    let data: PhaseReflectionCardData?

    var body: some View {
        AdaptiveCardRoot(content: reflectionContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
    }

    private var reflectionContent: AdaptiveCardContent? {
        guard let data else { return nil }

        return AdaptiveCardContent(
            preferredLayout: .stackedInfo,
            accent: .purple,
            visual: .symbol("sparkles", tint: .purple, renderingMode: .hierarchical),
            title: "Reflection",
            subtitle: data.phaseTitle,
            body: data.body,
            badge: AdaptiveCardBadge(text: data.badgeText, systemImage: "brain.head.profile"),
            footer: data.dateText
        )
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No reflection yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
