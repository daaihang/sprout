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
        AdaptiveCardRoot(content: linkContent) {
            placeholderContent
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cardBackground()
    }

    private var linkContent: AdaptiveCardContent? {
        guard let data = data, !data.links.isEmpty else { return nil }

        if data.links.count == 1, let link = data.links.first {
            return AdaptiveCardContent(
                preferredLayout: .leadingVisual,
                accent: .accentColor,
                visual: .custom(treatment: .thumbnail) {
                    linkIcon(for: link, size: 42)
                        .frame(width: 42, height: 42)
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                },
                title: link.title.isEmpty ? link.domain : link.title,
                subtitle: link.domain,
                body: link.description.isEmpty ? nil : link.description
            )
        }

        let visibleLinks = Array(data.links.prefix(4))
        return AdaptiveCardContent(
            preferredLayout: .listSummary,
            accent: .accentColor,
            visual: .symbol("link", tint: .accentColor, renderingMode: .hierarchical),
            title: localizedString("card.link.title", default: "Links"),
            subtitle: localizedString("card.link.count", default: "%d saved", arguments: [data.links.count]),
            badge: AdaptiveCardBadge(text: "\(data.links.count)", systemImage: "safari"),
            listItems: visibleLinks.map { link in
                AdaptiveCardListItem(
                    systemImage: "link",
                    symbolColor: .accentColor,
                    title: link.title.isEmpty ? link.domain : link.title,
                    subtitle: link.domain,
                    emphasis: true
                )
            },
            footer: data.links.count > visibleLinks.count
                ? localizedString("card.link.more", default: "+%d more", arguments: [data.links.count - visibleLinks.count])
                : nil
        )
    }

    private func linkIcon(for link: LinkItem, size: CGFloat) -> some View {
        if let iconURL = link.iconURL {
            return AnyView(
                CachedRemoteImage(url: iconURL, contentMode: .fit) {
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
