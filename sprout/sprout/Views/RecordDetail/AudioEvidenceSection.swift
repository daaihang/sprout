import SwiftUI

/// Dedicated view for displaying audio evidence in a record's detail page.
/// Extracted from RecordDetailView to improve maintainability and reusability.
@MainActor
struct AudioEvidenceSection: View {
    @Environment(AppLocalization.self) private var localization
    
    let artifact: Artifact?
    let audioDurationString: (Data?) -> String
    
    var body: some View {
        if let artifact {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "waveform", title: localization.string("detail.section.audio", default: "Voice"))
                AudioCard(
                    data: AudioCardData(
                        title: nonEmpty(artifact.title) ?? "",
                        audioData: artifact.binaryPayload,
                        transcriptPreview: nonEmpty(artifact.textContent) ?? "",
                        durationText: audioDurationString(artifact.binaryPayload),
                        capturedAt: artifact.createdAt
                    )
                )
                .frame(height: 180)
            }
            .detailCard()
        }
    }
}

// MARK: - Helper

private func nonEmpty(_ str: String?) -> String? {
    guard let str = str, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return str
}
