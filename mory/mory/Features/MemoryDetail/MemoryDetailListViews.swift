import AVFoundation
import SwiftUI

struct MemoryAudioList: View {
    let artifacts: [Artifact]

    var body: some View {
        if !artifacts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(artifacts) { artifact in
                    MemoryAudioRow(artifact: artifact)
                }
            }
            .padding(.horizontal, 20)
        } else {
            MemoryDetailEmptyBlock(
                titleKey: "memory.detail.empty.audio.title",
                messageKey: "memory.detail.empty.audio.message",
                systemImage: "waveform"
            )
            .padding(.horizontal, 20)
        }
    }
}

struct MemoryAudioRow: View {
    let artifact: Artifact
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(artifact.binaryPayload == nil)

            VStack(alignment: .leading, spacing: 3) {
                Text(artifact.memoryDetailSummary)
                    .font(.subheadline)
                    .lineLimit(2)
                if let filename = artifact.mediaRef?.filename {
                    Text(filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func togglePlayback() {
        guard let data = artifact.binaryPayload else { return }
        do {
            if player == nil {
                player = try AVAudioPlayer(data: data)
            }
            if player?.isPlaying == true {
                player?.pause()
                isPlaying = false
            } else {
                player?.play()
                isPlaying = true
            }
        } catch {
            isPlaying = false
        }
    }
}

struct MemoryLinkList: View {
    let artifacts: [Artifact]

    var body: some View {
        if !artifacts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(artifacts) { artifact in
                    Link(destination: URL(string: artifact.metadata["url"] ?? "") ?? URL(string: "https://example.com")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .frame(width: 32, height: 32)
                                .background(Color.secondary.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(artifact.memoryDetailSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                if let url = artifact.metadata["url"] {
                                    Text(url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        } else {
            MemoryDetailEmptyBlock(
                titleKey: "memory.detail.empty.link.title",
                messageKey: "memory.detail.empty.link.message",
                systemImage: "link"
            )
            .padding(.horizontal, 20)
        }
    }
}

struct MemoryDetailEmptyBlock: View {
    let titleKey: String
    let messageKey: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(LocalizedStringKey(titleKey), systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(LocalizedStringKey(messageKey))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
