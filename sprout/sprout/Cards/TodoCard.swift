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
    let size: CardSize
    var data: TodoCardData?
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let data, !data.isEmpty {
                contentView(data)
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    @ViewBuilder
    private func contentView(_ data: TodoCardData) -> some View {
        if size == .w4h1 {
            HStack(spacing: 10) {
                Image(systemName: data.doneCount == data.totalCount ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundStyle(data.doneCount == data.totalCount ? .green : .secondary)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    if !data.title.isEmpty {
                        Text(data.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Text("\(data.doneCount)/\(data.totalCount) 已完成")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: geo.size.width, height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * data.progress, height: 6)
                    }
                }
                .frame(width: 40, height: 6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else if size == .w4h2 {
            VStack(alignment: .leading, spacing: 6) {
                if !data.title.isEmpty {
                    Text(data.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                ForEach(data.items.prefix(3)) { item in
                    todoRow(item, compact: true)
                }
                if data.totalCount > 3 {
                    Text("还有 \(data.totalCount - 3) 项...")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                progressBar(data)
            }
            .padding(12)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if !data.title.isEmpty {
                        Text(data.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(data.doneCount)/\(data.totalCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                progressBar(data)
                Divider()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(data.items) { item in
                            todoRow(item, compact: false)
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
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

    @ViewBuilder
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

    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: size == .w4h1 ? 4 : 8) {
            Image(systemName: "checklist")
                .font(.system(size: size == .w4h1 ? 20 : 30))
                .foregroundStyle(.secondary.opacity(0.4))
            if size != .w4h1 {
                Text("点击添加待办")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TodoCard_4x1: View {
    var data: TodoCardData?
    var onTap: (() -> Void)?
    var body: some View { TodoCard(size: .w4h1, data: data, onTap: onTap) }
}

struct TodoCard_4x2: View {
    var data: TodoCardData?
    var onTap: (() -> Void)?
    var body: some View { TodoCard(size: .w4h2, data: data, onTap: onTap) }
}

struct TodoCard_4x4: View {
    var data: TodoCardData?
    var onTap: (() -> Void)?
    var body: some View { TodoCard(size: .w4h4, data: data, onTap: onTap) }
}

#Preview {
    VStack(spacing: 12) {
        TodoCard_4x1(data: {
            var d = TodoCardData(title: "今日计划")
            d.items = [TodoItem(text: "晨跑", isDone: true), TodoItem(text: "读书"), TodoItem(text: "复盘")]
            return d
        }())
        TodoCard_4x2(data: {
            var d = TodoCardData(title: "购物清单")
            d.items = [TodoItem(text: "牛奶", isDone: true), TodoItem(text: "鸡蛋"), TodoItem(text: "蔬菜", isDone: true), TodoItem(text: "水果")]
            return d
        }())
        TodoCard_4x4(data: {
            var d = TodoCardData(title: "本周目标")
            d.items = [TodoItem(text: "完成项目报告", isDone: true), TodoItem(text: "健身 3 次"), TodoItem(text: "读完一本书", isDone: true), TodoItem(text: "学习新技能"), TodoItem(text: "整理房间")]
            return d
        }())
    }
    .frame(width: 393)
    .padding()
}
