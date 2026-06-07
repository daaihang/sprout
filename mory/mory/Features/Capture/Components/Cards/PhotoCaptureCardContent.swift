import SwiftUI
import UIKit

struct PhotoCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePhotoCardPayload
    let accent: Color
    let highContrast: Bool

    var body: some View {
        if payload.photoCount > 1 {
            photoGroupContent
        } else {
            singlePhotoContent
        }
    }

    private var singlePhotoContent: some View {
        ZStack(alignment: .bottomLeading) {
            photoBackground
            photoScrim
            titleBlock(legibility: legibility)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
    }

    private var photoGroupContent: some View {
        ZStack(alignment: .bottomLeading) {
            mosaicBackground

            photoScrim
            VStack(alignment: .leading, spacing: 5) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.photos"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(String(format: String(localized: "capture.card.photo.count.format"), payload.photoCount))
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(legibility.primaryText)
            .shadow(color: legibility.shadow, radius: 3, y: 1)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var photoBackground: some View {
        if let image = payload.thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(colors: [accent.opacity(0.8), .orange.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var mosaicBackground: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                sampleTile(index: 0)
                    .frame(width: width * 0.58, height: height)
                    .position(x: width * 0.29, y: height * 0.5)
                VStack(spacing: 2) {
                    sampleTile(index: 1)
                    sampleTile(index: 2)
                }
                .frame(width: width * 0.42, height: height)
                .position(x: width * 0.79, y: height * 0.5)
            }
        }
    }

    private func sampleTile(index: Int) -> some View {
        ZStack {
            sampleGradient(index: index)
            if let image = payload.thumbnailImage, index == 0 {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .clipped()
    }

    private func sampleGradient(index: Int) -> LinearGradient {
        let palettes: [[Color]] = [
            [accent.opacity(0.92), .orange.opacity(0.76)],
            [.pink.opacity(0.82), .purple.opacity(0.62)],
            [.teal.opacity(0.75), .blue.opacity(0.58)],
            [.indigo.opacity(0.72), accent.opacity(0.42)],
        ]
        let colors = palettes[index % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var photoScrim: some View {
        LinearGradient(
            colors: legibility.scrimColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.imageData(payload.thumbnailData, highContrast: highContrast)
    }

    private func titleBlock(legibility: CaptureCardLegibility) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.photo"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(common.detail)
                .font(.caption)
                .lineLimit(2)
        }
        .foregroundStyle(legibility.primaryText)
        .shadow(color: legibility.shadow, radius: 3, y: 1)
    }
}

private extension CapturePhotoCardPayload {
    var thumbnailImage: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }
}
