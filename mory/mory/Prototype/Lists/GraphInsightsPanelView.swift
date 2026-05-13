import SwiftUI

struct GraphInsightsPanelView: View {
    @Environment(PrototypeSelectionStore.self) private var selection
    let insights: GraphInsightsSnapshot

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                insightCard(title: "Recent Entities") {
                    entityInsightRows(insights.recentEntities)
                }
                insightCard(title: "Top People") {
                    entityInsightRows(insights.topPeople)
                }
                insightCard(title: "Top Themes") {
                    entityInsightRows(insights.topThemes)
                }
                insightCard(title: "Hot Relations") {
                    edgeInsightRows(insights.hotEdges)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.thinMaterial)
    }

    private func insightCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .frame(width: 220, alignment: .topLeading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func entityInsightRows(_ rows: [GraphEntityInsight]) -> some View {
        if rows.isEmpty {
            Text("No entities yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(rows) { row in
                Button {
                    selection.route = .entities
                    selection.selectedEntity = .entity(row.entityID)
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.displayName)
                            Text(row.kind.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(row.mentionCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func edgeInsightRows(_ rows: [GraphEdgeInsight]) -> some View {
        if rows.isEmpty {
            Text("No relations yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(rows) { row in
                Button {
                    selection.route = .entities
                    selection.selectedEntity = .entity(row.fromEntityID)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(row.fromDisplayName) ↔ \(row.toDisplayName)")
                            .lineLimit(1)
                        Text(row.relationKind.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("evidence \(row.evidenceCount) • \(row.weight.formatted(.number.precision(.fractionLength(1))))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
