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

    private func contentView(_ data: BookCardData, metrics: CardLayoutMetrics) -> some View {
        let coverWidth = min(max(metrics.containerSize.width * (metrics.isLandscape ? 0.24 : 0.3), 48), 96)

        return HStack(spacing: metrics.isCompactHeight ? 10 : 14) {
            coverImageView(data.coverImageURL, width: coverWidth)

            VStack(alignment: .leading, spacing: 6) {
                Text(data.title)
                    .font(.system(size: metrics.isWideWidth ? 16 : 14, weight: .semibold))
                    .lineLimit(metrics.isTallHeight ? 2 : 1)
                Text(data.author)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let genre = data.genre, !genre.isEmpty, !metrics.isCompactHeight {
                    Text(genre)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let progress = data.progress {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedString("card.book.progress", default: "%d%% read", arguments: [Int(progress * 100)]))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        progressBar(progress)
                    }
                }

                if let rating = data.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: metrics.isTallHeight ? 12 : 10))
                                .foregroundStyle(star <= rating ? .orange : .secondary.opacity(0.3))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(metrics.isCompactHeight ? 12 : 16)
    }

    private func coverImageView(_ url: URL?, width: CGFloat) -> some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.secondary.opacity(0.15).overlay(ProgressView())
                }
            } else {
                Color.secondary.opacity(0.15)
                    .overlay(
                        Image(systemName: "book.fill")
                            .font(.system(size: width * 0.35))
                            .foregroundStyle(.secondary.opacity(0.4))
                    )
            }
        }
        .frame(width: width, height: width * 1.4)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func progressBar(_ progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * progress, height: 5)
            }
        }
        .frame(height: 5)
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
