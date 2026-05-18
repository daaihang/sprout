import SwiftUI

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
    let item: HomeBoardItemSnapshot
    let isEditing: Bool
    let onSelect: (HomeRoute) -> Void
    let onPreference: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void
    let onAnswerQuestion: (ClarificationQuestion, ClarificationAnswer) -> Void
    let onDismissQuestion: (ClarificationQuestion) -> Void
    let onSystemAction: () -> Void

    var body: some View {
        HomeBoardCardChrome {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        Label(cardLabel, systemImage: cardIcon)
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        preferenceMenu
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label(cardLabel, systemImage: cardIcon)
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
                    YesterdayPanelBoardCard(title: title, subtitle: subtitle, recordCount: sourceRecordIDs.count)
                case let .systemPrompt(title, subtitle, actionTitle):
                    SystemPromptBoardCard(
                        title: title,
                        subtitle: subtitle,
                        actionTitle: actionTitle,
                        onAction: onSystemAction
                    )
                case let .contextCluster(title, subtitle, sourceRecordIDs):
                    ContextClusterBoardCard(title: title, subtitle: subtitle, recordCount: sourceRecordIDs.count)
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
        .accessibilityElement(children: .combine)
    }

    private var preferenceMenu: some View {
        Menu {
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

            if item.cardKind != .clarificationQuestion {
                Button {
                    onPreference(item, .pin(!item.isPinned))
                } label: {
                    Label(item.isPinned ? "home.board.action.unpin" : "home.board.action.pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                }
            }

            if isEditing {
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

    private var cardLabel: String {
        switch item.cardKind {
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

    private var cardIcon: String {
        switch item.cardKind {
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

private struct MemoryBoardCard: View {
    let memory: MemorySummary
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(memory.title).font(.headline).lineLimit(2)
            Text(memory.summaryText).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            if let contextSummary {
                Text(contextSummary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack {
                Text(reason)
                Spacer()
                Text(memory.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var contextSummary: String? {
        memory.contextArtifacts
            .map(\.summary)
            .compactMap(\.trimmedOrNil)
            .prefix(3)
            .joined(separator: " | ")
            .trimmedOrNil
    }
}

private struct ArcBoardCard: View {
    let arc: TemporalArc
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(arc.title).font(.headline).lineLimit(2)
            Text(arc.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            HStack {
                Text("home.board.arc.ongoing \(arc.sourceRecordIDs.count)")
                Spacer()
                Text(reason)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct ReflectionBoardCard: View {
    let reflection: ReflectionSnapshot
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reflection.title).font(.headline).lineLimit(2)
            Text(reflection.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            HStack {
                Text(reflection.statusLabel)
                Spacer()
                Text(reason)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct YesterdayPanelBoardCard: View {
    let title: String
    let subtitle: String
    let recordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(.headline)
                .lineLimit(2)
            Text(verbatim: subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text(verbatim: "\(recordCount) items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SystemPromptBoardCard: View {
    let title: String
    let subtitle: String
    let actionTitle: String?
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            if let actionTitle {
                Button(actionTitle, action: onAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct ContextClusterBoardCard: View {
    let title: String
    let subtitle: String
    let recordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            Text("home.board.cluster.count \(recordCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PendingActionBoardCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
        }
    }
}
