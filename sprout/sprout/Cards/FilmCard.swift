import SwiftUI

struct FilmCardData: Equatable {
    var title: String = ""
    var year: String = ""
    var posterImageURL: URL?
    var genre: String?
    var rating: Double?
    var director: String?
    var isWatched: Bool = false

    var isEmpty: Bool { title.isEmpty }
}

struct FilmCard: View {
    var data: FilmCardData?
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

    private func contentView(_ data: FilmCardData, metrics: CardLayoutMetrics) -> some View {
        let posterWidth = min(max(metrics.containerSize.width * (metrics.isLandscape ? 0.24 : 0.28), 54), 110)

        return HStack(spacing: metrics.isCompactHeight ? 10 : 14) {
            posterImageView(data.posterImageURL, width: posterWidth)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(data.title)
                        .font(.system(size: metrics.isWideWidth ? 16 : 14, weight: .semibold))
                        .lineLimit(metrics.isTallHeight ? 2 : 1)
                    if data.isWatched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }

                if !data.year.isEmpty {
                    Text(data.year)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if let director = data.director, !director.isEmpty, !metrics.isCompactWidth {
                    Text(director)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                }

                if let genre = data.genre, !genre.isEmpty, metrics.isTallHeight {
                    Text(genre)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let rating = data.rating {
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: Double(index + 1) <= rating ? "star.fill" : "star")
                                .font(.system(size: metrics.isTallHeight ? 14 : 11))
                                .foregroundStyle(Double(index + 1) <= rating ? .orange : .secondary.opacity(0.3))
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: metrics.isTallHeight ? 13 : 11, weight: .medium))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(metrics.isCompactHeight ? 12 : 16)
    }

    private func posterImageView(_ url: URL?, width: CGFloat) -> some View {
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
                        Image(systemName: "film.fill")
                            .font(.system(size: width * 0.35))
                            .foregroundStyle(.secondary.opacity(0.4))
                    )
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholderView: some View {
        HStack(spacing: 10) {
            Color.secondary.opacity(0.1)
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    Image(systemName: "film.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary.opacity(0.3))
                )
            Text(localizedString("card.film.placeholder", default: "Tap to add a film"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
    }
}
