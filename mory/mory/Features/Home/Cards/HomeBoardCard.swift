import SwiftUI

struct HomeBoardOrderControls {
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let moveEarlier: () -> Void
    let moveLater: () -> Void
}

private struct HomeBoardCardChrome<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct HomeBoardCard: View {
    @State private var isShowingReason = false

    let item: HomeBoardItemSnapshot
    let isEditing: Bool
    let orderControls: HomeBoardOrderControls?
    let onSelect: (HomeRoute) -> Void
    let onPreference: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void
    let onShowActions: (HomeBoardItemSnapshot) -> Void
    let onAnswerQuestion: (ClarificationQuestion, ClarificationAnswer) -> Void
    let onDismissQuestion: (ClarificationQuestion) -> Void
    let onSystemAction: () -> Void

    var body: some View {
        let metadata = HomeBoardCardMetadata(item: item)

        HomeBoardCardChrome {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        Label(metadata.kindLabel, systemImage: metadata.iconName)
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        actionsButton
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label(metadata.kindLabel, systemImage: metadata.iconName)
                        HStack {
                            if item.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            actionsButton
                        }
                    }
                }

                HomeBoardCardContent(
                    item: item,
                    onSelect: onSelect,
                    onAnswerQuestion: onAnswerQuestion,
                    onDismissQuestion: onDismissQuestion,
                    onSystemAction: onSystemAction
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: metadata.accessibilityLabel))
        .accessibilityHint(Text(verbatim: metadata.accessibilityHint))
        .accessibilityAction(named: Text(verbatim: "Explain why")) {
            isShowingReason = true
        }
        .accessibilityAction(named: Text(verbatim: item.isPinned ? "Unpin card" : "Pin card")) {
            guard item.cardKind != .clarificationQuestion else { return }
            onPreference(item, .pin(!item.isPinned))
        }
        .accessibilityAction(named: Text(verbatim: item.layout.layer == .suggestion || item.cardKind == .clarificationQuestion ? "Dismiss card" : "Hide card")) {
            if case let .clarificationQuestion(question, _) = item.renderValue {
                onDismissQuestion(question)
            } else {
                onPreference(item, item.layout.layer == .suggestion ? .dismiss : .hide)
            }
        }
        .accessibilityAdjustableAction { direction in
            guard isEditing, let orderControls else { return }
            switch direction {
            case .increment:
                guard orderControls.canMoveLater else { return }
                orderControls.moveLater()
            case .decrement:
                guard orderControls.canMoveEarlier else { return }
                orderControls.moveEarlier()
            @unknown default:
                break
            }
        }
        .alert(Text(verbatim: "Why this appears"), isPresented: $isShowingReason) {
            Button {
            } label: {
                Text(verbatim: "OK")
            }
        } message: {
            Text(verbatim: reasonDetail)
        }
    }

    private var actionsButton: some View {
        Button {
            onShowActions(item)
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "More actions"))
    }

    private var reasonDetail: String {
        var lines = [item.reason.ifEmpty("recent activity")]
        if !item.sourceRecordIDs.isEmpty {
            lines.append("\(item.sourceRecordIDs.count) source memories")
        }
        if item.layout.feedbackAdjustment > 0 {
            lines.append("You asked for more like this.")
        } else if item.layout.feedbackAdjustment < 0 {
            lines.append("You asked for less like this.")
        }
        return lines.joined(separator: "\n")
    }

}
