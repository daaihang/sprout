import SwiftUI
import UIKit

struct FilmFrameCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureVideoCardPayload
    let accent: Color

    var body: some View {
        VStack(spacing: 0) {
            perforatedStrip
            frameBody
            perforatedStrip
        }
        .padding(7)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.08), radius: 9, y: 4)
    }

    private var frameBody: some View {
        ZStack(alignment: .bottomLeading) {
            thumbnail
                .frame(width: 214, height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

            playBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.video"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(common.detail)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = payload.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [accent.opacity(0.52), Color.black.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(systemName: "video.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
    }

    private var playBadge: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: 1)
            }
            .frame(width: 214, height: 118)
    }

    private var perforatedStrip: some View {
        HStack(spacing: 7) {
            ForEach(0..<9, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white.opacity(0.68))
                    .frame(width: 12, height: 6)
            }
        }
        .frame(width: 214, height: 12)
    }
}

struct LivePhotoPrintCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureLivePhotoCardPayload
    let accent: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            backPrint
                .offset(x: 8, y: 8)
                .rotationEffect(.degrees(3))

            frontPrint

            Image(systemName: "livephoto")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .padding(7)
                .background(.white.opacity(0.88), in: Circle())
                .padding(12)
        }
    }

    private var frontPrint: some View {
        VStack(spacing: 0) {
            thumbnail
                .frame(width: 152, height: 152)
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.livePhoto"))
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .lineLimit(1)
                Text(common.detail)
                    .font(.system(size: 9, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 152, height: 40, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .padding(EdgeInsets(top: 9, leading: 9, bottom: 5, trailing: 9))
        .background(.white, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .rotationEffect(.degrees(-1.5))
    }

    private var backPrint: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color(red: 0.88, green: 0.90, blue: 0.92))
            .frame(width: 170, height: 206)
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = payload.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [accent.opacity(0.24), Color(.systemGray5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "livephoto")
                    .font(.largeTitle)
                    .foregroundStyle(accent.opacity(0.72))
            }
        }
    }
}
