import SwiftUI

struct HomeBoardOrderControls {
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let moveEarlier: () -> Void
    let moveLater: () -> Void
}

private struct HomeBoardResizeMenu: View {
    let item: HomeBoardItemSnapshot
    let onResize: (HomeBoardSpan) -> Void

    var body: some View {
        Menu {
            ForEach(HomeBoardSpan.allowedSizes, id: \.self) { span in
                Button {
                    onResize(span)
                } label: {
                    Text(verbatim: "\(span.widthColumns)x\(span.heightUnits)")
                }
            }
        } label: {
            Label {
                Text(verbatim: "\(item.layout.span.widthColumns)x\(item.layout.span.heightUnits)")
            } icon: {
                Image(systemName: "rectangle.resize")
            }
        }
    }
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
                        preferenceMenu
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label(metadata.kindLabel, systemImage: metadata.iconName)
                        HStack {
                            if item.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            preferenceMenu
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

    private var preferenceMenu: some View {
        Menu {
            Button {
                isShowingReason = true
            } label: {
                Label {
                    Text(verbatim: "Explain why")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }

            if item.layout.layer == .suggestion {
                Button {
                    onPreference(item, .addToBoard)
                } label: {
                    Label {
                        Text(verbatim: "Add to board")
                    } icon: {
                        Image(systemName: "plus.square.on.square")
                    }
                }
            }

            Button {
                onPreference(item, .preferMore)
            } label: {
                Label {
                    Text(verbatim: "More like this")
                } icon: {
                    Image(systemName: "hand.thumbsup")
                }
            }

            Button {
                onPreference(item, .preferLess)
            } label: {
                Label {
                    Text(verbatim: "Less like this")
                } icon: {
                    Image(systemName: "hand.thumbsdown")
                }
            }

            if item.layout.feedbackAdjustment != 0 {
                Button {
                    onPreference(item, .resetFeedback)
                } label: {
                    Label {
                        Text(verbatim: "Reset feedback")
                    } icon: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }

            if item.cardKind != .clarificationQuestion {
                Button {
                    onPreference(item, .pin(!item.isPinned))
                } label: {
                    Label(item.isPinned ? "home.board.action.unpin" : "home.board.action.pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                }
            }

            if isEditing {
                if let orderControls {
                    Button {
                        orderControls.moveEarlier()
                    } label: {
                        Label {
                            Text(verbatim: "Move earlier")
                        } icon: {
                            Image(systemName: "arrow.up")
                        }
                    }
                    .disabled(!orderControls.canMoveEarlier)

                    Button {
                        orderControls.moveLater()
                    } label: {
                        Label {
                            Text(verbatim: "Move later")
                        } icon: {
                            Image(systemName: "arrow.down")
                        }
                    }
                    .disabled(!orderControls.canMoveLater)
                }

                HomeBoardResizeMenu(item: item) { span in
                    onPreference(item, .resize(span))
                }
            }

            Button(role: .destructive) {
                if case let .clarificationQuestion(question, _) = item.renderValue {
                    onDismissQuestion(question)
                } else {
                    onPreference(item, item.layout.layer == .suggestion ? .dismiss : .hide)
                }
            } label: {
                Label(item.layout.layer == .suggestion || item.cardKind == .clarificationQuestion ? "home.board.action.dismiss" : "home.board.action.hide", systemImage: "eye.slash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.button)
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
