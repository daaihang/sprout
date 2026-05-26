import SwiftUI
import UIKit

struct LivePhotoCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureLivePhotoCardPayload
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
                    Image(systemName: "livephoto")
                        .font(.title3.weight(.semibold))
                    Text("Live Photo")
                        .font(.caption.weight(.semibold))
                }
                Text(common.title?.trimmedOrNil ?? "Live Photo")
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
            LinearGradient(colors: [.cyan.opacity(0.72), accent.opacity(0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "livephoto")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.imageData(payload.thumbnailData, highContrast: highContrast)
    }
}

private extension CaptureLivePhotoCardPayload {
    var thumbnailImage: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }
}
