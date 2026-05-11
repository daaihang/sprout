import SwiftUI
import MusicKit

struct MusicCardData {
    var trackName: String
    var artistName: String
    var albumName: String
    var albumArtworkURL: URL?
    var appleMusicURL: URL?
    var isPlaying: Bool

    init(
        trackName: String = "",
        artistName: String = "",
        albumName: String = "",
        albumArtworkURL: URL? = nil,
        appleMusicURL: URL? = nil,
        isPlaying: Bool = false
    ) {
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.albumArtworkURL = albumArtworkURL
        self.appleMusicURL = appleMusicURL
        self.isPlaying = isPlaying
    }

    var isEmpty: Bool {
        trackName.isEmpty && artistName.isEmpty
    }
}

struct MusicCard: View {
    var data: MusicCardData?
    var onTap: (() -> Void)?

    var body: some View {
        cardContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cardBackground()
            .onTapGesture {
                onTap?()
            }
    }

    @ViewBuilder
    private var cardContent: some View {
        if let data = data, !data.isEmpty {
            GeometryReader { geo in
                contentView(for: data, metrics: CardLayoutMetrics(containerSize: geo.size))
            }
        } else {
            placeholderContent
        }
    }

    private func contentView(for data: MusicCardData, metrics: CardLayoutMetrics) -> some View {
        let artworkSize = max(44, min(metrics.containerSize.height - 24, metrics.containerSize.width * (metrics.isCompactHeight ? 0.42 : 0.34)))

        return HStack(spacing: 12) {
            artworkView(for: data, artworkSize: artworkSize)
            if !metrics.isCompactHeight || metrics.isWideWidth {
                infoView(for: data, metrics: metrics)
            }
        }
        .padding(metrics.isCompactHeight ? 12 : 14)
    }

    @ViewBuilder
    private func artworkView(for data: MusicCardData, artworkSize: CGFloat) -> some View {
        ZStack {
            if let url = data.albumArtworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: artworkSize, height: artworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: artworkSize, height: artworkSize)
                        .overlay(
                            ProgressView()
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: artworkSize, height: artworkSize)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    )
            }

            if data.isPlaying {
                playingIndicator
                    .frame(width: artworkSize, height: artworkSize)
            }
        }
    }

    @ViewBuilder
    private var playingIndicator: some View {
        ZStack {
            Color.black.opacity(0.4)
            Image(systemName: "waveform")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func infoView(for data: MusicCardData, metrics: CardLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.trackName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(metrics.isTallHeight || metrics.isWideWidth ? 2 : 1)

            Text(data.artistName)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)

            if (metrics.isTallHeight || metrics.isWideWidth) && !data.albumName.isEmpty {
                Text(data.albumName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var placeholderContent: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.5))
                Text(localizedString("card.music.placeholder", default: "Tap to add music"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
