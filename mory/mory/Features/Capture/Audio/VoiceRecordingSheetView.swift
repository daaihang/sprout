import SwiftUI

struct VoiceRecordingSheetView: View {
    @ObservedObject var audioRecorder: AudioRecorderModel
    let onStop: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
                .padding(.horizontal, MorySpacing.large)
                .padding(.top, MorySpacing.medium)

            transcriptScrollView
                .padding(.horizontal, MorySpacing.large)
                .padding(.top, MorySpacing.medium)

            Spacer(minLength: MorySpacing.medium)

            doneButton
                .padding(.horizontal, MorySpacing.large)
                .padding(.bottom, MorySpacing.large)
        }
        .frame(maxWidth: .infinity)
        .interactiveDismissDisabled()
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("quickCapture.voice.cancel"))

            Spacer()

            HStack(spacing: 6) {
                PulsingDot(isActive: audioRecorder.isRecording, reduceMotion: reduceMotion)
                Text(formatDuration(audioRecorder.recordingDuration))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }

            Spacer()

            // Balance the xmark on the left
            Color.clear.frame(width: 44, height: 44)
        }
    }

    // MARK: - Transcript

    private var transcriptScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(transcriptText)
                        .font(.body)
                        .foregroundStyle(transcriptStyle)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
            }
            .onChange(of: transcriptText) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button(action: onStop) {
            if audioRecorder.isStopping || audioRecorder.isTranscribing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("quickCapture.voice.stop")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
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

    private var transcriptStyle: AnyShapeStyle {
        audioRecorder.liveTranscription.trimmedOrNil == nil
            ? AnyShapeStyle(.secondary)
            : AnyShapeStyle(.primary)
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
