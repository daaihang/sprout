import SwiftUI

struct AudioCaptureInputView: View {
    @ObservedObject var audioRecorder: AudioRecorderModel
    @Binding var transcriptionText: String
    @Binding var transcriptionDuration: TimeInterval?
    @Binding var noteText: String

    var body: some View {
        VStack(spacing: 12) {
            if audioRecorder.isRecording {
                HStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                        .opacity(audioRecorder.recordingDuration > 0 ? 1 : 0.5)
                    Text("capture.audio.recording \(Int(audioRecorder.recordingDuration))")
                        .font(.headline)
                    Spacer()
                    Button(String(localized: "capture.audio.stop")) {
                        Task { await audioRecorder.stopAndTranscribe() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            } else if audioRecorder.isStopping || audioRecorder.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(audioRecorder.isTranscribing ? "capture.audio.transcribing" : "capture.audio.finalizing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    transcriptionText = ""
                    transcriptionDuration = nil
                    Task { await audioRecorder.startRecording() }
                } label: {
                    Label(
                        audioRecorder.recordedAudioURL != nil ? String(localized: "capture.audio.rerecord") : String(localized: "capture.audio.startRecording"),
                        systemImage: "mic.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(audioRecorder.isStopping)
            }

            if let url = audioRecorder.recordedAudioURL {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let recorderError = audioRecorder.errorMessage {
                Text(recorderError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: audioRecorder.liveTranscription) { _, transcript in
            if !transcript.isEmpty {
                transcriptionText = transcript
            }
        }
        .onChange(of: audioRecorder.finalTranscription) { _, transcript in
            if !transcript.isEmpty {
                transcriptionText = transcript
            }
        }
        .onChange(of: audioRecorder.transcriptionDuration) { _, duration in
            transcriptionDuration = duration
        }

        if !transcriptionText.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("capture.audio.transcription")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("capture.audio.editTranscription", text: $transcriptionText, axis: .vertical)
                    .lineLimit(3...8)
                    .font(.subheadline)
                if let duration = transcriptionDuration {
                    Text("capture.audio.transcriptionTime \(String(format: "%.1f", duration))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }

        TextField("capture.audio.notePlaceholder", text: $noteText, axis: .vertical)
            .lineLimit(2...5)
    }
}
