import SwiftUI

struct HomeBoardCardContent: View {
    let item: HomeBoardItemSnapshot
    let onSelect: (HomeRoute) -> Void
    let onAnswerQuestion: (ClarificationQuestion, ClarificationAnswer) -> Void
    let onDismissQuestion: (ClarificationQuestion) -> Void
    let onSystemAction: () -> Void

    var body: some View {
        switch item.renderValue {
        case let .memory(memory):
            Button {
                onSelect(.memory(memory.record.id))
            } label: {
                MemoryBoardCard(memory: memory, reason: item.reason)
            }
            .buttonStyle(.plain)

        case let .arc(arc):
            Button {
                onSelect(.arc(arc.id))
            } label: {
                ArcBoardCard(arc: arc, reason: item.reason)
            }
            .buttonStyle(.plain)

        case let .reflection(reflection):
            Button {
                onSelect(.reflection(reflection.id))
            } label: {
                ReflectionBoardCard(reflection: reflection, reason: item.reason)
            }
            .buttonStyle(.plain)

        case let .clarificationQuestion(question, profile):
            ClarificationQuestionCard(
                question: question,
                profile: profile,
                onAnswer: { answer in
                    onAnswerQuestion(question, answer)
                },
                onDismiss: {
                    onDismissQuestion(question)
                }
            )

        case let .yesterdayPanel(title, subtitle, sourceRecordIDs):
            YesterdayPanelBoardCard(
                title: title,
                subtitle: subtitle,
                recordCount: sourceRecordIDs.count
            )

        case let .systemPrompt(title, subtitle, actionTitle):
            SystemPromptBoardCard(
                title: title,
                subtitle: subtitle,
                actionTitle: actionTitle,
                onAction: onSystemAction
            )

        case let .contextCluster(title, subtitle, sourceRecordIDs):
            ContextClusterBoardCard(
                title: title,
                subtitle: subtitle,
                recordCount: sourceRecordIDs.count
            )

        case let .pendingAction(title, subtitle, targetRecordID):
            Button {
                if let targetRecordID {
                    onSelect(.memory(targetRecordID))
                }
            } label: {
                PendingActionBoardCard(title: title, subtitle: subtitle)
            }
            .buttonStyle(.plain)
        }
    }
}
