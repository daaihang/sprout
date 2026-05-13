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
        Group {
            if let data, !data.isEmpty {
                GeometryReader { geometry in
                    let context = MusicCardLayoutContext(containerSize: geometry.size)
                    MusicCardRenderer(data: data, context: context)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                placeholderContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    @ViewBuilder
    private var placeholderContent: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.90, blue: 0.92),
                    Color(red: 0.90, green: 0.90, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius - 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                .padding(6)

            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.76))
                        .frame(width: 42, height: 42)
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.6))
                }

                Text(localizedString("card.music.placeholder", default: "Tap to add music"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.72))

                Text(localizedString("card.music.placeholder.subtitle", default: "Songs become memory artifacts with artist, album, and playback context."))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .lineLimit(2)
            }
            .padding(16)
        }
    }
}

private struct MusicCardRenderer: View {
    let data: MusicCardData
    let context: MusicCardLayoutContext

    var body: some View {
        ZStack {
            switch context.mode {
            case .compactStrip:
                compactStrip
            case .splitArtwork:
                splitArtwork
            case .heroArtwork:
                heroArtwork
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous))
        .animation(.spring(duration: 0.34, bounce: 0.16), value: context.mode.rawValue)
    }

    private var compactStrip: some View {
        HStack(spacing: 12) {
            artwork(size: context.compactArtworkSize)
                .overlay(alignment: .bottomTrailing) {
                    if data.isPlaying {
                        playbackBadge(compact: true)
                            .offset(x: 4, y: 4)
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                titleBlock(titleFont: context.compactTitleFont, bodyFont: context.compactBodyFont, lineLimit: 1)

                HStack(spacing: 8) {
                    if let source = sourceLine {
                        chip(text: source, systemImage: "apple.logo", lightText: false)
                    }
                    Spacer(minLength: 0)
                    if data.isPlaying {
                        miniWaveform
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.98), Color(red: 0.98, green: 0.96, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var splitArtwork: some View {
        HStack(spacing: 0) {
            artwork(size: CGSize(width: context.leadingArtworkWidth, height: context.containerSize.height))
                .frame(width: context.leadingArtworkWidth)
                .overlay(alignment: .topLeading) {
                    topChips(lightText: true)
                        .padding(10)
                }
                .overlay(alignment: .bottomTrailing) {
                    if data.isPlaying {
                        playbackBadge(compact: false)
                            .padding(10)
                    }
                }

            VStack(alignment: .leading, spacing: 8) {
                titleBlock(titleFont: context.standardTitleFont, bodyFont: context.standardBodyFont, lineLimit: context.titleLineLimit)

                Spacer(minLength: 0)

                if let albumName = albumLine {
                    Text(albumName)
                        .font(context.metaFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let source = sourceLine {
                        chip(text: source, systemImage: "apple.logo", lightText: false)
                    }
                    Spacer(minLength: 0)
                    if data.isPlaying {
                        miniWaveform
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.97))
        }
    }

    private var heroArtwork: some View {
        ZStack(alignment: .topLeading) {
            artwork(size: context.containerSize)
            LinearGradient(
                colors: [.black.opacity(0.18), .clear, .black.opacity(0.74)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                topChips(lightText: true)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        titleBlock(titleFont: context.heroTitleFont, bodyFont: context.heroBodyFont, lineLimit: context.titleLineLimit, lightText: true)

                        if let albumName = albumLine {
                            Text(albumName)
                                .font(context.heroMetaFont)
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    if data.isPlaying {
                        playbackBadge(compact: false)
                    }
                }
                .padding(14)
            }
        }
    }

    private func artwork(size: CGSize) -> some View {
        ZStack {
            artworkBackground

            AdaptiveCardVisual.remoteImage(
                data.albumArtworkURL,
                placeholderSystemName: "music.note",
                treatment: .cover
            )
            .view
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .frame(width: size.width, height: size.height)
    }

    private var artworkBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.64, blue: 0.78),
                Color(red: 0.61, green: 0.61, blue: 0.90)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func titleBlock(titleFont: Font, bodyFont: Font, lineLimit: Int, lightText: Bool = false) -> some View {
        let primary = lightText ? Color.white : Color.primary
        let secondary = lightText ? Color.white.opacity(0.9) : Color.secondary

        VStack(alignment: .leading, spacing: 4) {
            Text(data.trackName)
                .font(titleFont)
                .foregroundStyle(primary)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.82)

            if !data.artistName.isEmpty {
                Text(data.artistName)
                    .font(bodyFont)
                    .foregroundStyle(secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func topChips(lightText: Bool) -> some View {
        HStack(spacing: 8) {
            if let source = sourceLine {
                chip(text: source, systemImage: "apple.logo", lightText: lightText)
            }

            if data.isPlaying {
                chip(
                    text: localizedString("card.music.playing", default: "Playing"),
                    systemImage: "speaker.wave.2.fill",
                    lightText: lightText
                )
            }

            Spacer(minLength: 0)
        }
    }

    private func chip(text: String, systemImage: String, lightText: Bool) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(lightText ? Color.white : Color.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(lightText ? Color.black.opacity(0.28) : Color.black.opacity(0.05))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke((lightText ? Color.white : Color.black).opacity(lightText ? 0.16 : 0.08), lineWidth: 1)
            )
    }

    private func playbackBadge(compact: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(compact ? 0.92 : 0.86))
                .frame(width: compact ? 24 : 34, height: compact ? 24 : 34)
            Image(systemName: "waveform")
                .font(.system(size: compact ? 11 : 15, weight: .bold))
                .foregroundStyle(Color.pink.opacity(0.92))
                .symbolEffect(.pulse, options: .repeating, value: data.isPlaying)
        }
    }

    private var miniWaveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.pink.opacity(0.82))
                    .frame(width: 3, height: [8, 13, 10, 15][index])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.pink.opacity(0.08), in: Capsule(style: .continuous))
    }

    private var albumLine: String? {
        let trimmed = data.albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var sourceLine: String? {
        data.appleMusicURL == nil ? nil : localizedString("card.music.apple_music", default: "Apple Music")
    }
}

private struct MusicCardLayoutContext {
    enum Mode: String {
        case compactStrip
        case splitArtwork
        case heroArtwork
    }

    let containerSize: CGSize

    var aspectRatio: CGFloat {
        guard containerSize.height > 0 else { return 1 }
        return containerSize.width / containerSize.height
    }

    var mode: Mode {
        if containerSize.height < 104 || containerSize.width < 180 {
            return .compactStrip
        }
        if aspectRatio >= 1.25 {
            return .splitArtwork
        }
        return .heroArtwork
    }

    var compactArtworkSize: CGSize {
        CGSize(width: min(max(containerSize.height - 28, 48), 64), height: min(max(containerSize.height - 28, 48), 64))
    }

    var leadingArtworkWidth: CGFloat {
        max(min(containerSize.width * 0.42, 132), 96)
    }

    var compactTitleFont: Font {
        .system(size: 14, weight: .semibold, design: .rounded)
    }

    var compactBodyFont: Font {
        .system(size: 11, weight: .medium)
    }

    var standardTitleFont: Font {
        containerSize.height > 180
            ? .system(size: 18, weight: .bold, design: .rounded)
            : .system(size: 16, weight: .semibold, design: .rounded)
    }

    var standardBodyFont: Font {
        .system(size: 12, weight: .medium)
    }

    var heroTitleFont: Font {
        containerSize.height > 220
            ? .system(size: 24, weight: .bold, design: .rounded)
            : .system(size: 20, weight: .bold, design: .rounded)
    }

    var heroBodyFont: Font {
        .system(size: 13, weight: .semibold)
    }

    var metaFont: Font {
        .system(size: 11, weight: .medium)
    }

    var heroMetaFont: Font {
        .system(size: 12, weight: .medium)
    }

    var titleLineLimit: Int {
        switch mode {
        case .compactStrip:
            1
        case .splitArtwork:
            containerSize.height > 170 ? 2 : 1
        case .heroArtwork:
            containerSize.height > 210 ? 3 : 2
        }
    }
}
