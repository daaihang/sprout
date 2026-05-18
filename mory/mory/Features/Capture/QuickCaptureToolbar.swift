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
    let onTextCapture: () -> Void
    let onPhotoCapture: () -> Void
    let onMoreCapture: () -> Void
    let onVoiceCaptureReady: (QuickVoiceCaptureResult) -> Void

    @StateObject private var audioRecorder = AudioRecorderModel()
    @State private var isPressingVoice = false
    @State private var isCancellingVoice = false
    @State private var hasStartedVoiceCapture = false
    @State private var voiceStartTask: Task<Void, Never>?
    @State private var voiceLongPressTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: MorySpacing.small) {
            quickActionButton(
                systemImage: "camera.fill",
                accessibilityLabel: "quickCapture.photo",
                accessibilityHint: "quickCapture.photo.hint",
                action: onPhotoCapture
            )

            captureCapsule

            quickActionButton(
                systemImage: "plus",
                accessibilityLabel: "quickCapture.more",
                accessibilityHint: "quickCapture.more.hint",
                action: onMoreCapture
            )
        }
        .frame(height: 52)
        .padding(.horizontal, MorySpacing.medium)
        .padding(.vertical, MorySpacing.small)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var captureCapsule: some View {
        HStack(spacing: MorySpacing.small) {
            capsuleLeadingIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(capsulePrimaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(capsulePrimaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let secondaryText = capsuleSecondaryText {
                    Text(secondaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: MorySpacing.small)

            if let recoveryAction = audioRecorder.recoveryAction {
                Image(systemName: recoveryAction == .openSettings ? "gearshape.fill" : "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 26, height: 26)
            } else {
                Image(systemName: audioRecorder.isRecording ? "mic.circle.fill" : "mic.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(audioRecorder.isRecording ? .red : .secondary)
                    .frame(width: 26, height: 26)
            }
        }
        .padding(.horizontal, MorySpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        .background(capsuleBackground)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(capsuleStrokeColor, lineWidth: 1)
        }
        .contentShape(Capsule())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(capsuleAccessibilityLabel))
        .accessibilityHint(Text("quickCapture.unified.hint"))
        .gesture(capsuleGesture)
    }

    private var capsuleGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleCapsuleDragChanged(value)
            }
            .onEnded { value in
                handleCapsuleDragEnded(value)
            }
    }

    private var capsuleLeadingIcon: some View {
        Group {
            if audioRecorder.state == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if audioRecorder.isRecording || isPressingVoice {
                Circle()
                    .fill(isCancellingVoice ? .orange : .red)
                    .frame(width: 9, height: 9)
            } else if audioRecorder.isStopping || audioRecorder.isTranscribing {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 18, height: 18)
    }

    private var capsuleBackground: some ShapeStyle {
        if isCancellingVoice {
            return AnyShapeStyle(Color.orange.opacity(0.16))
        }
        if audioRecorder.isRecording {
            return AnyShapeStyle(Color.red.opacity(0.14))
        }
        if audioRecorder.state == .failed {
            return AnyShapeStyle(Color.orange.opacity(0.12))
        }
        return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }

    private var capsuleStrokeColor: Color {
        if isCancellingVoice {
            return .orange.opacity(0.45)
        }
        if audioRecorder.isRecording {
            return .red.opacity(0.35)
        }
        if audioRecorder.state == .failed {
            return .orange.opacity(0.35)
        }
        return Color.secondary.opacity(0.16)
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
        if isCancellingVoice {
            return String(localized: "quickCapture.voice.releaseToCancel")
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

    private var capsuleSecondaryText: String? {
        if audioRecorder.state == .failed {
            return String(localized: audioRecorder.recoveryAction == .openSettings ? "quickCapture.voice.recovery.openSettings" : "quickCapture.voice.recovery.retry")
        }
        if isCancellingVoice {
            return String(localized: "quickCapture.unified.cancelHint")
        }
        if !audioRecorder.liveTranscription.isEmpty && (audioRecorder.isRecording || audioRecorder.isTranscribing) {
            return audioRecorder.liveTranscription
        }
        if audioRecorder.isRecording || isPressingVoice {
            return String(localized: "quickCapture.unified.releaseHint")
        }
        return String(localized: "quickCapture.unified.tapHoldHint")
    }

    private var capsuleAccessibilityLabel: String {
        if audioRecorder.isRecording || audioRecorder.isStopping || audioRecorder.isTranscribing {
            return capsulePrimaryText
        }
        return String(localized: "quickCapture.unified.placeholder")
    }

    private func quickActionButton(
        systemImage: String,
        accessibilityLabel: LocalizedStringKey,
        accessibilityHint: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(accessibilityHint))
    }

    private func handleCapsuleDragChanged(_ value: DragGesture.Value) {
        if !isPressingVoice {
            isPressingVoice = true
            isCancellingVoice = false
            hasStartedVoiceCapture = false
            voiceLongPressTask = Task {
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard isPressingVoice, !hasStartedVoiceCapture else { return }
                    hasStartedVoiceCapture = true
                    playImpact(.medium)
                    voiceStartTask = Task {
                        await audioRecorder.startRecording()
                    }
                }
            }
        }
        if hasStartedVoiceCapture {
            isCancellingVoice = value.translation.width < -70 || value.translation.height < -55
        }
    }

    private func handleCapsuleDragEnded(_ value: DragGesture.Value) {
        let shouldCancel = isCancellingVoice || value.translation.width < -70 || value.translation.height < -55
        voiceLongPressTask?.cancel()
        voiceLongPressTask = nil

        if !hasStartedVoiceCapture {
            isPressingVoice = false
            isCancellingVoice = false
            if let recoveryAction = audioRecorder.recoveryAction {
                handleRecoveryAction(recoveryAction)
            } else {
                onTextCapture()
            }
            return
        }

        isPressingVoice = false
        isCancellingVoice = false
        hasStartedVoiceCapture = false

        Task {
            await voiceStartTask?.value
            voiceStartTask = nil
            if shouldCancel {
                await audioRecorder.cancelRecording()
                notify(.warning)
                return
            }
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
}
