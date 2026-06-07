import SwiftUI
import UIKit

struct LivePhotoCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureLivePhotoCardPayload
    let context: CaptureCardRenderContext
    let accent: Color
    let highContrast: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background
            Image(systemName: "livephoto")
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .padding(7)
                .background(Color.black.opacity(highContrast ? 0.58 : 0.36), in: Circle())
                .padding(9)
            CaptureCardMediaStackBadge(count: payload.mediaCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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
