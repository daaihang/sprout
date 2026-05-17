import Speech
import AVFoundation
import Foundation

final class AudioTranscriptionService: Sendable {

    struct Result: Sendable {
        let transcription: String
        let locale: Locale
        let duration: TimeInterval
    }

    func transcribe(audioData: Data, filename: String? = nil) async -> Result? {
        let authorized = await ensureAuthorized()
        guard authorized else { return nil }

        let ext = (filename as? NSString)?.pathExtension ?? "m4a"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + ext)
        do {
            try audioData.write(to: tempURL)
        } catch {
            return nil
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let locale = detectLocale()
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable else { return nil }

        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        request.shouldReportPartialResults = false

        let start = Date()

        let timeout = min(max(8.0, Double(audioData.count) / 24_000.0), 45.0)
        let transcription: String? = await withCheckedContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false
            var task: SFSpeechRecognitionTask?

            func resumeOnce(_ value: String?) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                task?.cancel()
                continuation.resume(returning: value)
            }

            task = recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    resumeOnce(result.bestTranscription.formattedString)
                } else if error != nil {
                    resumeOnce(nil)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                resumeOnce(nil)
            }
        }

        guard let text = transcription, !text.isEmpty else { return nil }

        return Result(
            transcription: text,
            locale: locale,
            duration: Date().timeIntervalSince(start)
        )
    }

    private func ensureAuthorized() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }
        if status != .notDetermined { return false }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { newStatus in
                continuation.resume(returning: newStatus == .authorized)
            }
        }
    }

    private func detectLocale() -> Locale {
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
