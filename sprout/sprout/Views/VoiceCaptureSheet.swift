import SwiftUI
import UIKit
import Speech

struct VoiceCaptureSheet: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.dismiss) private var dismiss

    var speechRecognizer: SpeechRecognizer
    let onCommit: (String, Data?) -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch speechRecognizer.authorizationStatus {
                case .authorized:
                    transcriptView
                case .denied, .restricted:
                    deniedView
                case .notDetermined:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    deniedView
                }
            }
            .navigationTitle(t("toolbar.voice.stop", "Stop Recording"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("common.cancel", "Cancel")) {
                        cancel()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("common.done", "Done")) {
                        commit()
                    }
                    .disabled(speechRecognizer.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && speechRecognizer.audioData == nil)
                }
            }
        }
        .task {
            if speechRecognizer.authorizationStatus == .notDetermined {
                await speechRecognizer.requestAuthorization()
            }
            guard speechRecognizer.authorizationStatus == .authorized else { return }
            if !speechRecognizer.isRecording {
                speechRecognizer.startRecording()
            }
        }
        .onDisappear {
            if speechRecognizer.isRecording {
                speechRecognizer.stopRecording()
            }
        }
    }

    private var transcriptView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                if speechRecognizer.recognizedText.isEmpty {
                    Text(t("toolbar.voice.transcribing", "Transcribing what you're saying…"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                } else {
                    ScrollView {
                        Text(speechRecognizer.recognizedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 240)
                }
            }
            .font(.system(size: 17))
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 10) {
                Label(durationString, systemImage: speechRecognizer.isRecording ? "mic.fill" : "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(speechRecognizer.isRecording ? Color.red : Color.green)

                Button {
                    if speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                    } else {
                        commit()
                    }
                } label: {
                    Text(speechRecognizer.isRecording ? t("toolbar.voice.stop", "Stop Recording") : t("common.done", "Done"))
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(20)
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(t("common.request_permission", "Request Permission"))
                .font(.headline)

            Text(t("toolbar.voice.locked_hint", "Keep talking, then stop when you're done"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(t("common.open_settings", "Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var durationString: String {
        let duration = Int(speechRecognizer.recordingDuration)
        return String(format: "%02d:%02d", duration / 60, duration % 60)
    }

    private func cancel() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }
        dismiss()
    }

    private func commit() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }
        onCommit(speechRecognizer.recognizedText, speechRecognizer.audioData)
        dismiss()
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}
