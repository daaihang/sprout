import SwiftUI
import UIKit

struct PersonCardItem: Identifiable, Hashable {
    let id: UUID
    var name: String
    var nickname: String
    var relationship: String
    var avatarImageData: Data? = nil
    var lastMentionedAt: Date? = nil
    var mentionCount: Int = 0

    init(
        id: UUID = UUID(),
        name: String,
        nickname: String = "",
        relationship: String = "",
        avatarImageData: Data? = nil,
        lastMentionedAt: Date? = nil,
        mentionCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.relationship = relationship
        self.avatarImageData = avatarImageData
        self.lastMentionedAt = lastMentionedAt
        self.mentionCount = mentionCount
    }

    init(person: Person) {
        self.id = person.id
        self.name = person.name
        self.nickname = person.nickname ?? ""
        self.relationship = person.relationship ?? ""
        self.avatarImageData = person.avatarImageData
        self.lastMentionedAt = person.lastMentionedAt
        self.mentionCount = person.mentionCount
    }

    var displayName: String {
        nickname.isEmpty ? name : nickname
    }

    var subtitle: String {
        if !relationship.isEmpty { return relationship }
        if !nickname.isEmpty && nickname != name { return name }
        return ""
    }

    var initials: String {
        let components = name
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .prefix(2)
            .map { String($0.prefix(1)) }
        return components.isEmpty ? String(name.prefix(1)) : components.joined().uppercased()
    }
}

struct PeopleCardData {
    var people: [PersonCardItem] = []

    var isEmpty: Bool { people.isEmpty }
    var count: Int { people.count }
}

struct PeopleCard: View {
    var data: PeopleCardData?
    var onTap: (() -> Void)? = nil

    var body: some View {
        AdaptiveCardRoot(content: peopleContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    private var peopleContent: AdaptiveCardContent? {
        guard let data, !data.isEmpty else { return nil }

        if data.count == 1, let person = data.people.first {
            var meta: [AdaptiveCardMetaItem] = [
                AdaptiveCardMetaItem(
                    systemImage: "bubble.left.and.bubble.right",
                    text: localizedString("card.people.mentions", default: "%d mentions", arguments: [max(person.mentionCount, 1)])
                )
            ]

            if let lastMentionedAt = person.lastMentionedAt {
                meta.append(AdaptiveCardMetaItem(systemImage: "calendar", text: lastMentionedAt.formatted(date: .abbreviated, time: .omitted)))
            }

            return AdaptiveCardContent(
                preferredLayout: .leadingVisual,
                accent: .accentColor,
                visual: .custom(treatment: .thumbnail) {
                    avatarView(for: person, size: 76)
                },
                title: person.displayName,
                subtitle: person.subtitle.isEmpty ? localizedString("card.people.single", default: "Person") : person.subtitle,
                badge: AdaptiveCardBadge(text: "\(max(person.mentionCount, 1))", systemImage: "person.fill"),
                metaItems: meta
            )
        }

        let visiblePeople = Array(data.people.prefix(4))
        return AdaptiveCardContent(
            preferredLayout: .listSummary,
            accent: .accentColor,
            visual: .symbol("person.2.fill", tint: .accentColor, renderingMode: .hierarchical),
            title: localizedString("card.people.title", default: "People"),
            subtitle: localizedString("card.people.count", default: "%d people", arguments: [data.count]),
            badge: AdaptiveCardBadge(text: "\(data.count)", systemImage: "person.2.fill"),
            listItems: visiblePeople.map { person in
                AdaptiveCardListItem(
                    systemImage: "person.crop.circle",
                    symbolColor: .accentColor,
                    title: person.displayName,
                    subtitle: person.subtitle.isEmpty ? nil : person.subtitle,
                    emphasis: true
                )
            },
            footer: data.count > visiblePeople.count
                ? localizedString("card.people.more", default: "+%d more", arguments: [data.count - visiblePeople.count])
                : nil
        )
    }

    @ViewBuilder
    private func avatarView(for person: PersonCardItem, size: CGFloat) -> some View {
        if let avatarImageData = person.avatarImageData, let image = UIImage(data: avatarImageData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: size, height: size)
                .overlay(
                    Text(person.initials)
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                )
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(localizedString("card.people.placeholder", default: "Tap to mention people"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
