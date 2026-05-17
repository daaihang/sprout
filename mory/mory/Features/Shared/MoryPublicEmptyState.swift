import SwiftUI

enum MoryPublicEmptyStateID: String, Equatable, Sendable {
    case today
    case memories
    case filteredMemories
    case insights
    case search
    case permissionDenied
    case processingFailed
}

struct MoryPublicEmptyState: Equatable, Sendable {
    let id: MoryPublicEmptyStateID
    let titleKey: String
    let messageKey: String
    let actionKey: String?
    let systemImage: String

    var hasAction: Bool {
        actionKey != nil
    }

    var exposesDebugCopy: Bool {
        false
    }

    static let today = MoryPublicEmptyState(
        id: .today,
        titleKey: "empty.today.title",
        messageKey: "empty.today.message",
        actionKey: "empty.action.addFirstMemory",
        systemImage: "plus.bubble"
    )

    static let memories = MoryPublicEmptyState(
        id: .memories,
        titleKey: "empty.memories.title",
        messageKey: "empty.memories.message",
        actionKey: "empty.action.addMemory",
        systemImage: "square.stack"
    )

    static let filteredMemories = MoryPublicEmptyState(
        id: .filteredMemories,
        titleKey: "empty.memories.filtered.title",
        messageKey: "empty.memories.filtered.message",
        actionKey: "empty.action.clearFilters",
        systemImage: "line.3.horizontal.decrease.circle"
    )

    static let insights = MoryPublicEmptyState(
        id: .insights,
        titleKey: "empty.insights.title",
        messageKey: "empty.insights.message",
        actionKey: "empty.action.addMemory",
        systemImage: "sparkles.rectangle.stack"
    )

    static let search = MoryPublicEmptyState(
        id: .search,
        titleKey: "empty.search.title",
        messageKey: "empty.search.message",
        actionKey: "empty.action.clearSearch",
        systemImage: "magnifyingglass"
    )

    static let permissionDenied = MoryPublicEmptyState(
        id: .permissionDenied,
        titleKey: "empty.permission.title",
        messageKey: "empty.permission.message",
        actionKey: "empty.action.openSettings",
        systemImage: "hand.raised"
    )

    static let processingFailed = MoryPublicEmptyState(
        id: .processingFailed,
        titleKey: "empty.processingFailed.title",
        messageKey: "empty.processingFailed.message",
        actionKey: "empty.action.retry",
        systemImage: "exclamationmark.arrow.triangle.2.circlepath"
    )
}

struct MoryPublicEmptyStateView: View {
    let state: MoryPublicEmptyState
    var onAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: MorySpacing.medium) {
            Label {
                Text(LocalizedStringKey(state.titleKey))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: state.systemImage)
                    .foregroundStyle(.secondary)
            }

            Text(LocalizedStringKey(state.messageKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let actionKey = state.actionKey, let onAction {
                Button {
                    onAction()
                } label: {
                    Label(LocalizedStringKey(actionKey), systemImage: actionIcon)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, MorySpacing.small)
        .accessibilityElement(children: .combine)
    }

    private var actionIcon: String {
        switch state.id {
        case .filteredMemories, .search: "xmark.circle"
        case .permissionDenied: "gearshape"
        case .processingFailed: "arrow.clockwise"
        default: "plus.circle"
        }
    }
}
