import SwiftUI

struct EntitiesListView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    @State private var searchText = ""
    @State private var selectedKind: EntityKind? = nil

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            GraphInsightsPanelView(insights: workspace.graphInsights())
            List(filteredEntities) { entity in
                Button {
                    selection.selectedEntity = .entity(entity.id)
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entity.displayName)
                            Text(entity.kind.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !entity.summary.isEmpty {
                                Text(entity.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if let confidence = entity.confidence {
                            Text(confidence.formatted(.percent.precision(.fractionLength(0))))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredEntities: [EntityNode] {
        workspace.filteredEntityNodes(
            searchText: searchText,
            kind: selectedKind
        )
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search entities", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    kindChip(title: "All", isActive: selectedKind == nil) {
                        selectedKind = nil
                    }
                    ForEach(EntityKind.allCases) { kind in
                        kindChip(title: kind.displayName, isActive: selectedKind == kind) {
                            selectedKind = kind
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
    }

    private func kindChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
