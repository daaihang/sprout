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
                quoteBody(data)
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardBackground()
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    @ViewBuilder
    private func quoteBody(_ data: QuoteCardData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("\u{201C}")
                    .font(.system(size: 42, weight: .black, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.16))
                Spacer(minLength: 0)
                if !data.source.isEmpty {
                    Text(data.source.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.05))
                        )
                }
            }

            Spacer(minLength: 6)

            Text(data.quote)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .lineLimit(7)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 12)

            HStack(alignment: .bottom, spacing: 10) {
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 28, height: 1.5)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(data.author.isEmpty ? localizedString("card.quote.title", default: "Quote") : data.author)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    if !data.source.isEmpty {
                        Text(localizedString("card.quote.source_label", default: "Saved source"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
    }

    private var placeholderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\u{201C}")
                .font(.system(size: 34, weight: .black, design: .serif))
                .foregroundStyle(.secondary.opacity(0.18))
            Text(localizedString("card.quote.placeholder", default: "Tap to add a quote"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
    }
}
