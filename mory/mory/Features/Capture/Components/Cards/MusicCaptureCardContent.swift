import SwiftUI
import UIKit

struct MusicCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureMusicCardPayload
    let accent: Color
    let palette: CaptureCardPalette
    let highContrast: Bool

    var body: some View {
        ZStack {
            musicBackground

            HStack(alignment: .center, spacing: 10) {
                compactArtwork(size: 48)

                VStack(alignment: .leading, spacing: 5) {
                    Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.music"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(coverLegibility.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                    Text(common.detail)
                        .font(.caption)
                        .foregroundStyle(coverLegibility.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .shadow(color: coverLegibility.shadow, radius: 3, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func compactArtwork(size: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
            artworkImageView(contentMode: .fill)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size >= 50 ? 12 : 10, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if musicState == .playing && payload.hasArtwork {
                MusicEqualizerView(isPlaying: true, accent: .white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.34), in: Capsule())
                    .padding(5)
            }
        }
    }

    private var musicCoverScrimColors: [Color] {
        coverLegibility.scrimColors
    }

    private var coverLegibility: CaptureCardLegibility {
        if payload.artworkData != nil {
            return CaptureCardLegibility.imageData(payload.artworkData, highContrast: highContrast)
        }
        return CaptureCardLegibility.palette(palette, highContrast: highContrast)
    }

    private var musicBackground: some View {
        ZStack {
            LinearGradient(colors: palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
            artworkBackgroundImage
                .scaleEffect(1.24)
                .blur(radius: 16)
                .saturation(1.08)
                .opacity(0.62)
            LinearGradient(
                colors: musicCoverScrimColors,
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var artworkBackgroundImage: some View {
        if let image = payload.artworkImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let artworkURL = payload.artworkURL, let url = URL(string: artworkURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                default:
                    Color.clear
                }
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func artworkImageView(contentMode: ContentMode) -> some View {
        if let image = payload.artworkImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let artworkURL = payload.artworkURL, let url = URL(string: artworkURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                default:
                    musicPlaceholder
                }
            }
        } else {
            musicPlaceholder
        }
    }

    private var musicState: CaptureMusicPlaybackState {
        payload.playbackState ?? (common.origin == .context ? .playing : .searchResult)
    }

    private var musicPlaceholder: some View {
        Image(systemName: "music.note")
            .font(.title2.weight(.bold))
            .foregroundStyle(palette.primaryText.opacity(0.92))
    }
}

private extension CaptureMusicCardPayload {
    var artworkImage: UIImage? {
        guard let artworkData else { return nil }
        return UIImage(data: artworkData)
    }

    var hasArtwork: Bool {
        artworkURL?.trimmedOrNil != nil || artworkData != nil
    }
}

private struct MusicEqualizerView: View {
    let isPlaying: Bool
    let accent: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    let animatedHeight = 7 + abs(sin(time * 2.6 + Double(index))) * 11
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(accent.opacity(isPlaying ? 0.76 : 0.34))
                        .frame(width: 3, height: isPlaying ? animatedHeight : CGFloat([8, 13, 10, 15, 9][index]))
                }
            }
        }
        .frame(width: 28, height: 18, alignment: .bottom)
    }
}
