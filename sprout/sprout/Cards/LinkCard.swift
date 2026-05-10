import SwiftUI
import UIKit

struct LinkItem: Identifiable, Equatable {
    let id = UUID()
    var url: URL
    var title: String
    var description: String
    var iconImage: UIImage?

    var domain: String {
        url.host ?? url.absoluteString
    }

    var iconURL: URL? {
        URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64")
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
    let size: CardSize
    var data: LinkCardData?

    var body: some View {
        cardContent
            .frame(width: size.width, height: size.height)
            .cardBackground()
    }

    @ViewBuilder
    private var cardContent: some View {
        if let data = data, !data.links.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if data.links.count == 1 {
                    singleLinkContent(data.links[0])
                } else {
                    multiLinkContent(data.links)
                }
            }
            .padding(12)
        } else {
            placeholderContent
        }
    }

    @ViewBuilder
    private func singleLinkContent(_ link: LinkItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                linkIcon(for: link, size: 16)

                Text(link.title.isEmpty ? link.domain : link.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(size == .w4h2 ? 1 : 2)
            }

            if !link.description.isEmpty {
                Text(link.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(size == .w4h2 ? 1 : 3)
            }

            Text(link.domain)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func multiLinkContent(_ links: [LinkItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(links.prefix(size == .w4h2 ? 2 : 4)) { link in
                HStack(spacing: 6) {
                    linkIcon(for: link, size: 12)

                    Text(link.title.isEmpty ? link.domain : link.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }

            if links.count > (size == .w4h2 ? 2 : 4) {
                Text("+\(links.count - (size == .w4h2 ? 2 : 4)) more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func linkIcon(for link: LinkItem, size: CGFloat) -> some View {
        if let iconImage = link.iconImage {
            Image(uiImage: iconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "link")
                .font(.system(size: size))
                .foregroundColor(.accentColor)
        }
    }

    @ViewBuilder
    private var placeholderContent: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("点击添加链接")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct LinkCard_4x2: View {
    var data: LinkCardData?
    var body: some View { LinkCard(size: .w4h2, data: data) }
}

struct LinkCard_4x4: View {
    var data: LinkCardData?
    var body: some View { LinkCard(size: .w4h4, data: data) }
}

#Preview {
    VStack(spacing: 12) {
        LinkCard_4x2(data: LinkCardData(links: [
            LinkItem(url: URL(string: "https://example.com")!, title: "Example Site", description: "This is an example description")
        ]))
        LinkCard_4x4(data: LinkCardData(links: [
            LinkItem(url: URL(string: "https://apple.com")!, title: "Apple", description: "Apple official website"),
            LinkItem(url: URL(string: "https://google.com")!, title: "Google", description: "Google search")
        ]))
    }
    .frame(width: 400)
}
