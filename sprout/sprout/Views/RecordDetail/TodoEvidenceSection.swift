import SwiftUI

/// Dedicated view for displaying todo evidence in a record's detail page.
/// Extracted from RecordDetailView to improve maintainability and reusability.
@MainActor
struct TodoEvidenceSection: View {
    @Environment(AppLocalization.self) private var localization
    
    let artifact: Artifact?
    let record: Record
    let legacyTodoPayload: (title: String, items: [TodoItem])?
    
    var body: some View {
        if let artifact = artifact {
            let items = decodedTodoItems(from: artifact.textContent)
            if !items.isEmpty {
                todoCard(title: nonEmpty(artifact.title) ?? localization.t("detail.todo.default_title", "To-Do"),
                         items: items)
            }
        } else if let payload = legacyTodoPayload {
            todoCard(title: payload.title, items: payload.items)
        }
    }
    
    private func todoCard(title: String, items: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "checklist", title: title)
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.isDone ? .green : .secondary)
                        .font(.system(size: 16))
                    Text(item.text)
                        .font(.body)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                        .strikethrough(item.isDone)
                }
            }
            let doneCount = items.filter(\.isDone).count
            Text(localization.t("detail.todo.completed", "%d/%d completed", doneCount, items.count))
                .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
        }
        .detailCard()
    }
    
    private func decodedTodoItems(from text: String) -> [TodoItem] {
        guard let raw = text.data(using: .utf8),
              let items = try? JSONDecoder().decode([TodoItem].self, from: raw) else {
            return []
        }
        return items
    }
}

// MARK: - Helper

private func nonEmpty(_ str: String?) -> String? {
    guard let str = str, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return str
}
