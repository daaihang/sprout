import SwiftUI

struct ReflectionsListView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    let reflections: [ReflectionSnapshot]

    var body: some View {
        List(reflections) { reflection in
            Button {
                selection.selectedEntity = .reflection(reflection.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reflection.title)
                    Text(reflection.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(highlightColor(for: reflection), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private func highlightColor(for reflection: ReflectionSnapshot) -> Color {
        guard let lastAnalyzedRecordID = workspace.lastAnalyzedRecordID else { return .clear }
        return reflection.sourceRecordIDs.contains(lastAnalyzedRecordID)
            ? Color.accentColor.opacity(0.14)
            : .clear
    }
}
