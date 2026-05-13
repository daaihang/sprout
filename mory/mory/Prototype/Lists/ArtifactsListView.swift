import SwiftUI

struct ArtifactsListView: View {
    @Environment(PrototypeSelectionStore.self) private var selection
    let artifacts: [Artifact]

    var body: some View {
        List(artifacts) { artifact in
            Button {
                selection.selectedEntity = .artifact(artifact.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artifact.title)
                        Text(artifact.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(artifact.kind.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
