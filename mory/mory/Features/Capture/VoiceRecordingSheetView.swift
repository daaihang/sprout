import SwiftUI

struct VoiceRecordingSheetView: View {
    @ObservedObject var audioRecorder: AudioRecorderModel
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: MorySpacing.large) {
            Spacer(minLength: 0)
            transcriptScrollView
            timerRow
            Spacer(minLength: 0)
            stopButton
                .padding(.bottom, MorySpacing.large)
        }
        .padding(.horizontal, MorySpacing.xLarge)
        .frame(maxWidth: .infinity)
        .interactiveDismissDisabled()
    }

    // MARK: - Transcript

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
                withAnimation {
                    proxy.scrollTo("transcriptBottom", anchor: .bottom)
                }
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
