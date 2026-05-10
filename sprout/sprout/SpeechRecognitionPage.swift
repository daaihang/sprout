import SwiftUI
import Speech
import AVFoundation
import Combine

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var recognizedText = "按住开始说话..."
    @Published var isRecording = false

    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }

    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    func startRecording() {
        guard authorizationStatus == .authorized else { return }

        recognitionTask?.cancel()
        recognitionTask = nil

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            recognizedText = "音频会话配置失败: \(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            recognizedText = "正在录音..."
        } catch {
            recognizedText = "启动音频引擎失败: \(error.localizedDescription)"
            return
        }

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
        let engineRef = audioEngine
        let inputNodeRef = inputNode

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    engineRef.stop()
                    inputNodeRef.removeTap(onBus: 0)
                    request.endAudio()
                    self.isRecording = false
                }
            }
        }
    }

    func stopRecording() {
        audioEngine?.stop()
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine = nil
        isRecording = false
    }

    func clearText() {
        recognizedText = "按住开始说话..."
        stopRecording()
    }
}

struct SpeechRecognitionPage: View {
    @StateObject private var recognizer = SpeechRecognizer()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 液态玻璃卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("转写结果")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(recognizer.recognizedText)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Debug 控件
                VStack(spacing: 16) {
                    // 授权状态
                    HStack {
                        Text("授权状态:")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Text(authorizationStatusText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(recognizer.authorizationStatus == .authorized ? .green : .orange)

                        Spacer()

                        if recognizer.authorizationStatus != .authorized {
                            Button("请求授权") {
                                recognizer.requestAuthorization()
                            }
                            .font(.system(size: 14))
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 控制按钮
                    HStack(spacing: 16) {
                        Button {
                            if recognizer.isRecording {
                                recognizer.stopRecording()
                            } else {
                                recognizer.startRecording()
                            }
                        } label: {
                            Label(
                                recognizer.isRecording ? "结束" : "开始",
                                systemImage: recognizer.isRecording ? "stop.fill" : "mic.fill"
                            )
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(recognizer.isRecording ? Color.red : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(recognizer.authorizationStatus != .authorized)

                        Button {
                            recognizer.clearText()
                        } label: {
                            Label("清空", systemImage: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("语音转文字")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    recognizer.authorizationStatus = status
                }
            }
        }
    }

    private var authorizationStatusText: String {
        switch recognizer.authorizationStatus {
        case .notDetermined: return "未确定"
        case .denied: return "被拒绝"
        case .restricted: return "受限制"
        case .authorized: return "已授权"
        @unknown default: return "未知"
        }
    }
}

#Preview {
    NavigationStack {
        SpeechRecognitionPage()
    }
}