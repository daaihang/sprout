import Foundation

struct HomeBoardCardMetadata: Hashable, Sendable {
    let kindLabel: String
    let iconName: String
    let title: String
    let summary: String?
    let reason: String
    let sourceCount: Int

    init(item: HomeBoardItemSnapshot) {
        kindLabel = Self.kindLabel(for: item.cardKind)
        iconName = Self.iconName(for: item.cardKind)
        reason = item.reason.ifEmpty("recent activity")
        sourceCount = item.sourceRecordIDs.count

        switch item.renderValue {
        case let .memory(memory):
            title = memory.title
            summary = memory.summaryText
        case let .arc(arc):
            title = arc.title
            summary = arc.summary
        case let .reflection(reflection):
            title = reflection.title
            summary = reflection.body
        case let .clarificationQuestion(question, profile):
            title = profile?.displayName.trimmedOrNil ?? question.prompt
            summary = question.reason.trimmedOrNil
        case let .yesterdayPanel(title, subtitle, _):
            self.title = title
            summary = subtitle
        case let .systemPrompt(title, subtitle, _):
            self.title = title
            summary = subtitle
        case let .contextCluster(title, subtitle, _):
            self.title = title
            summary = subtitle
        case let .pendingAction(title, subtitle, _):
            self.title = title
            summary = subtitle
        }
    }

    var accessibilityLabel: String {
        [kindLabel, title]
            .compactMap(\.trimmedOrNil)
            .joined(separator: ", ")
    }

    var accessibilityHint: String {
        var parts = ["Double tap to open or review this card."]
        if sourceCount > 0 {
            parts.append("\(sourceCount) source memories.")
        }
        parts.append("Reason: \(reason).")
        return parts.joined(separator: " ")
    }

    static func kindLabel(for kind: HomeBoardCardKind) -> String {
        switch kind {
        case .memory: return String(localized: "home.board.kind.memory")
        case .arc: return String(localized: "home.board.kind.arc")
        case .reflection: return String(localized: "home.board.kind.reflection")
        case .clarificationQuestion: return "Question"
        case .yesterdayPanel: return "Yesterday"
        case .systemPrompt: return String(localized: "home.board.kind.system")
        case .contextCluster: return String(localized: "home.board.kind.cluster")
        case .pendingAction: return String(localized: "home.board.kind.pending")
        }
    }

    static func iconName(for kind: HomeBoardCardKind) -> String {
        switch kind {
        case .memory: return "doc.text"
        case .arc: return "point.3.connected.trianglepath.dotted"
        case .reflection: return "sparkles"
        case .clarificationQuestion: return "questionmark.bubble"
        case .yesterdayPanel: return "calendar"
        case .systemPrompt: return "hand.wave"
        case .contextCluster: return "square.stack.3d.up"
        case .pendingAction: return "exclamationmark.circle"
        }
    }
}
