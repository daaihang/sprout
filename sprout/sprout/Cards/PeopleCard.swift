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

    @ViewBuilder
    private func contentView(_ data: PeopleCardData, metrics: CardLayoutMetrics) -> some View {
        if data.count == 1, let person = data.people.first {
            singlePersonView(person, metrics: metrics)
        } else {
            multiPersonView(data, metrics: metrics)
        }
    }

    private func singlePersonView(_ person: PersonCardItem, metrics: CardLayoutMetrics) -> some View {
        HStack(spacing: metrics.isCompactHeight ? 10 : 14) {
            avatarView(for: person, size: metrics.isCompactHeight ? 48 : (metrics.isWideWidth ? 76 : 64))

            VStack(alignment: .leading, spacing: 6) {
                Text(person.displayName)
                    .font(.system(size: metrics.isWideWidth ? 18 : 15, weight: .semibold))
                    .lineLimit(2)

                if !person.subtitle.isEmpty {
                    Text(person.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Label(
                        localizedString("card.people.mentions", default: "%d mentions", arguments: [max(person.mentionCount, 1)]),
                        systemImage: "bubble.left.and.bubble.right"
                    )
                    .lineLimit(1)

                    if let lastMentionedAt = person.lastMentionedAt, !metrics.isCompactWidth {
                        Text(lastMentionedAt.formatted(date: .abbreviated, time: .omitted))
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(metrics.isCompactHeight ? 12 : 16)
    }

    private func multiPersonView(_ data: PeopleCardData, metrics: CardLayoutMetrics) -> some View {
        let visibleCount = metrics.isTallHeight ? min(4, data.count) : (metrics.isWideWidth ? min(3, data.count) : min(2, data.count))

        return VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 10 : 14) {
            HStack {
                Label(
                    localizedString("card.people.title", default: "People"),
                    systemImage: "person.2.fill"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

                Spacer()

                Text(localizedString("card.people.count", default: "%d people", arguments: [data.count]))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(Array(data.people.prefix(visibleCount))) { person in
                    HStack(spacing: 10) {
                        avatarView(for: person, size: metrics.isCompactHeight ? 36 : 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            if !person.subtitle.isEmpty && !metrics.isCompactWidth {
                                Text(person.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                }
            }

            if data.count > visibleCount {
                Text(localizedString("card.people.more", default: "+%d more", arguments: [data.count - visibleCount]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(metrics.isCompactHeight ? 12 : 16)
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
