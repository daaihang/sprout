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
        Group {
            if let data, !data.isEmpty {
                GeometryReader { geo in
                    contentView(data, metrics: CardLayoutMetrics(containerSize: geo.size))
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    private func contentView(_ data: TodoCardData, metrics: CardLayoutMetrics) -> some View {
        let visibleItems = metrics.isTallHeight ? 6 : (metrics.isMediumHeight ? 3 : 1)

        return VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 6 : 10) {
            HStack {
                if !data.title.isEmpty {
                    Text(data.title)
                        .font(.system(size: metrics.isCompactHeight ? 12 : 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(data.doneCount)/\(data.totalCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            progressBar(data)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(data.items.prefix(visibleItems)) { item in
                    todoRow(item, compact: !metrics.isTallHeight)
                }
            }

            if data.totalCount > visibleItems {
                Text(localizedString("card.todo.remaining", default: "%d more…", arguments: [data.totalCount - visibleItems]))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(metrics.isCompactHeight ? 12 : 14)
    }

    private func todoRow(_ item: TodoItem, compact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                .foregroundStyle(item.isDone ? .green : .secondary)
                .font(.system(size: compact ? 12 : 14))
            Text(item.text)
                .font(.system(size: compact ? 11 : 13))
                .foregroundStyle(item.isDone ? .secondary : .primary)
                .strikethrough(item.isDone)
                .lineLimit(1)
        }
    }

    private func progressBar(_ data: TodoCardData) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(height: 5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * data.progress, height: 5)
            }
        }
        .frame(height: 5)
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
