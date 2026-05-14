import SwiftUI

/// Dedicated view for displaying audio evidence in a record's detail page.
/// Extracted from RecordDetailView to improve maintainability and reusability.
@MainActor
struct AudioEvidenceSection: View {
    @Environment(AppLocalization.self) private var localization
    
    let artifact: Artifact?
    let record: Record
    let legacyAudio: MediaCard?
    let audioDurationString: (Data?) -> String
    
    var body: some View {
        if let artifact {
            let audio = legacyAudio
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "waveform", title: localization.t("detail.section.audio", "Voice"))
                AudioCard(
                    data: AudioCardData(
                        title: nonEmpty(artifact.title) ?? audio?.title ?? "",
                        audioData: audio?.audioData,
                        transcriptPreview: nonEmpty(artifact.textContent) ?? audio?.caption ?? "",
                        durationText: audioDurationString(audio?.audioData),
                        capturedAt: artifact.createdAt
                    )
                )
                .frame(height: 180)
            }
            .detailCard()
        } else if let audio = legacyAudio {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "waveform", title: localization.t("detail.section.audio", "Voice"))
                AudioCard(
                    data: AudioCardData(
                        title: audio.title ?? "",
                        audioData: audio.audioData,
                        transcriptPreview: audio.caption ?? "",
                        durationText: audioDurationString(audio.audioData),
                        capturedAt: audio.capturedAt ?? record.createdAt
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
