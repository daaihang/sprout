import SwiftUI

struct TemporalArcsListView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    let arcs: [TemporalArc]
    @State private var selectedStatus: TemporalArcStatus? = nil

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            List(filteredArcs) { arc in
                Button {
                    selection.selectedEntity = .arc(arc.id)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(arc.title)
                            Spacer()
                            Text(arc.status.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(statusColor(for: arc.status))
                        }

                        Text(arc.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        Text("\(arc.sourceRecordIDs.count) records • \(arc.themeLabels.prefix(2).joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredArcs: [TemporalArc] {
        arcs.filter { arc in
            selectedStatus.map { arc.status == $0 } ?? true
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Temporal Arcs")
                    .font(.headline)
                Spacer()
                Text("\(workspace.temporalArcs.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statusChip(title: "All", isActive: selectedStatus == nil) {
                        selectedStatus = nil
                    }
                    ForEach(TemporalArcStatus.allCases, id: \.self) { status in
                        statusChip(title: status.rawValue.capitalized, isActive: selectedStatus == status) {
                            selectedStatus = status
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
    }

    private func statusChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func statusColor(for status: TemporalArcStatus) -> Color {
        switch status {
        case .candidate:
            .secondary
        case .accepted:
            .green
        case .archived:
            .orange
        }
    }
}
