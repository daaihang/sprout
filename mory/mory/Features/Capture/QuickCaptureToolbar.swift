import SwiftUI
import UIKit

struct QuickVoiceCaptureResult: Identifiable, Equatable, Sendable {
    let id = UUID()
    var filename: String
    var audioData: Data?
    var transcription: String
    var duration: TimeInterval?
}

struct QuickCaptureToolbar: View {
    @ObservedObject var audioRecorder: AudioRecorderModel
    @Binding var stopTrigger: Bool
    let onTextCapture: () -> Void
    let onPhotoCapture: () -> Void
    let onVoiceCaptureReady: (QuickVoiceCaptureResult) -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement

    var body: some View {
        Group {
            if isVoiceSessionActive {
                voiceAccessoryContent
            } else {
                HStack(spacing: 0) {
                    quickActionButton(
                        systemImage: "camera.fill",
                        accessibilityLabel: "quickCapture.photo",
                        accessibilityHint: "quickCapture.photo.hint",
                        action: onPhotoCapture
                    )

                    captureCapsule

                    voiceButton
                }
            }
        }
        .padding(.horizontal, contentHorizontalInset)
        .frame(maxWidth: .infinity)
        .frame(height: accessoryHeight)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isVoiceSessionActive)
        .onChange(of: stopTrigger) { _, triggered in
            if triggered {
                stopTrigger = false
                handleVoiceButtonTap()
            }
        }
    }

    private var voiceAccessoryContent: some View {
        HStack(spacing: voiceContentSpacing) {
            Text(voiceElapsedText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: durationWidth, alignment: .leading)

            Text(voiceTranscriptText)
                .font(capsuleFont)
                .foregroundStyle(capsulePrimaryColor)
                .lineLimit(1)
                .truncationMode(.head)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: controlSize, maxHeight: controlSize)

            voiceStopButton
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var captureCapsule: some View {
        Button {
            if let recoveryAction = audioRecorder.recoveryAction {
                handleRecoveryAction(recoveryAction)
            } else if !isVoiceSessionActive {
                onTextCapture()
            }
        } label: {
            Group {
                Text(capsulePrimaryText)
                    .font(capsuleFont)
                    .foregroundStyle(capsulePrimaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: controlSize, maxHeight: controlSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(capsuleAccessibilityLabel))
        .accessibilityHint(Text("quickCapture.unified.hint"))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard !audioRecorder.isBusy else { return }
                handleVoiceButtonTap()
            }
        )
    }

    private var isInlineAccessory: Bool {
        accessoryPlacement == .inline
    }

    private var accessoryHeight: CGFloat {
        isInlineAccessory ? 40 : 52
    }

    private var controlSize: CGFloat {
        isInlineAccessory ? 38 : 44
    }

    private var contentHorizontalInset: CGFloat {
        isInlineAccessory ? 10 : 12
    }

    private var capsuleFont: Font {
        isInlineAccessory ? .footnote.weight(.semibold) : .subheadline.weight(.semibold)
    }

    private var iconFont: Font {
        isInlineAccessory ? .subheadline.weight(.semibold) : .headline.weight(.semibold)
    }

    private var durationWidth: CGFloat {
        isInlineAccessory ? 44 : 50
    }

    private var stopButtonWidth: CGFloat {
        isInlineAccessory ? 72 : 84
    }

    private var voiceContentSpacing: CGFloat {
        isInlineAccessory ? 8 : 10
    }

    private var isVoiceSessionActive: Bool {
        switch audioRecorder.state {
        case .preparing, .recording, .finalizing, .transcribing:
            return true
        default:
            return false
        }
    }

    private var capsulePrimaryColor: Color {
        switch audioRecorder.state {
        case .failed:
            return .orange
        default:
            return .primary
        }
    }

    private var capsulePrimaryText: String {
        if let error = audioRecorder.errorMessage {
            return error
        }
        switch audioRecorder.state {
        case .preparing:
            return String(localized: "quickCapture.voice.preparing")
        case .recording:
            return String(localized: "quickCapture.voice.recording \(Int(audioRecorder.recordingDuration))")
        case .finalizing:
            return String(localized: "quickCapture.voice.finalizing")
        case .transcribing:
            return String(localized: "quickCapture.voice.transcribing")
        default:
            return String(localized: "quickCapture.unified.placeholder")
        }
    }

    private var voiceElapsedText: String {
        formatDuration(audioRecorder.recordingDuration)
    }

    private var voiceTranscriptText: String {
        let liveTranscript = audioRecorder.liveTranscription.trimmedOrNil
        if audioRecorder.isStopping { return liveTranscript ?? String(localized: "quickCapture.voice.finalizing") }
        if audioRecorder.isTranscribing {
            return liveTranscript ?? String(localized: "quickCapture.voice.transcribing")
        }
        return liveTranscript ?? String(localized: "quickCapture.voice.transcriptPlaceholder")
    }

    private var capsuleAccessibilityLabel: String {
        if audioRecorder.isRecording || audioRecorder.isStopping || audioRecorder.isTranscribing {
            return "\(voiceElapsedText), \(voiceTranscriptText)"
        }
        return String(localized: "quickCapture.unified.placeholder")
    }

    private var voiceButton: some View {
        Button {
            handleVoiceButtonTap()
        } label: {
            Group {
                if audioRecorder.isStopping || audioRecorder.isTranscribing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(iconFont)
                        .foregroundStyle(audioRecorder.isRecording ? .red : .primary)
                }
            }
            .frame(width: controlSize, height: controlSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(audioRecorder.isStopping || audioRecorder.isTranscribing)
        .accessibilityLabel(Text(audioRecorder.isRecording ? "quickCapture.voice.stopSubmit" : "quickCapture.voice.start"))
        .accessibilityHint(Text(audioRecorder.isRecording ? "quickCapture.voice.stopSubmit.hint" : "quickCapture.voice.start.hint"))
    }

    private var voiceStopButton: some View {
        Button {
            handleVoiceButtonTap()
        } label: {
            Group {
                if audioRecorder.isStopping || audioRecorder.isTranscribing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("quickCapture.voice.stop", systemImage: "stop.fill")
                        .font(.caption.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .foregroundStyle(.red)
            .frame(width: stopButtonWidth, height: controlSize)
            .background(Color.red.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(audioRecorder.isStopping || audioRecorder.isTranscribing)
        .accessibilityLabel(Text("quickCapture.voice.stopSubmit"))
        .accessibilityHint(Text("quickCapture.voice.stopSubmit.hint"))
    }

    private func quickActionButton(
        systemImage: String,
        accessibilityLabel: LocalizedStringKey,
        accessibilityHint: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(iconFont)
                .frame(width: controlSize, height: controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(accessibilityHint))
    }

    private func handleVoiceButtonTap() {
        if let recoveryAction = audioRecorder.recoveryAction {
            handleRecoveryAction(recoveryAction)
            return
        }

        if audioRecorder.isRecording {
            stopVoiceCapture()
        } else {
            startVoiceCapture()
        }
    }

    private func startVoiceCapture() {
        playImpact(.medium)
        Task {
            await audioRecorder.startRecording()
        }
    }

    private func stopVoiceCapture() {
        Task {
            guard let output = await audioRecorder.stopAndTranscribe() else {
                if audioRecorder.state == .failed {
                    notify(.error)
                }
                return
            }
            notify(.success)
            onVoiceCaptureReady(
                QuickVoiceCaptureResult(
                    filename: output.filename,
                    audioData: output.audioData,
                    transcription: audioRecorder.finalTranscription.trimmedOrNil ?? audioRecorder.liveTranscription,
                    duration: audioRecorder.transcriptionDuration
                )
            )
        }
    }

    private func handleRecoveryAction(_ action: AudioRecordingRecoveryAction) {
        switch action {
        case .openSettings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        case .retry:
            audioRecorder.clearRecording()
            playImpact(.light)
        }
    }

    private func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
