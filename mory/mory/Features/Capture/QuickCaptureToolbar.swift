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
    let onStopVoiceCapture: () -> Void
    @Binding var isHoldToTalkMode: Bool
    let onTextCapture: () -> Void
    let onPhotoCapture: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement
    @State private var capsulePressTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            quickActionButton(
                systemImage: "camera.fill",
                accessibilityLabel: "quickCapture.photo",
                accessibilityHint: "quickCapture.photo.hint",
                action: onPhotoCapture
            )
            .opacity(isVoiceSessionActive ? 0 : 1)
            .disabled(isVoiceSessionActive)

            captureCapsule

            voiceButton
                .opacity(isVoiceSessionActive ? 0 : 1)
                .disabled(isVoiceSessionActive)
        }
        .padding(.horizontal, contentHorizontalInset)
        .frame(maxWidth: .infinity)
        .frame(height: accessoryHeight)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isVoiceSessionActive)
    }

    private var captureCapsule: some View {
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
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard capsulePressTask == nil, !isHoldToTalkMode else { return }
                    capsulePressTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        guard !Task.isCancelled, !audioRecorder.isBusy else { return }
                        isHoldToTalkMode = true
                        capsulePressTask = nil
                        startVoiceCapture()
                    }
                }
                .onEnded { _ in
                    if let task = capsulePressTask {
                        task.cancel()
                        capsulePressTask = nil
                        if let recoveryAction = audioRecorder.recoveryAction {
                            handleRecoveryAction(recoveryAction)
                        } else if !isVoiceSessionActive {
                            onTextCapture()
                        }
                    } else if isHoldToTalkMode {
                        isHoldToTalkMode = false
                        onStopVoiceCapture()
                    }
                }
        )
        .accessibilityLabel(Text(capsuleAccessibilityLabel))
        .accessibilityHint(Text("quickCapture.unified.hint"))
        .accessibilityAddTraits(.isButton)
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

    private var capsuleAccessibilityLabel: String {
        if audioRecorder.isRecording || audioRecorder.isStopping || audioRecorder.isTranscribing {
            return "\(formatDuration(audioRecorder.recordingDuration)), \(capsulePrimaryText)"
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
            onStopVoiceCapture()
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
