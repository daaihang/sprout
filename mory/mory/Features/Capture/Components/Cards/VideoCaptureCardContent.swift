import SwiftUI
import UIKit

struct VideoCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureVideoCardPayload
    let accent: Color
    let highContrast: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            LinearGradient(
                colors: legibility.scrimColors,
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3.weight(.semibold))
                    if let duration = payload.durationSeconds {
                        Text(duration.formattedCaptureDuration)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                Text(common.title?.trimmedOrNil ?? "Video")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(common.detail)
                    .font(.caption)
                    .lineLimit(2)
            }
            .foregroundStyle(legibility.primaryText)
            .shadow(color: legibility.shadow, radius: 3, y: 1)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let image = payload.thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(colors: [.blue.opacity(0.76), accent.opacity(0.64)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "video.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.imageData(payload.thumbnailData, highContrast: highContrast)
    }
}

private extension CaptureVideoCardPayload {
    var thumbnailImage: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }
}

private extension Int {
    var formattedCaptureDuration: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
