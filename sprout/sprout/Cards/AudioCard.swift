import SwiftUI
import AVFoundation
import Combine

private enum AudioDurationCache {
    static let queue = DispatchQueue(label: "AudioDurationCache.queue")
    static var storage: [Int: String] = [:]
}

private final class AudioDurationResolver {
    static let shared = AudioDurationResolver()

    func string(for audioData: Data?) -> String {
        guard let audioData else {
            return ""
        }

        let signature = audioData.hashValue
        if let cached = AudioDurationCache.queue.sync(execute: { AudioDurationCache.storage[signature] }) {
            return cached
        }

        let resolved: String
        if let player = try? AVAudioPlayer(data: audioData) {
            resolved = formatAudioDuration(player.duration)
        } else {
            resolved = ""
        }

        AudioDurationCache.queue.sync {
            AudioDurationCache.storage[signature] = resolved
        }
        return resolved
    }
}

struct AudioCardData {
    var title: String = ""
    var audioData: Data? = nil
    var transcriptPreview: String = ""
    var durationText: String = ""
    var capturedAt: Date? = nil

    var isEmpty: Bool {
        audioData == nil && title.isEmpty && transcriptPreview.isEmpty
    }
}

final class AudioPlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var loadedSignature: Int?

    func load(audioData: Data?) {
        let signature = audioData?.hashValue
        guard loadedSignature != signature else { return }

        stopPlayback()
        loadedSignature = signature
        duration = 0
        currentTime = 0

        guard let audioData else { return }
        player = try? AVAudioPlayer(data: audioData)
        player?.delegate = self
        player?.prepareToPlay()
        duration = player?.duration ?? 0
    }

    func togglePlayback() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            stopTimer()
            isPlaying = false
        } else {
            player.play()
            startTimer()
            isPlaying = true
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        stopTimer()
        isPlaying = false
        currentTime = 0
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopTimer()
        isPlaying = false
        currentTime = 0
        player.currentTime = 0
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            Task { @MainActor in
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct AudioCard: View {
    var data: AudioCardData?
    var onTap: (() -> Void)? = nil

    @StateObject private var playback = AudioPlaybackController()

    var body: some View {
        Group {
            if let data, !data.isEmpty {
                GeometryReader { geo in
                    contentView(data, metrics: CardLayoutMetrics(containerSize: geo.size))
                        .onAppear { playback.load(audioData: data.audioData) }
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
        .onDisappear { playback.stopPlayback() }
        .onChange(of: data?.audioData) { _, newValue in
            playback.load(audioData: newValue)
        }
    }

    private func contentView(_ data: AudioCardData, metrics: CardLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 8 : 12) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    playback.togglePlayback()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: metrics.isCompactHeight ? 14 : 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: metrics.isCompactHeight ? 34 : 40, height: metrics.isCompactHeight ? 34 : 40)
                        .background(Color.accentColor, in: Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title.isEmpty ? localizedString("card.audio.title", default: "Voice Note") : data.title)
                        .font(.system(size: metrics.isWideWidth ? 16 : 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(metrics.isTallHeight ? 2 : 1)

                    HStack(spacing: 6) {
                        Text(audioDurationLabel(fallback: data.durationText))
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)

                        if let capturedAt = data.capturedAt, !metrics.isCompactWidth {
                            Text(capturedAt.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            waveformRow(color: .accentColor)
                .frame(height: metrics.isCompactHeight ? 20 : 28)

            if !data.transcriptPreview.isEmpty && (!metrics.isCompactHeight || metrics.isWideWidth) {
                Text(data.transcriptPreview)
                    .font(.system(size: metrics.isTallHeight ? 14 : 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(metrics.isTallHeight ? 6 : (metrics.isWideWidth ? 4 : 2))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(metrics.isCompactHeight ? 12 : 16)
    }

    private func waveformRow(color: Color) -> some View {
        let progress = max(playback.duration, 0.1) == 0 ? 0 : min(playback.currentTime / max(playback.duration, 0.1), 1)
        return HStack(alignment: .center, spacing: 4) {
            ForEach(0..<18, id: \.self) { index in
                let baseHeight: CGFloat = [6, 12, 8, 15, 10, 17, 7, 14, 11][index % 9]
                let threshold = Double(index + 1) / 18.0
                RoundedRectangle(cornerRadius: 2)
                    .fill(threshold <= progress ? color : color.opacity(0.22))
                    .frame(width: 4, height: baseHeight)
            }
        }
    }

    private func audioDurationLabel(fallback: String) -> String {
        if playback.duration > 0 {
            return formatAudioDuration(playback.duration)
        }
        return fallback.isEmpty ? localizedString("card.audio.duration_placeholder", default: "--:--") : fallback
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(localizedString("card.audio.placeholder", default: "Tap to add a voice note"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

func formatAudioDuration(_ value: TimeInterval) -> String {
    let totalSeconds = max(Int(value.rounded()), 0)
    return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
}

func audioDurationString(from audioData: Data?) -> String {
    AudioDurationResolver.shared.string(for: audioData)
}

func makeSampleAudioData(duration: TimeInterval = 2.4, frequency: Double = 660) -> Data {
    let sampleRate = 44_100
    let channelCount = 1
    let bitsPerSample = 16
    let sampleCount = Int(Double(sampleRate) * duration)
    let byteRate = sampleRate * channelCount * bitsPerSample / 8
    let blockAlign = channelCount * bitsPerSample / 8
    let dataSize = sampleCount * channelCount * bitsPerSample / 8

    var data = Data()

    func appendASCII(_ string: String) {
        data.append(contentsOf: string.utf8)
    }

    func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    appendASCII("RIFF")
    appendLE(UInt32(36 + dataSize))
    appendASCII("WAVE")
    appendASCII("fmt ")
    appendLE(UInt32(16))
    appendLE(UInt16(1))
    appendLE(UInt16(channelCount))
    appendLE(UInt32(sampleRate))
    appendLE(UInt32(byteRate))
    appendLE(UInt16(blockAlign))
    appendLE(UInt16(bitsPerSample))
    appendASCII("data")
    appendLE(UInt32(dataSize))

    for index in 0..<sampleCount {
        let phase = 2 * Double.pi * frequency * Double(index) / Double(sampleRate)
        let envelope = min(Double(index) / Double(sampleCount / 10), 1.0)
        let sample = Int16((sin(phase) * 0.35 * envelope) * Double(Int16.max))
        appendLE(sample)
    }

    return data
}
