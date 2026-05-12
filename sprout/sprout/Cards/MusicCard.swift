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
        AdaptiveCardRoot(content: musicContent) {
            placeholderContent
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cardBackground()
            .onTapGesture {
                onTap?()
            }
    }

    private var musicContent: AdaptiveCardContent? {
        guard let data = data, !data.isEmpty else { return nil }

        let visual = AdaptiveCardVisual.custom(treatment: .cover) {
            ZStack {
                AdaptiveCardVisual.remoteImage(
                    data.albumArtworkURL,
                    placeholderSystemName: "music.note",
                    treatment: .cover
                ).view

                if data.isPlaying {
                    ZStack {
                        Color.black.opacity(0.34)
                        Image(systemName: "waveform")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse, options: .repeating, value: data.isPlaying)
                    }
                }
            }
        }

        return AdaptiveCardContent(
            preferredLayout: .leadingVisual,
            accent: Color.pink,
            visual: visual,
            title: data.trackName,
            subtitle: data.artistName,
            body: data.albumName.isEmpty ? nil : data.albumName,
            badge: data.isPlaying ? AdaptiveCardBadge(text: localizedString("card.music.playing", default: "Playing"), systemImage: "speaker.wave.2.fill") : nil,
            metaItems: data.appleMusicURL == nil ? [] : [
                AdaptiveCardMetaItem(systemImage: "apple.logo", text: localizedString("card.music.apple_music", default: "Apple Music"))
            ]
        )
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
