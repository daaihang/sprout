import SwiftUI

struct AnalysisInspectorView: View {
    let analysis: RecordAnalysisSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Analysis")
                .font(.headline)
            LabeledContent("Emotion", value: analysis.emotionLabel)
            LabeledContent("Tags", value: analysis.tags.joined(separator: ", "))
            if !analysis.entities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Entities")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(analysis.entities) { entity in
                        Text("\(entity.kind.displayName): \(entity.name)")
                            .font(.caption)
                    }
                }
            }
            Text(analysis.insight)
                .font(.body)
            if let followUpQuestion = analysis.followUpQuestion {
                Divider()
                Text(followUpQuestion)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
