import SwiftUI

struct VoiceRecordingOverlayView: View {
    @ObservedObject var audioRecorder: AudioRecorderModel
    let isHoldToTalkMode: Bool
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowBreathing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            glowBubble
                .padding(.bottom, 140)

            Spacer(minLength: 0)
                .frame(maxHeight: 160)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowBreathing = true
            }
        }
    }

    private var glowBubble: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.white.opacity(0.85),
                    Color.accentColor.opacity(0.55),
                    Color.accentColor.opacity(0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 160
            )
            .frame(width: 380, height: 380)
            .blur(radius: 36)
            .scaleEffect(glowBreathing ? 1.06 : 1.0)
            .allowsHitTesting(false)

            VStack(spacing: MorySpacing.large) {
                transcriptView
                bottomRow
            }
            .padding(.horizontal, MorySpacing.xLarge)
            .frame(width: 300)
        }
    }

    private var transcriptView: some View {
        Text(transcriptText)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .animation(.default, value: transcriptText)
    }

    private var bottomRow: some View {
        HStack(spacing: MorySpacing.medium) {
            HStack(spacing: MorySpacing.small) {
                PulsingDot(isActive: audioRecorder.isRecording, reduceMotion: reduceMotion)
                Text(formatDuration(audioRecorder.recordingDuration))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isHoldToTalkMode {
                stopButton
            }
        }
    }

    private var stopButton: some View {
        Button { onStop() } label: {
            Group {
                if audioRecorder.isStopping || audioRecorder.isTranscribing {
                    ProgressView().controlSize(.small).tint(Color.accentColor)
                } else {
                    Label("quickCapture.voice.stop", systemImage: "stop.fill")
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 84, height: 36)
        }
        .background(Color.accentColor.opacity(0.12), in: Capsule())
        .disabled(audioRecorder.isStopping || audioRecorder.isTranscribing)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("quickCapture.voice.stopSubmit"))
        .accessibilityHint(Text("quickCapture.voice.stopSubmit.hint"))
    }

    private var transcriptText: String {
        let live = audioRecorder.liveTranscription.trimmedOrNil
        if audioRecorder.isStopping {
            return live ?? String(localized: "quickCapture.voice.finalizing")
        }
        if audioRecorder.isTranscribing {
            return live ?? String(localized: "quickCapture.voice.transcribing")
        }
        return live ?? String(localized: "quickCapture.voice.transcriptPlaceholder")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct PulsingDot: View {
    let isActive: Bool
    let reduceMotion: Bool
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 7, height: 7)
            .opacity(isAnimating && isActive && !reduceMotion ? 0.35 : 1.0)
            .onAppear {
                guard isActive && !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
