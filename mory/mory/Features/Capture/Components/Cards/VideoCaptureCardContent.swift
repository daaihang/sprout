import SwiftUI
import UIKit

struct VideoCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureVideoCardPayload
    let context: CaptureCardRenderContext
    let accent: Color
    let highContrast: Bool

    var body: some View {
        ZStack {
            background
            Image(systemName: "play.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Color.black.opacity(highContrast ? 0.62 : 0.42), in: Circle())
                .shadow(color: .black.opacity(0.24), radius: 8, y: 3)

            if let duration = payload.durationSeconds {
                Text(duration.formattedCaptureDuration)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(highContrast ? 0.68 : 0.46), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(10)
            }
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
