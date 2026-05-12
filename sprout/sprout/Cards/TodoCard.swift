import SwiftUI

struct TodoItem: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var isDone: Bool = false
}

struct TodoCardData {
    var title: String = ""
    var items: [TodoItem] = []

    var isEmpty: Bool { items.isEmpty }
    var doneCount: Int { items.filter(\.isDone).count }
    var totalCount: Int { items.count }
    var progress: Double { isEmpty ? 0 : Double(doneCount) / Double(totalCount) }
}

struct TodoCard: View {
    var data: TodoCardData?
    var onTap: (() -> Void)?

    var body: some View {
        AdaptiveCardRoot(content: todoContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    private var todoContent: AdaptiveCardContent? {
        guard let data, !data.isEmpty else { return nil }

        let visibleItems = Array(data.items.prefix(5)).map { item in
            AdaptiveCardListItem(
                systemImage: item.isDone ? "checkmark.square.fill" : "square",
                symbolColor: item.isDone ? .green : .secondary,
                title: item.text,
                emphasis: !item.isDone
            )
        }

        return AdaptiveCardContent(
            preferredLayout: .stackedInfo,
            accent: .accentColor,
            visual: .symbol("checklist", tint: .accentColor, renderingMode: .hierarchical),
            title: data.title.isEmpty ? localizedString("card.todo.title", default: "To-Do") : data.title,
            subtitle: localizedString("card.todo.progress", default: "%d of %d done", arguments: [data.doneCount, data.totalCount]),
            badge: AdaptiveCardBadge(text: "\(data.doneCount)/\(data.totalCount)", systemImage: "checkmark"),
            progress: AdaptiveCardProgress(
                value: data.progress,
                label: localizedString("card.todo.completion", default: "Completion"),
                trailingText: "\(Int(data.progress * 100))%"
            ),
            listItems: visibleItems,
            footer: data.totalCount > visibleItems.count
                ? localizedString("card.todo.remaining", default: "%d more…", arguments: [data.totalCount - visibleItems.count])
                : nil
        )
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(localizedString("card.todo.placeholder", default: "Tap to add a to-do"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
