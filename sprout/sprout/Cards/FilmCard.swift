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
        AdaptiveCardRoot(content: filmContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    private var filmContent: AdaptiveCardContent? {
        guard let data, !data.isEmpty else { return nil }

        var meta: [AdaptiveCardMetaItem] = []
        if !data.year.isEmpty {
            meta.append(AdaptiveCardMetaItem(systemImage: "calendar", text: data.year))
        }
        if let director = data.director, !director.isEmpty {
            meta.append(AdaptiveCardMetaItem(systemImage: "movieclapper", text: director))
        }
        if let genre = data.genre, !genre.isEmpty {
            meta.append(AdaptiveCardMetaItem(systemImage: "tag", text: genre))
        }

        return AdaptiveCardContent(
            preferredLayout: .leadingVisual,
            accent: Color(red: 0.84, green: 0.48, blue: 0.12),
            visual: .remoteImage(data.posterImageURL, placeholderSystemName: "film.fill", treatment: .cover),
            title: data.title,
            subtitle: data.year.isEmpty ? nil : data.year,
            body: data.genre,
            badge: data.isWatched ? AdaptiveCardBadge(text: localizedString("card.film.watched", default: "Watched"), systemImage: "checkmark.circle.fill") : nil,
            metaItems: meta,
            footer: data.rating.map { String(format: localizedString("card.film.rating", default: "Rating %.1f"), $0) }
        )
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
