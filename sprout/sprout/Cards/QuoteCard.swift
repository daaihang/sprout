import SwiftUI

struct QuoteCardData {
    var quote: String = ""
    var author: String = ""
    var source: String = ""

    var isEmpty: Bool { quote.isEmpty }
}

struct QuoteCard: View {
    var data: QuoteCardData?
    var onTap: (() -> Void)?

    var body: some View {
        AdaptiveCardRoot(content: quoteContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    private var quoteContent: AdaptiveCardContent? {
        guard let data, !data.isEmpty else { return nil }

        return AdaptiveCardContent(
            preferredLayout: .automatic,
            accent: Color.secondary,
            visual: .symbol("quote.opening", tint: .secondary, renderingMode: .hierarchical),
            title: data.author.isEmpty ? localizedString("card.quote.title", default: "Quote") : "— \(data.author)",
            subtitle: data.source.isEmpty ? nil : data.source,
            body: data.quote
        )
    }

    private var placeholderView: some View {
        VStack(spacing: 6) {
            Text("\u{201C}")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.22))
            Text(localizedString("card.quote.placeholder", default: "Tap to add a quote"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
