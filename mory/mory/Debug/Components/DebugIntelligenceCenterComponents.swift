#if DEBUG
import SwiftUI
import UIKit

struct DebugCenterValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

struct DebugCenterPayloadBlock: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = content
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
            Text(content.isEmpty ? "empty" : content)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}

struct DebugCenterProgressRow: View {
    let text: String

    var body: some View {
        HStack {
            ProgressView()
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

func debugControlLabel(_ rawValue: String) -> String {
    rawValue
        .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        .replacingOccurrences(of: "_", with: " ")
        .capitalized
}

func cloudGateReason(_ cloudEnabled: Bool, _ flagEnabled: Bool, flagName: String) -> String {
    var reasons: [String] = []
    if !cloudEnabled {
        reasons.append("cloudIntelligenceEnabled=false")
    }
    if !flagEnabled {
        reasons.append("\(flagName)=false")
    }
    return reasons.isEmpty ? "enabled" : "blocked: \(reasons.joined(separator: ", "))"
}

func debugHomeBoardTitle(_ item: HomeBoardItemSnapshot) -> String {
    switch item.renderValue {
    case let .memory(memory):
        return memory.title
    case let .arc(arc):
        return arc.title
    case let .reflection(reflection):
        return reflection.title
    case let .clarificationQuestion(question, profile):
        return profile.map { "\($0.displayName): \(question.prompt)" } ?? question.prompt
    case let .yesterdayPanel(title, _, _):
        return title
    case let .systemPrompt(title, _, _):
        return title
    case let .contextCluster(title, _, _):
        return title
    case let .pendingAction(title, _, _):
        return title
    }
}

func debugActionLabel(_ action: HomeBoardPreferenceAction) -> String {
    switch action {
    case .addToBoard:
        return "addToBoard"
    case let .pin(value):
        return "pin(\(value))"
    case let .resize(span):
        return "resize(\(span.widthColumns)x\(span.heightUnits))"
    case let .setUserOrder(value):
        return "setUserOrder(\(value))"
    case .preferMore:
        return "preferMore"
    case .preferLess:
        return "preferLess"
    case .resetFeedback:
        return "resetFeedback"
    case .hide:
        return "hide"
    case .dismiss:
        return "dismiss"
    }
}

func isoDate(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}


struct DebugV6GateDiagnosticRow: View {
    let diagnostic: V6GateDiagnostic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(
                    diagnostic.statusText,
                    systemImage: diagnostic.isEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(diagnostic.isEnabled ? .green : .orange)
                Spacer()
                Text(diagnostic.title)
                    .font(.caption.weight(.semibold))
            }



            if !diagnostic.isEnabled {
                Text(diagnostic.reasonText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 3)
    }
}


enum DebugEnqueueableJobKind: String, CaseIterable, Identifiable {
    case dailyQuestion
    case semanticIndex
    case notificationIntent
    case chapterCandidate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailyQuestion: "Daily question"
        case .semanticIndex: "Semantic index"
        case .notificationIntent: "Notification intent"
        case .chapterCandidate: "Chapter candidate"
        }


    }

    var kind: IntelligenceJobKind {
        switch self {
        case .dailyQuestion: .dailyQuestion
        case .semanticIndex: .semanticIndex
        case .notificationIntent: .notificationIntent
        case .chapterCandidate: .chapterCandidate
        }
    }

    var targetType: IntelligenceTargetType {
        switch self {
        case .dailyQuestion, .chapterCandidate:
            .board
        case .semanticIndex:
            .searchIndex
        case .notificationIntent:
            .notification
        }
    }

    var defaultPriority: Double {
        switch self {
        case .dailyQuestion: 0.74
        case .semanticIndex: 0.62
        case .notificationIntent: 0.58
        case .chapterCandidate: 0.68
        }
    }

    var requiresCloudAI: Bool {
        switch self {
        case .dailyQuestion, .chapterCandidate:
            true
        case .semanticIndex, .notificationIntent:
            false
        }
    }
}
#endif
