import SwiftUI

struct RecordInspectorView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    let record: RecordShell

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Record")
                .font(.headline)
            Text(record.rawText)
                .font(.body)
            LabeledContent("Source", value: record.captureSource.rawValue)
            LabeledContent("Mood", value: record.userMood ?? "-")
            LabeledContent("Intensity", value: record.userIntensity.map(String.init) ?? "-")
            if !linkedEntities.isEmpty {
                Divider()
                Text("Graph Seeds")
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
        workspace.linkedEntities(forRecordID: record.id)
    }
}
