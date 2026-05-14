import SwiftUI

/// Dedicated view for displaying todo evidence in a record's detail page.
/// Extracted from RecordDetailView to improve maintainability and reusability.
@MainActor
struct TodoEvidenceSection: View {
    @Environment(AppLocalization.self) private var localization
    
    let artifact: Artifact?
    
    var body: some View {
        if let artifact = artifact {
            let items = decodedTodoItems(from: artifact.textContent)
            if !items.isEmpty {
                todoCard(title: nonEmpty(artifact.title) ?? localization.string("detail.todo.default_title", default: "To-Do"),
                         items: items)
            }
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
            Text(localization.string("detail.todo.completed", default: "%d/%d completed", arguments: [doneCount, items.count]))
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
