import SwiftUI
import UIKit
import Speech
import AVFoundation
import Observation

// MARK: - SpeechRecognizer

@Observable
@MainActor
final class SpeechRecognizer {
    // Published state
    var recognizedText: String = ""
    var isRecording: Bool = false
    var audioLevel: Float = 0        // 0.0–1.0 RMS amplitude (updated per audio buffer)
    var recordingDuration: TimeInterval = 0
    var audioData: Data? = nil       // PCM/m4a file data captured during last session
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // Private internals
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var audioRecorder: AVAudioRecorder?
    private var durationTimer: Timer?
    private var audioFileURL: URL?

    // MARK: Authorization

    func requestAuthorization() async {
        // Microphone
        if #available(iOS 17.0, *) {
            let micStatus = AVAudioApplication.requestRecordPermission
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                AVAudioApplication.requestRecordPermission { _ in cont.resume() }
            }
        } else {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { _ in cont.resume() }
            }
        }
        // Speech recognition
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.authorizationStatus = status
                    cont.resume()
                }
            }
        }
    }

    // MARK: Recording

    func startRecording() {
        guard authorizationStatus == .authorized else { return }

        recognizedText = ""
        audioData      = nil
        audioLevel     = 0
        recordingDuration = 0
        recognitionTask?.cancel()
        recognitionTask = nil

        let engine = AVAudioEngine()
        audioEngine = engine

        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        // Set up AVAudioRecorder to capture a file alongside speech recognition
        let tmpURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970)).m4a")
        audioFileURL = tmpURL
        let recorderSettings: [String: Any] = [
            AVFormatIDKey:              Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:            44100,
            AVNumberOfChannelsKey:      1,
            AVEncoderAudioQualityKey:   AVAudioQuality.high.rawValue
        ]
        audioRecorder = try? AVAudioRecorder(url: tmpURL, settings: recorderSettings)
        audioRecorder?.record()

        // Speech recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let fmt       = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buffer, _ in
            request.append(buffer)
            // Compute RMS for waveform visualisation
            if let channelData = buffer.floatChannelData?[0] {
                let frameCount = Int(buffer.frameLength)
                var rms: Float = 0
                for i in 0 ..< frameCount { rms += channelData[i] * channelData[i] }
                rms = (frameCount > 0) ? sqrt(rms / Float(frameCount)) : 0
                let normalised = min(rms * 8, 1.0)   // scale: speech is typically 0.03–0.12 RMS
                Task { @MainActor [weak self] in self?.audioLevel = normalised }
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch { return }

        isRecording = true

        // Duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordingDuration += 0.1
            }
        }

        // Start recognition task
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    engine.stop()
                    inputNode.removeTap(onBus: 0)
                    request.endAudio()
                    self.isRecording = false
                }
            }
        }
    }

    func stopRecording() {
        durationTimer?.invalidate()
        durationTimer = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        audioRecorder?.stop()
        // Load captured audio data
        if let url = audioFileURL, let data = try? Data(contentsOf: url) {
            audioData = data
        }
        audioRecorder = nil

        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clearText() {
        recognizedText = ""
        stopRecording()
    }
}

// MARK: - PulsingModifier

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - SpeechRecognitionPage (debug/standalone)

struct SpeechRecognitionPage: View {
    @State private var recognizer = SpeechRecognizer()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 转写结果卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("转写结果")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    if recognizer.recognizedText.isEmpty {
                        Text("点击开始录音")
                            .font(.system(size: 17))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    } else {
                        Text(recognizer.recognizedText)
                            .font(.system(size: 17))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }

                    if recognizer.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .modifier(PulsingModifier())
                            Text("正在录音…  \(durationString)")
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 16) {
                    // 授权状态
                    HStack {
                        Label(authStatusText, systemImage: authStatusIcon)
                            .foregroundStyle(authStatusColor)
                            .font(.subheadline)
                        Spacer()
                        if recognizer.authorizationStatus == .notDetermined {
                            Button("请求权限") {
                                Task { await recognizer.requestAuthorization() }
                            }
                            .font(.caption).buttonStyle(.bordered)
                        } else if recognizer.authorizationStatus == .denied {
                            Button("打开设置") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption).buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 控制按钮
                    HStack(spacing: 16) {
                        Button {
                            if recognizer.isRecording { recognizer.stopRecording() }
                            else { recognizer.startRecording() }
                        } label: {
                            Label(
                                recognizer.isRecording ? "结束" : "开始录音",
                                systemImage: recognizer.isRecording ? "stop.fill" : "mic.fill"
                            )
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(recognizer.isRecording ? Color.red : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(recognizer.authorizationStatus != .authorized)

                        Button { recognizer.clearText() } label: {
                            Label("清空", systemImage: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.red)
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
        .task { await recognizer.requestAuthorization() }
    }

    private var durationString: String {
        let t = Int(recognizer.recordingDuration)
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    private var authStatusText: String {
        switch recognizer.authorizationStatus {
        case .notDetermined: return "未授权"
        case .denied:        return "已拒绝"
        case .restricted:    return "受限制"
        case .authorized:    return "已授权"
        @unknown default:    return "未知"
        }
    }

    private var authStatusIcon: String {
        switch recognizer.authorizationStatus {
        case .authorized:           return "checkmark.circle.fill"
        case .denied, .restricted:  return "xmark.circle.fill"
        default:                    return "questionmark.circle.fill"
        }
    }

    private var authStatusColor: Color {
        switch recognizer.authorizationStatus {
        case .authorized:           return .green
        case .denied, .restricted:  return .red
        default:                    return .orange
        }
    }
}

#Preview {
    NavigationStack { SpeechRecognitionPage() }
}
