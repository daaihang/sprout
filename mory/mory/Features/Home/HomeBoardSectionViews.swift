import SwiftUI

struct HomeBoardSection: View {
    let board: HomeBoardSnapshot
    let isEditing: Bool
    let onSelect: (HomeRoute) -> Void
    let onPreference: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void
    let onShowActions: (HomeBoardItemSnapshot) -> Void
    let onReorder: ([HomeBoardOrderUpdate]) -> Void
    let onAnswerQuestion: (ClarificationQuestion, ClarificationAnswer) -> Void
    let onDismissQuestion: (ClarificationQuestion) -> Void
    let onSystemAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MorySpacing.large) {
            if !board.userBoardItems.isEmpty {
                HomeBoardMasonry(
                    items: board.userBoardItems,
                    isEditing: isEditing,
                    onSelect: onSelect,
                    onPreference: onPreference,
                    onShowActions: onShowActions,
                    onReorder: onReorder,
                    onAnswerQuestion: onAnswerQuestion,
                    onDismissQuestion: onDismissQuestion,
                    onSystemAction: onSystemAction
                )
            }

            if !board.suggestionItems.isEmpty {
                VStack(alignment: .leading, spacing: MorySpacing.small) {
                    Text(verbatim: "Suggestions")
                        .font(.headline)
                    HomeBoardMasonry(
                        items: board.suggestionItems,
                        isEditing: isEditing,
                        onSelect: onSelect,
                        onPreference: onPreference,
                        onShowActions: onShowActions,
                        onReorder: onReorder,
                        onAnswerQuestion: onAnswerQuestion,
                        onDismissQuestion: onDismissQuestion,
                        onSystemAction: onSystemAction
                    )
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
}

struct HomeBoardMasonry: View {
    let items: [HomeBoardItemSnapshot]
    let isEditing: Bool
    let onSelect: (HomeRoute) -> Void
    let onPreference: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void
    let onShowActions: (HomeBoardItemSnapshot) -> Void
    let onReorder: ([HomeBoardOrderUpdate]) -> Void
    let onAnswerQuestion: (ClarificationQuestion, ClarificationAnswer) -> Void
    let onDismissQuestion: (ClarificationQuestion) -> Void
    let onSystemAction: () -> Void

    var body: some View {
        HomeBoardMasonryLayout(metrics: metrics) {
            ForEach(items) { item in
                HomeBoardCard(
                    item: item,
                    isEditing: isEditing,
                    orderControls: orderControls(for: item),
                    onSelect: onSelect,
                    onPreference: onPreference,
                    onShowActions: onShowActions,
                    onAnswerQuestion: onAnswerQuestion,
                    onDismissQuestion: onDismissQuestion,
                    onSystemAction: onSystemAction
                )
                .zIndex(Double(item.compositionItem.zIndex))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: items.map(\.compositionItem.itemKey))
    }

    private var metrics: MoryMasonryMetrics {
        MoryMasonryMetrics.homeBoard
    }

    private func orderControls(for item: HomeBoardItemSnapshot) -> HomeBoardOrderControls? {
        guard isEditing, item.layout.layer == .userBoard else { return nil }
        return HomeBoardOrderControls(
            canMoveEarlier: HomeBoardOrdering.canMove(item: item, in: items, direction: .earlier),
            canMoveLater: HomeBoardOrdering.canMove(item: item, in: items, direction: .later),
            moveEarlier: {
                onReorder(HomeBoardOrdering.updatesForMove(items: items, moving: item, direction: .earlier))
            },
            moveLater: {
                onReorder(HomeBoardOrdering.updatesForMove(items: items, moving: item, direction: .later))
            }
        )
    }
}
