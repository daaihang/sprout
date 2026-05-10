import SwiftUI
import UIKit
import MusicKit

struct MusicCardData {
    var trackName: String
    var artistName: String
    var albumName: String
    var albumArtwork: UIImage?
    var appleMusicURL: URL?
    var isPlaying: Bool

    init(
        trackName: String = "",
        artistName: String = "",
        albumName: String = "",
        albumArtwork: UIImage? = nil,
        appleMusicURL: URL? = nil,
        isPlaying: Bool = false
    ) {
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.albumArtwork = albumArtwork
        self.appleMusicURL = appleMusicURL
        self.isPlaying = isPlaying
    }

    var isEmpty: Bool {
        trackName.isEmpty && artistName.isEmpty
    }
}

struct MusicCard: View {
    let size: CardSize
    var data: MusicCardData?
    var onTap: (() -> Void)?

    @State private var isLoading = false

    var body: some View {
        cardContent
            .frame(width: size.width, height: size.height)
            .cardBackground()
            .onTapGesture {
                onTap?()
            }
    }

    @ViewBuilder
    private var cardContent: some View {
        if let data = data, !data.isEmpty {
            contentView(for: data)
        } else {
            placeholderContent
        }
    }

    @ViewBuilder
    private func contentView(for data: MusicCardData) -> some View {
        GeometryReader { _ in
            HStack(spacing: 12) {
                artworkView(for: data, cardSize: size)
                if size == .w4h2 || size == .w4h4 {
                    infoView(for: data)
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func artworkView(for data: MusicCardData, cardSize: CardSize) -> some View {
        let artworkSize = cardSize.height - 24
        ZStack {
            if let image = data.albumArtwork {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: artworkSize, height: artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
    private func infoView(for data: MusicCardData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.trackName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(size == .w4h2 ? 1 : 2)

            Text(data.artistName)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)

            if size == .w4h4 && !data.albumName.isEmpty {
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
                Text("点击添加音乐")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct MusicCard_4x1: View {
    var data: MusicCardData?
    var onTap: (() -> Void)?
    var body: some View { MusicCard(size: .w4h1, data: data, onTap: onTap) }
}

struct MusicCard_4x2: View {
    var data: MusicCardData?
    var onTap: (() -> Void)?
    var body: some View { MusicCard(size: .w4h2, data: data, onTap: onTap) }
}

struct MusicCard_4x4: View {
    var data: MusicCardData?
    var onTap: (() -> Void)?
    var body: some View { MusicCard(size: .w4h4, data: data, onTap: onTap) }
}

#Preview {
    VStack(spacing: 12) {
        MusicCard_4x1()
        MusicCard_4x2(data: MusicCardData(
            trackName: "测试歌曲",
            artistName: "测试艺术家",
            albumName: "测试专辑",
            isPlaying: true
        ))
        MusicCard_4x4(data: MusicCardData(
            trackName: "这是一首很长很长的歌曲名称",
            artistName: "艺术家名字",
            albumName: "专辑名称",
            isPlaying: false
        ))
    }
    .frame(width: 400)
}