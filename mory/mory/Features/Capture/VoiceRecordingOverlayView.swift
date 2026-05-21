import SwiftUI

struct VoiceRecordingOverlayView: View {
    @ObservedObject var audioRecorder: AudioRecorderModel
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.red.opacity(0.04), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                ScrollView {
                    Text(transcriptText)
                        .font(.body)
                        .foregroundStyle(transcriptStyle)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, MorySpacing.xLarge)
                        .padding(.vertical, MorySpacing.large)
                        .animation(.default, value: transcriptText)
                }

                HStack(spacing: MorySpacing.medium) {
                    HStack(spacing: MorySpacing.small) {
                        PulsingDot(isActive: audioRecorder.isRecording, reduceMotion: reduceMotion)
                        Text(formatDuration(audioRecorder.recordingDuration))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    stopButton
                }
                .padding(.horizontal, MorySpacing.xLarge)
                .padding(.bottom, MorySpacing.large)
            }
        }
        .contentShape(Rectangle())
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

    private var transcriptStyle: AnyShapeStyle {
        audioRecorder.liveTranscription.trimmedOrNil == nil
            ? AnyShapeStyle(.secondary)
            : AnyShapeStyle(.primary)
    }

    private var stopButton: some View {
        Button { onStop() } label: {
            Group {
                if audioRecorder.isStopping || audioRecorder.isTranscribing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.red)
                } else {
                    Label("quickCapture.voice.stop", systemImage: "stop.fill")
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.red)
                }
            }
            .frame(width: 84, height: 36)
        }
        .background(Color.red.opacity(0.12), in: Capsule())
        .disabled(audioRecorder.isStopping || audioRecorder.isTranscribing)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("quickCapture.voice.stopSubmit"))
        .accessibilityHint(Text("quickCapture.voice.stopSubmit.hint"))
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
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .opacity(isAnimating && isActive && !reduceMotion ? 0.4 : 1.0)
            .onAppear {
                guard isActive && !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
