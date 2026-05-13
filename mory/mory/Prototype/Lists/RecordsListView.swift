import SwiftUI

struct RecordsListView: View {
    @Environment(PrototypeSelectionStore.self) private var selection
    let records: [RecordShell]

    var body: some View {
        List(records) { record in
            Button {
                selection.selectedEntity = .record(record.id)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.rawText)
                        .lineLimit(2)
                    Text(record.captureSource.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
