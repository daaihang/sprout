import SwiftUI

struct BookCardData: Equatable {
    var title: String = ""
    var author: String = ""
    var coverImageURL: URL?
    var progress: Double?
    var genre: String?
    var rating: Int?

    var isEmpty: Bool { title.isEmpty }
}

struct BookCard: View {
    var data: BookCardData?
    var onTap: (() -> Void)?

    var body: some View {
        AdaptiveCardRoot(content: bookContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    private var bookContent: AdaptiveCardContent? {
        guard let data, !data.isEmpty else { return nil }

        return AdaptiveCardContent(
            preferredLayout: .leadingVisual,
            accent: Color.orange,
            visual: .remoteImage(data.coverImageURL, placeholderSystemName: "book.fill", treatment: .cover),
            title: data.title,
            subtitle: data.author,
            body: data.genre,
            badge: data.rating.map { AdaptiveCardBadge(text: "\($0)/5", systemImage: "star.fill") },
            progress: data.progress.map {
                AdaptiveCardProgress(
                    value: $0,
                    label: localizedString("card.book.progress_label", default: "Reading"),
                    trailingText: localizedString("card.book.progress", default: "%d%% read", arguments: [Int($0 * 100)])
                )
            }
        )
    }

    private var placeholderView: some View {
        HStack(spacing: 10) {
            Color.secondary.opacity(0.1)
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary.opacity(0.3))
                )
            Text(localizedString("card.book.placeholder", default: "Tap to add a book"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
    }
}
