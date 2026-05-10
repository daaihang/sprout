import SwiftUI

struct QuoteCardData {
    var quote: String = ""
    var author: String = ""
    var source: String = ""

    var isEmpty: Bool { quote.isEmpty }
}

struct QuoteCard: View {
    let size: CardSize
    var data: QuoteCardData?
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let data, !data.isEmpty {
                contentView(data)
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    @ViewBuilder
    private func contentView(_ data: QuoteCardData) -> some View {
        if size == .w4h1 {
            HStack(alignment: .top, spacing: 6) {
                Text("\u{201C}")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .offset(y: -2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(data.quote)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if !data.author.isEmpty {
                        Text("— \(data.author)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else if size == .w4h2 {
            VStack(alignment: .leading, spacing: 4) {
                Text("\u{201C}")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.28))
                    .offset(y: 2)
                Text(data.quote)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                if !data.author.isEmpty {
                    Text("— \(data.author)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if !data.source.isEmpty {
                    Text(data.source)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            .padding(14)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("\u{201C}")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.18))
                    .offset(y: 8)
                Spacer()
                Text(data.quote)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if !data.author.isEmpty || !data.source.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        if !data.author.isEmpty {
                            Text("— \(data.author)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        if !data.source.isEmpty {
                            Text(data.source)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: size == .w4h1 ? 0 : 6) {
            Text("\u{201C}")
                .font(.system(size: size == .w4h1 ? 22 : 36, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.22))
            if size != .w4h1 {
                Text("点击添加语录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct QuoteCard_4x1: View {
    var data: QuoteCardData?
    var onTap: (() -> Void)?
    var body: some View { QuoteCard(size: .w4h1, data: data, onTap: onTap) }
}

struct QuoteCard_4x2: View {
    var data: QuoteCardData?
    var onTap: (() -> Void)?
    var body: some View { QuoteCard(size: .w4h2, data: data, onTap: onTap) }
}

struct QuoteCard_4x4: View {
    var data: QuoteCardData?
    var onTap: (() -> Void)?
    var body: some View { QuoteCard(size: .w4h4, data: data, onTap: onTap) }
}

#Preview {
    VStack(spacing: 12) {
        QuoteCard_4x1(data: QuoteCardData(quote: "不积跬步，无以至千里。", author: "荀子"))
        QuoteCard_4x2(data: QuoteCardData(quote: "宝剑锋从磨砺出，梅花香自苦寒来。", author: "古语"))
        QuoteCard_4x4(data: QuoteCardData(quote: "人生而自由，却无往不在枷锁之中。", author: "卢梭", source: "《社会契约论》"))
    }
    .frame(width: 393)
    .padding()
}
