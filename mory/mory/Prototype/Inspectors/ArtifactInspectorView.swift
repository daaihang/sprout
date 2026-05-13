import SwiftUI

struct ArtifactInspectorView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    let artifact: Artifact

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Artifact")
                .font(.headline)
            LabeledContent("Type", value: artifact.kind.displayName)
            LabeledContent("Title", value: artifact.title)
            Text(artifact.summary)
                .font(.body)
            if !artifact.textContent.isEmpty {
                Divider()
                Text(artifact.textContent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !linkedEntities.isEmpty {
                Divider()
                Text("Linked Entities")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(linkedEntities) { entity in
                    Text("\(entity.kind.displayName): \(entity.displayName)")
                        .font(.caption)
                }
            }
            Spacer()
        }
    }

    private var linkedEntities: [EntityNode] {
        workspace.linkedEntities(forArtifactID: artifact.id)
    }
}
