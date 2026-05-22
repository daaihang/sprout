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
    let onTextCapture: () -> Void
    let onPhotoCapture: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement

    var body: some View {
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
        .padding(.horizontal, contentHorizontalInset)
        .frame(maxWidth: .infinity)
        .frame(height: accessoryHeight)
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
        return String(localized: "quickCapture.unified.placeholder")
    }

    private var capsuleAccessibilityLabel: String {
        String(localized: "quickCapture.unified.placeholder")
    }

    private var voiceButton: some View {
        Button {
            handleVoiceButtonTap()
        } label: {
            Image(systemName: "mic.fill")
                .font(iconFont)
                .frame(width: controlSize, height: controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .disabled(isVoiceSessionActive)
        .accessibilityLabel(Text("quickCapture.voice.start"))
        .accessibilityHint(Text("quickCapture.voice.start.hint"))
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
        startVoiceCapture()
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
