import SwiftUI

struct LinkItem: Identifiable, Equatable {
    let id = UUID()
    var url: URL
    var title: String
    var description: String
    var iconURL: URL?

    var domain: String {
        url.host ?? url.absoluteString
    }

    static func == (lhs: LinkItem, rhs: LinkItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url && lhs.title == rhs.title && lhs.description == rhs.description
    }
}

struct LinkCardData: Equatable {
    var links: [LinkItem]

    init(links: [LinkItem] = []) {
        self.links = links
    }
}

struct LinkCard: View {
    var data: LinkCardData?

    var body: some View {
        cardContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cardBackground()
    }

    @ViewBuilder
    private var cardContent: some View {
        if let data = data, !data.links.isEmpty {
            GeometryReader { geo in
                let metrics = CardLayoutMetrics(containerSize: geo.size)
                contentView(data, metrics: metrics)
            }
        } else {
            placeholderContent
        }
    }

    @ViewBuilder
    private func contentView(_ data: LinkCardData, metrics: CardLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if data.links.count == 1 {
                singleLinkContent(data.links[0], metrics: metrics)
            } else {
                multiLinkContent(data.links, metrics: metrics)
            }
        }
        .padding(metrics.isCompactHeight ? 10 : 12)
    }

    private func singleLinkContent(_ link: LinkItem, metrics: CardLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                linkIcon(for: link, size: 16)

                Text(link.title.isEmpty ? link.domain : link.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(metrics.isTallHeight || metrics.isWideWidth ? 2 : 1)
            }

            if !link.description.isEmpty {
                Text(link.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(metrics.isTallHeight || metrics.isWideWidth ? 3 : 1)
            }

            Text(link.domain)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func multiLinkContent(_ links: [LinkItem], metrics: CardLayoutMetrics) -> some View {
        let maxItems = metrics.isTallHeight ? 4 : (metrics.isWideWidth ? 3 : 2)

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(links.prefix(maxItems)) { link in
                HStack(spacing: 6) {
                    linkIcon(for: link, size: 12)

                    Text(link.title.isEmpty ? link.domain : link.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }

            if links.count > maxItems {
                Text(localizedString("card.link.more", default: "+%d more", arguments: [links.count - maxItems]))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linkIcon(for link: LinkItem, size: CGFloat) -> some View {
        if let iconURL = link.iconURL {
            return AnyView(
                AsyncImage(url: iconURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "link")
                        .font(.system(size: size))
                        .foregroundColor(.accentColor)
                }
                .frame(width: size, height: size)
            )
        }

        return AnyView(
            Image(systemName: "link")
                .font(.system(size: size))
                .foregroundColor(.accentColor)
        )
    }

    @ViewBuilder
    private var placeholderContent: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.5))
                Text(localizedString("card.link.placeholder", default: "Tap to add a link"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
