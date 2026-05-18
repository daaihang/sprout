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

struct QuickTextCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var title = ""
    @State private var bodyText = ""
    @State private var mood = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: QuickTextCaptureField?

    let onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("quickCapture.text.section") {
                    TextField("capture.field.title", text: $title)
                    TextField("quickCapture.text.placeholder", text: $bodyText, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($focusedField, equals: .body)
                    TextField("capture.field.mood", text: $mood)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("quickCapture.text.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || bodyText.trimmedOrNil == nil)
                }
            }
        }
        .task {
            focusedField = .body
        }
    }

    @MainActor
    private func save() async {
        guard !isSaving, let text = bodyText.trimmedOrNil else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let draft = MemoryCaptureDraft(
                title: title.trimmedOrNil ?? text.firstMeaningfulLine,
                rawText: text,
                mood: mood.trimmedOrNil,
                inputContext: "quick text capture",
                captureSource: .composer,
                artifacts: [.text(title: title.trimmedOrNil, body: text)]
            )
            let orchestrator = CaptureOrchestrator(memoryRepository: memoryRepository)
            _ = try await orchestrator.capture(draft: draft)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum QuickTextCaptureField: Hashable {
    case body
}

struct QuickVoiceReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.memoryRepository) private var memoryRepository

    let result: QuickVoiceCaptureResult
    let onSaved: () -> Void

    @State private var transcript: String
    @State private var note = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(result: QuickVoiceCaptureResult, onSaved: @escaping () -> Void) {
        self.result = result
        self.onSaved = onSaved
        _transcript = State(initialValue: result.transcription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("quickCapture.voice.transcriptPlaceholder", text: $transcript, axis: .vertical)
                        .lineLimit(4...10)
                    TextField("quickCapture.voice.notePlaceholder", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                    LabeledContent("quickCapture.voice.filename", value: result.filename)
                    if let duration = result.duration {
                        LabeledContent("quickCapture.voice.duration", value: String(format: "%.1fs", duration))
                    }
                } header: {
                    Text("quickCapture.voice.review.section")
                } footer: {
                    Text("quickCapture.voice.review.footer")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("quickCapture.voice.review.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("quickCapture.discard") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || result.audioData == nil)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let transcriptText = transcript.trimmedOrNil
            let noteText = note.trimmedOrNil
            let summary = noteText ?? transcriptText ?? String(localized: "quickCapture.voice.defaultSummary")
            let rawText = transcriptText ?? noteText ?? String(localized: "quickCapture.voice.defaultSummary")
            let draft = MemoryCaptureDraft(
                title: transcriptText?.firstMeaningfulLine ?? String(localized: "quickCapture.voice.defaultTitle"),
                rawText: rawText,
                mood: nil,
                inputContext: "quick voice capture",
                captureSource: .audio,
                artifacts: [.audio(
                    title: String(localized: "quickCapture.voice.defaultTitle"),
                    summary: summary,
                    filename: result.filename,
                    audioData: result.audioData,
                    transcriptionText: transcriptText ?? ""
                )]
            )
            let orchestrator = CaptureOrchestrator(memoryRepository: memoryRepository)
            _ = try await orchestrator.capture(draft: draft)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
