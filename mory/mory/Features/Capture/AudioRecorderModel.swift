import AVFoundation
import Combine
import Foundation
import Speech

enum AudioRecordingState: String, Equatable, Sendable {
    case idle
    case preparing
    case recording
    case finalizing
    case transcribing
    case transcriptReady
    case failed
    case cancelled
}

struct AudioRecordingOutput: Equatable, Sendable {
    var url: URL?
    var filename: String
    var audioData: Data?
}

protocol AudioRecordingControlling: AnyObject {
    var onPartialTranscription: (@MainActor (String) -> Void)? { get set }
    func start() async throws
    func stop() async -> AudioRecordingOutput?
    func cancel() async
}

protocol AudioRecordingTranscribing: Sendable {
    func transcribe(audioData: Data, filename: String?) async -> AudioTranscriptionService.Result?
}

extension AudioTranscriptionService: AudioRecordingTranscribing {}

@MainActor
final class AudioRecorderModel: ObservableObject {
    @Published private(set) var state: AudioRecordingState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordedAudioURL: URL?
    @Published var recordedAudioData: Data?
    @Published var liveTranscription = ""
    @Published var finalTranscription = ""
    @Published var transcriptionDuration: TimeInterval?
    @Published var errorMessage: String?

    private let controller: any AudioRecordingControlling
    private let transcriber: any AudioRecordingTranscribing
    private var recordingTimer: Timer?

    init(
        controller: (any AudioRecordingControlling)? = nil,
        transcriber: (any AudioRecordingTranscribing)? = nil
    ) {
        self.controller = controller ?? AVSpeechAudioRecordingController()
        self.transcriber = transcriber ?? AudioTranscriptionService()
        self.controller.onPartialTranscription = { [weak self] transcript in
            self?.liveTranscription = transcript
        }
    }

    var isRecording: Bool { state == .recording }
    var isStopping: Bool { state == .finalizing }
    var isTranscribing: Bool { state == .transcribing }
    var isBusy: Bool { state == .preparing || state == .recording || state == .finalizing || state == .transcribing }
    var canSaveAudio: Bool { recordedAudioData != nil }
    var recordedFilename: String? { recordedAudioURL?.lastPathComponent }

    func startRecording() async {
        guard state == .idle || state == .cancelled || state == .failed || state == .transcriptReady else { return }
        resetOutput()
        state = .preparing
        errorMessage = nil

        do {
            try await controller.start()
            state = .recording
            startTimer()
        } catch {
            fail(error.localizedDescription)
        }
    }

    @discardableResult
    func stopAndTranscribe() async -> AudioRecordingOutput? {
        guard state == .recording || state == .preparing || state == .finalizing else {
            return currentOutput()
        }

        state = .finalizing
        stopTimer()
        let output = await controller.stop()
        recordedAudioURL = output?.url
        recordedAudioData = output?.audioData

        guard let output, let audioData = output.audioData else {
            state = .idle
            return nil
        }

        state = .transcribing
        if let result = await transcriber.transcribe(audioData: audioData, filename: output.filename) {
            finalTranscription = result.transcription
            transcriptionDuration = result.duration
        } else if finalTranscription.trimmedOrNil == nil {
            finalTranscription = liveTranscription
        }
        state = .transcriptReady
        return output
    }

    func cancelRecording() async {
        guard state != .idle else { return }
        stopTimer()
        await controller.cancel()
        resetOutput()
        state = .cancelled
    }

    func clearRecording() {
        stopTimer()
        resetOutput()
        errorMessage = nil
        state = .idle
    }

    private func startTimer() {
        stopTimer()
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.recordingDuration += 0.1
            }
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func resetOutput() {
        recordedAudioURL = nil
        recordedAudioData = nil
        liveTranscription = ""
        finalTranscription = ""
        transcriptionDuration = nil
        recordingDuration = 0
    }

    private func currentOutput() -> AudioRecordingOutput? {
        guard let data = recordedAudioData else { return nil }
        return AudioRecordingOutput(
            url: recordedAudioURL,
            filename: recordedFilename ?? "audio_\(Date().timeIntervalSince1970).caf",
            audioData: data
        )
    }

    private func fail(_ message: String) {
        stopTimer()
        errorMessage = message
        state = .failed
    }
}

enum AudioRecorderError: LocalizedError {
    case microphoneDenied
    case speechDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: String(localized: "quickCapture.voice.error.microphone")
        case .speechDenied: String(localized: "quickCapture.voice.error.speech")
        case .recognizerUnavailable: String(localized: "quickCapture.voice.error.recognizer")
        }
    }
}

@MainActor
final class AVSpeechAudioRecordingController: AudioRecordingControlling {
    var onPartialTranscription: (@MainActor (String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioSession = AVAudioSession.sharedInstance()
    private var currentRecordingURL: URL?

    func start() async throws {
        guard await requestMicrophonePermission() else {
            throw AudioRecorderError.microphoneDenied
        }
        guard await requestSpeechPermission() else {
            throw AudioRecorderError.speechDenied
        }

        let recognizer = SFSpeechRecognizer(locale: preferredSpeechLocale())
        guard let recognizer, recognizer.isAvailable else {
            throw AudioRecorderError.recognizerUnavailable
        }

        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
        try audioSession.setActive(true)

        let filename = "audio_\(Date().timeIntervalSince1970).caf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        let file = try AVAudioFile(forWriting: url, settings: inputFormat.settings)
        recognitionRequest = request
        audioFile = file
        currentRecordingURL = url

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            Task { @MainActor in
                self.onPartialTranscription?(result.bestTranscription.formattedString)
            }
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            request.append(buffer)
            try? file.write(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() async -> AudioRecordingOutput? {
        let url = currentRecordingURL
        tearDownRecording(finishRecognition: true)

        guard let url else { return nil }
        return AudioRecordingOutput(
            url: url,
            filename: url.lastPathComponent,
            audioData: try? Data(contentsOf: url)
        )
    }

    func cancel() async {
        tearDownRecording(finishRecognition: false)
    }

    private func tearDownRecording(finishRecognition: Bool) {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        if finishRecognition {
            recognitionRequest?.endAudio()
            recognitionTask?.finish()
        } else {
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
        }
        recognitionRequest = nil
        recognitionTask = nil
        audioFile = nil
        currentRecordingURL = nil
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestMicrophonePermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        if AVAudioApplication.shared.recordPermission == .denied { return false }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }
        if status != .notDetermined { return false }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func preferredSpeechLocale() -> Locale {
        for localeId in Locale.preferredLanguages {
            let locale = Locale(identifier: localeId)
            if let code = locale.language.languageCode?.identifier {
                switch code {
                case "zh": return Locale(identifier: "zh-Hans")
                case "en": return Locale(identifier: "en-US")
                case "ja": return Locale(identifier: "ja-JP")
                case "ko": return Locale(identifier: "ko-KR")
                default: continue
                }
            }
        }
        return Locale(identifier: "zh-Hans")
    }
}
