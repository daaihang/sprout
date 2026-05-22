import SwiftUI

struct VoiceRecordingOverlayView: View {
    @ObservedObject var audioRecorder: AudioRecorderModel
    let isHoldToTalkMode: Bool
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowBreathing = false

    var body: some View {
        ZStack {
            // Background: subtle full-screen material blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.4)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Bubble: upper portion, independent of button
            VStack(spacing: 0) {
                Spacer().frame(minHeight: 60, maxHeight: 120)
                glowBubble
                Spacer()
            }

            // Stop button: lower portion, independent of bubble
            VStack(spacing: 0) {
                Spacer()
                if !isHoldToTalkMode {
                    stopButton
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                Spacer().frame(height: 28)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isHoldToTalkMode)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowBreathing = true
            }
        }
    }

    // MARK: - Glow Bubble

    private var glowBubble: some View {
        VStack(spacing: MorySpacing.small) {
            transcriptScrollView
            timerRow
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(minWidth: 240, maxWidth: 300)
        // Frosted material with radial fade — no hard edge
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    RadialGradient(
                        colors: [
                            .white,
                            .white.opacity(0.92),
                            .white.opacity(0.4),
                            .clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 200
                    )
                }
                .allowsHitTesting(false)
        }
        // Large accent glow — overflows layout bounds, doesn't affect sizing
        .background {
            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.52),
                    Color.accentColor.opacity(0.22),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )
            .frame(width: 480, height: 480)
            .blur(radius: 50)
            .scaleEffect(glowBreathing ? 1.08 : 1.0)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Content

    /// Fixed 4-line viewport, always scrolled to show the latest (bottom) text.
    private var transcriptScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Text(transcriptText)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Color.clear
                        .frame(height: 1)
                        .id("transcriptBottom")
                }
            }
            .frame(height: 88) // ≈ 4 lines of body text
            .onChange(of: transcriptText) { _, _ in
                proxy.scrollTo("transcriptBottom", anchor: .bottom)
            }
        }
    }

    private var timerRow: some View {
        HStack(spacing: MorySpacing.small) {
            PulsingDot(isActive: audioRecorder.isRecording, reduceMotion: reduceMotion)
            Text(formatDuration(audioRecorder.recordingDuration))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stop Button

    private var stopButton: some View {
        Button {
            onStop()
        } label: {
            if audioRecorder.isStopping || audioRecorder.isTranscribing {
                ProgressView()
                    .frame(minWidth: 120)
            } else {
                Label("quickCapture.voice.stop", systemImage: "stop.fill")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.red)
        .disabled(audioRecorder.isStopping || audioRecorder.isTranscribing)
        .accessibilityLabel(Text("quickCapture.voice.stopSubmit"))
        .accessibilityHint(Text("quickCapture.voice.stopSubmit.hint"))
    }

    // MARK: - Helpers

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

// MARK: - Pulsing Dot

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
