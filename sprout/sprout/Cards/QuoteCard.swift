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
        Group {
            if let data, !data.isEmpty {
                GeometryReader { geo in
                    contentView(data, metrics: CardLayoutMetrics(containerSize: geo.size))
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    private func contentView(_ data: QuoteCardData, metrics: CardLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 4 : 8) {
            Text("\u{201C}")
                .font(.system(size: metrics.isCompactHeight ? 24 : (metrics.isTallHeight ? 50 : 32), weight: .bold))
                .foregroundStyle(.secondary.opacity(0.22))
                .offset(y: metrics.isCompactHeight ? -2 : 4)

            Text(data.quote)
                .font(.system(size: metrics.isCompactHeight ? 12 : (metrics.isTallHeight ? 16 : 13), weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(metrics.isCompactHeight ? 2 : (metrics.isTallHeight ? 8 : 4))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: metrics.isCompactHeight ? 0 : 4)

            if !data.author.isEmpty || !data.source.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if !data.author.isEmpty {
                        Text("— \(data.author)")
                            .font(.system(size: metrics.isCompactHeight ? 10 : 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !data.source.isEmpty {
                        Text(data.source)
                            .font(.system(size: metrics.isCompactHeight ? 9 : 11))
                            .foregroundStyle(.secondary.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(metrics.isCompactHeight ? 12 : 16)
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
