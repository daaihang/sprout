import SwiftUI
import UIKit

struct PhotoCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePhotoCardPayload
    let context: CaptureCardRenderContext
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
        ZStack {
            photoBackground
            CaptureCardMediaStackBadge(count: payload.photoCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private var photoGroupContent: some View {
        ZStack {
            mosaicBackground
            CaptureCardMediaStackBadge(count: payload.photoCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.imageData(payload.thumbnailData, highContrast: highContrast)
    }
}

private extension CapturePhotoCardPayload {
    var thumbnailImage: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }
}
