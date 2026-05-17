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
    let onMoreCapture: () -> Void
    let onVoiceCaptureReady: (QuickVoiceCaptureResult) -> Void

    @StateObject private var audioRecorder = AudioRecorderModel()
    @State private var isPressingVoice = false
    @State private var isCancellingVoice = false
    @State private var voiceStartTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 6) {
            if shouldShowVoiceStatusRow {
                voiceStatusRow
            }

            HStack(spacing: MorySpacing.small) {
                Button {
                    onTextCapture()
                } label: {
                    Label("quickCapture.text", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                voiceButton

                Button {
                    onMoreCapture()
                } label: {
                    Label("quickCapture.more", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .labelStyle(.iconOnly)
        }
        .padding(.horizontal, MorySpacing.medium)
        .padding(.vertical, MorySpacing.small)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var shouldShowVoiceStatusRow: Bool {
        audioRecorder.isRecording
            || audioRecorder.isStopping
            || audioRecorder.isTranscribing
            || isPressingVoice
            || audioRecorder.errorMessage != nil
    }

    private var voiceButton: some View {
        Label("quickCapture.voice", systemImage: audioRecorder.isRecording ? "mic.circle.fill" : "mic.fill")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(voiceButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: MoryCornerRadius.small, style: .continuous))
            .foregroundStyle(audioRecorder.isRecording ? .white : .primary)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("quickCapture.voice.hint"))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleVoiceDragChanged(value)
                    }
                    .onEnded { value in
                        handleVoiceDragEnded(value)
                    }
            )
    }

    private var voiceButtonBackground: some ShapeStyle {
        if isCancellingVoice {
            return AnyShapeStyle(Color.red.opacity(0.85))
        }
        if audioRecorder.isRecording {
            return AnyShapeStyle(Color.red.opacity(0.9))
        }
        return AnyShapeStyle(Color.secondary.opacity(0.12))
    }

    private var voiceStatusRow: some View {
        HStack(spacing: 8) {
            voiceStatusIcon
            Text(voiceStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if let recoveryAction = audioRecorder.recoveryAction {
                Button {
                    handleRecoveryAction(recoveryAction)
                } label: {
                    Image(systemName: recoveryAction == .openSettings ? "gearshape" : "arrow.counterclockwise")
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(recoveryAction == .openSettings ? "quickCapture.voice.recovery.openSettings" : "quickCapture.voice.recovery.retry"))
            } else if !audioRecorder.liveTranscription.isEmpty {
                Text(audioRecorder.liveTranscription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(height: 22)
    }

    @ViewBuilder
    private var voiceStatusIcon: some View {
        if audioRecorder.state == .failed {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .frame(width: 12, height: 12)
        } else {
            Circle()
                .fill(isCancellingVoice ? .orange : .red)
                .frame(width: 8, height: 8)
        }
    }

    private var voiceStatusText: String {
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
            return String(localized: "quickCapture.voice.hold")
        }
    }

    private func handleVoiceDragChanged(_ value: DragGesture.Value) {
        if !isPressingVoice {
            isPressingVoice = true
            isCancellingVoice = false
            playImpact(.medium)
            voiceStartTask = Task {
                await audioRecorder.startRecording()
            }
        }
        isCancellingVoice = value.translation.width < -70 || value.translation.height < -55
    }

    private func handleVoiceDragEnded(_ value: DragGesture.Value) {
        let shouldCancel = isCancellingVoice || value.translation.width < -70 || value.translation.height < -55
        isPressingVoice = false
        isCancellingVoice = false

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
