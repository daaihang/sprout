import SwiftUI

struct AudioCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureAudioCardPayload
    let context: CaptureCardRenderContext
    let accent: Color

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: "play.fill",
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.audio"),
                subtitle: payload.durationSeconds.map(formatDuration) ?? String(localized: "capture.card.audio.original"),
                accent: accent
            )
        } else {
            CaptureCardTextPanel(
                iconName: transcriptIsAvailable ? "text.quote" : "waveform",
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.audio"),
                detail: transcriptPreview,
                metadata: payload.durationSeconds.map(formatDuration) ?? common.metadata,
                context: context,
                accent: accent
            )
        }
    }

    private var transcriptPreview: String {
        guard let detail = common.detail.trimmedOrNil, detail != String(localized: "capture.card.audio.attached") else {
            return String(localized: "capture.card.audio.originalAttached")
        }
        return detail
    }

    private var transcriptIsAvailable: Bool {
        common.detail.trimmedOrNil != nil && common.detail != String(localized: "capture.card.audio.attached")
    }
}

private func formatDuration(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    return "\(minutes):\(String(format: "%02d", remainder))"
}
