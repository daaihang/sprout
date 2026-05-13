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
                GeometryReader { geometry in
                    let context = PeopleCardLayoutContext(containerSize: geometry.size, peopleCount: data.count)
                    PeopleCardRenderer(data: data, context: context)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private var placeholderView: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.96, blue: 1.0),
                    Color(red: 0.90, green: 0.95, blue: 0.93)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius - 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                .padding(6)

            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.78))
                        .frame(width: 42, height: 42)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.58))
                }

                Text(localizedString("card.people.placeholder", default: "Tap to mention people"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.72))

                Text(localizedString("card.people.placeholder.subtitle", default: "People mentions accumulate into long-term memory relationships."))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .lineLimit(2)
            }
            .padding(16)
        }
    }
}

private struct PeopleCardRenderer: View {
    let data: PeopleCardData
    let context: PeopleCardLayoutContext

    var body: some View {
        ZStack {
            switch context.mode {
            case .focusSingle:
                focusSingle
            case .duoCluster:
                duoCluster
            case .listCluster:
                listCluster
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous))
        .animation(.spring(duration: 0.34, bounce: 0.16), value: context.mode.rawValue)
    }

    private var focusSingle: some View {
        let person = data.people[0]

        return HStack(spacing: 14) {
            avatarView(for: person, size: context.primaryAvatarSize)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    chip(
                        text: localizedString("card.people.single", default: "Person"),
                        systemImage: "person.fill",
                        lightText: false
                    )
                    if let mentionSummary = mentionSummary(for: person) {
                        chip(text: mentionSummary, systemImage: "bubble.left.and.bubble.right", lightText: false)
                    }
                }

                Text(person.displayName)
                    .font(context.primaryTitleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !person.subtitle.isEmpty {
                    Text(person.subtitle)
                        .font(context.primarySubtitleFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let lastSeen = lastMentionLine(for: person) {
                    Text(lastSeen)
                        .font(context.metaFont)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.98), Color(red: 0.96, green: 0.98, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var duoCluster: some View {
        let visiblePeople = Array(data.people.prefix(2))

        return VStack(alignment: .leading, spacing: 12) {
            header(title: localizedString("card.people.title", default: "People"))

            HStack(spacing: 12) {
                ForEach(visiblePeople) { person in
                    VStack(alignment: .leading, spacing: 8) {
                        avatarView(for: person, size: context.secondaryAvatarSize)

                        Text(person.displayName)
                            .font(context.secondaryTitleFont)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if !person.subtitle.isEmpty {
                            Text(person.subtitle)
                                .font(context.secondarySubtitleFont)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let mentionSummary = mentionSummary(for: person) {
                            Text(mentionSummary)
                                .font(context.metaFont)
                                .foregroundStyle(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            if data.count > visiblePeople.count {
                footer(text: localizedString("card.people.more", default: "+%d more", arguments: [data.count - visiblePeople.count]))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.98))
    }

    private var listCluster: some View {
        let visiblePeople = Array(data.people.prefix(context.visibleCount))

        return VStack(alignment: .leading, spacing: 12) {
            header(title: localizedString("card.people.title", default: "People"))

            VStack(spacing: 10) {
                ForEach(visiblePeople) { person in
                    HStack(spacing: 12) {
                        avatarView(for: person, size: context.rowAvatarSize)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.displayName)
                                .font(context.rowTitleFont)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if !person.subtitle.isEmpty {
                                Text(person.subtitle)
                                    .font(context.rowSubtitleFont)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)

                        if let mentionSummary = mentionSummary(for: person) {
                            Text(mentionSummary)
                                .font(context.metaFont)
                                .foregroundStyle(.secondary.opacity(0.82))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            if data.count > visiblePeople.count {
                footer(text: localizedString("card.people.more", default: "+%d more", arguments: [data.count - visiblePeople.count]))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.98))
    }

    private func header(title: String) -> some View {
        HStack(spacing: 8) {
            chip(
                text: localizedString("card.people.count", default: "%d people", arguments: [data.count]),
                systemImage: "person.2.fill",
                lightText: false
            )
            Spacer(minLength: 0)
            Text(title)
                .font(context.headerFont)
                .foregroundStyle(.primary)
        }
    }

    private func footer(text: String) -> some View {
        Text(text)
            .font(context.metaFont)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
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
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: size, height: size)
                .overlay(
                    Text(person.initials)
                        .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                )
        }
    }

    private func chip(text: String, systemImage: String, lightText: Bool) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(lightText ? Color.white : Color.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(lightText ? Color.black.opacity(0.28) : Color.black.opacity(0.05))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke((lightText ? Color.white : Color.black).opacity(lightText ? 0.16 : 0.08), lineWidth: 1)
            )
    }

    private func mentionSummary(for person: PersonCardItem) -> String? {
        guard person.mentionCount > 0 else { return nil }
        return localizedString("card.people.mentions", default: "%d mentions", arguments: [person.mentionCount])
    }

    private func lastMentionLine(for person: PersonCardItem) -> String? {
        guard let lastMentionedAt = person.lastMentionedAt else { return nil }
        return lastMentionedAt.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct PeopleCardLayoutContext {
    enum Mode: String {
        case focusSingle
        case duoCluster
        case listCluster
    }

    let containerSize: CGSize
    let peopleCount: Int

    var mode: Mode {
        if peopleCount <= 1 {
            return .focusSingle
        }
        if peopleCount == 2 && containerSize.height < 190 {
            return .duoCluster
        }
        return .listCluster
    }

    var visibleCount: Int {
        if containerSize.height < 130 { return 2 }
        if containerSize.height < 190 { return 3 }
        return 4
    }

    var primaryAvatarSize: CGFloat {
        min(max(containerSize.height * 0.42, 64), 88)
    }

    var secondaryAvatarSize: CGFloat {
        min(max(containerSize.height * 0.26, 44), 60)
    }

    var rowAvatarSize: CGFloat {
        min(max(containerSize.height * 0.14, 34), 44)
    }

    var primaryTitleFont: Font {
        containerSize.height > 180
            ? .system(size: 20, weight: .bold, design: .rounded)
            : .system(size: 17, weight: .semibold, design: .rounded)
    }

    var primarySubtitleFont: Font {
        .system(size: 13, weight: .medium)
    }

    var secondaryTitleFont: Font {
        .system(size: 15, weight: .semibold, design: .rounded)
    }

    var secondarySubtitleFont: Font {
        .system(size: 12, weight: .medium)
    }

    var rowTitleFont: Font {
        .system(size: 14, weight: .semibold, design: .rounded)
    }

    var rowSubtitleFont: Font {
        .system(size: 11, weight: .medium)
    }

    var metaFont: Font {
        .system(size: 11, weight: .medium)
    }

    var headerFont: Font {
        .system(size: 16, weight: .semibold, design: .rounded)
    }
}
