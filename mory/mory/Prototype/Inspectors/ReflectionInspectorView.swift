import SwiftUI

struct ReflectionInspectorView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    let reflection: ReflectionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reflection")
                .font(.headline)
            Text(reflection.title)
                .font(.title3.weight(.semibold))
            Text(reflection.body)
                .font(.body)
            LabeledContent("Type", value: reflection.type.rawValue)
            LabeledContent("Records", value: "\(reflection.sourceRecordIDs.count)")
            LabeledContent("Artifacts", value: "\(reflection.sourceArtifactIDs.count)")
            LabeledContent("Entities", value: "\(reflection.sourceEntityIDs.count)")

            if let linkedArc {
                Divider()
                Text("Linked Temporal Arc")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button {
                    selection.route = .arcs
                    selection.selectedEntity = .arc(linkedArc.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(linkedArc.title)
                        Text(linkedArc.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private var linkedArc: TemporalArc? {
        workspace.linkedTemporalArc(forReflectionID: reflection.id)
    }
}
