import SwiftUI

struct ArtifactRowView: View {
    let artifact: Artifact
    var entityNames: [String] = []
    var style: Style = .card

    enum Style {
        case card
        case compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(kindBadge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(badgeTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeTint.opacity(0.12), in: Capsule())

                Text(titleText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            if !artifact.summary.isEmpty {
                Text(artifact.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if !artifact.textContent.isEmpty {
                Text(String(artifact.textContent.prefix(140)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !entityNames.isEmpty {
                Text(entityNames.prefix(3).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(style == .card ? 14 : 10)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: style == .card ? 16 : 12, style: .continuous))
    }

    private var titleText: String {
        artifact.title.isEmpty ? kindLabel : artifact.title
    }

    private var backgroundStyle: Color {
        switch style {
        case .card:
            return Color.white.opacity(0.78)
        case .compact:
            return Color.secondary.opacity(0.06)
        }
    }

    private var badgeTint: Color {
        switch artifact.kind {
        case .photo:
            return .blue
        case .audio:
            return .orange
        case .music:
            return .pink
        case .link:
            return .indigo
        case .location, .weather:
            return .green
        case .todo:
            return .teal
        case .personMention:
            return .blue
        case .decisionNote:
            return .purple
        case .book, .film, .game, .ticket, .healthMetric, .text:
            return .accentColor
        }
    }

    private var kindBadge: String {
        switch artifact.kind {
        case .text: return "TEXT"
        case .photo: return "PHOTO"
        case .audio: return "VOICE"
        case .music: return "MUSIC"
        case .link: return "LINK"
        case .location: return "PLACE"
        case .weather: return "WEATHER"
        case .todo: return "TODO"
        case .personMention: return "PERSON"
        case .decisionNote: return "DECISION"
        case .book: return "BOOK"
        case .film: return "FILM"
        case .game: return "GAME"
        case .ticket: return "TICKET"
        case .healthMetric: return "HEALTH"
        }
    }

    private var kindLabel: String {
        switch artifact.kind {
        case .text: return "Text"
        case .photo: return "Photo"
        case .audio: return "Voice"
        case .music: return "Music"
        case .link: return "Link"
        case .location: return "Location"
        case .weather: return "Weather"
        case .todo: return "To-Do"
        case .personMention: return "Person"
        case .decisionNote: return "Decision"
        case .book: return "Book"
        case .film: return "Film"
        case .game: return "Game"
        case .ticket: return "Ticket"
        case .healthMetric: return "Health"
        }
    }
}
