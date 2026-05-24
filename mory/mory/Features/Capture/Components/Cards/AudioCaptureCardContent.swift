import SwiftUI

struct AudioCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureAudioCardPayload
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(accent, in: Circle())

                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.audio"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let duration = payload.durationSeconds {
                    Text(formatDuration(duration))
                        .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }

            Text(transcriptPreview)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: transcriptIsAvailable ? "text.quote" : "waveform")
                    .font(.caption2.weight(.semibold))
                Text(transcriptIsAvailable ? String(localized: "capture.card.audio.transcript") : String(localized: "capture.card.audio.original"))
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
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
