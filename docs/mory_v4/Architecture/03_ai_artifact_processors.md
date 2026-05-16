# 03. AI Artifact Processors

## 1. 概述

每种非文字 Artifact 需要一个本地 AI 处理器，负责把原始数据转化为可被 L2 语义分析消费的文字。

所有处理器遵循同一协议：

```swift
protocol ArtifactProcessor {
    associatedtype Input
    associatedtype Output

    func process(_ input: Input) async throws -> Output
}
```

## 2. PhotoArtifactProcessor

### 2.1 职责

把一张照片转化为：标题 + 描述 + OCR 文字 + 缩略图 + EXIF 元数据。

### 2.2 实现

```swift
import Vision
import UIKit
import ImageIO

final class PhotoArtifactProcessor {

    struct Result {
        let title: String
        let summary: String
        let ocrText: String
        let thumbnailData: Data
        let metadata: [String: String]
    }

    func process(imageData: Data, filename: String) async -> Result {
        let image = UIImage(data: imageData)
        let cgImage = image?.cgImage

        async let classification = classifyImage(cgImage)
        async let ocrText = recognizeText(cgImage)
        async let exif = extractEXIF(imageData)
        let thumbnail = generateThumbnail(image, maxDimension: 600)

        let classLabels = await classification
        let ocr = await ocrText
        let metadata = await exif

        let title = classLabels.first ?? filename
        let summary = buildSummary(labels: classLabels, ocrText: ocr)

        return Result(
            title: title,
            summary: summary,
            ocrText: ocr,
            thumbnailData: thumbnail,
            metadata: metadata
        )
    }

    // MARK: - Vision 图片分类

    private func classifyImage(_ cgImage: CGImage?) async -> [String] {
        guard let cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let results = (request.results as? [VNClassificationObservation]) ?? []
                let labels = results
                    .filter { $0.confidence > 0.3 }
                    .prefix(5)
                    .map { $0.identifier }
                continuation.resume(returning: labels)
            }
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }

    // MARK: - OCR 文字识别

    private func recognizeText(_ cgImage: CGImage?) async -> String {
        guard let cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let results = (request.results as? [VNRecognizedTextObservation]) ?? []
                let text = results
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLanguages = detectRecognitionLanguages()
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }

    /// 动态检测系统语言，用于 OCR
    private func detectRecognitionLanguages() -> [String] {
        let preferredLanguages = Locale.preferredLanguages
        var languages: [String] = []

        for localeId in preferredLanguages {
            let locale = Locale(identifier: localeId)
            if let languageCode = locale.language.languageCode?.identifier {
                switch languageCode {
                case "zh": languages.append("zh-Hans"); languages.append("zh-Hant")
                case "en": languages.append("en")
                case "ja": languages.append("ja")
                case "ko": languages.append("ko")
                case "fr": languages.append("fr")
                case "de": languages.append("de")
                case "es": languages.append("es")
                default: break
                }
            }
        }

        if languages.isEmpty {
            languages = ["zh-Hans", "en"]
        }

        return Array(Set(languages)).prefix(4).map { $0 }
    }

    // MARK: - EXIF

    private func extractEXIF(_ data: Data) async -> [String: String] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { return [:] }

        var metadata: [String: String] = [:]
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let date = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                metadata["captureDate"] = date
            }
        }
        if let width = properties[kCGImagePropertyPixelWidth as String] {
            metadata["width"] = "\(width)"
        }
        if let height = properties[kCGImagePropertyPixelHeight as String] {
            metadata["height"] = "\(height)"
        }
        return metadata
    }

    // MARK: - 缩略图

    private func generateThumbnail(_ image: UIImage?, maxDimension: CGFloat) -> Data {
        guard let image else { return Data() }
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.jpegData(withCompressionQuality: 0.7) { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnail
    }

    private func buildSummary(labels: [String], ocrText: String) -> String {
        var parts: [String] = []
        if !labels.isEmpty {
            parts.append(labels.joined(separator: ", "))
        }
        if !ocrText.isEmpty {
            parts.append("Text: \(ocrText.prefix(200))")
        }
        return parts.joined(separator: " | ")
    }
}
```

### 2.3 性能要求

| 指标 | 要求 |
|------|------|
| 分类 + OCR + 缩略图总耗时 | < 3s |
| 缩略图大小 | < 200KB |
| 内存峰值 | < 50MB |

## 3. AudioTranscriptionService

### 3.1 职责

把录音转化为文字。

### 3.2 实现

```swift
import Speech
import AVFoundation

final class AudioTranscriptionService {

    func transcribe(audioData: Data) async -> String? {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            SFSpeechRecognizer.requestAuthorization { _ in }
            return nil
        }

        // 写入临时文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        try? audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // 检测语言
        let locale = detectLanguage(audioData: audioData)
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable else { return nil }

        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if error != nil {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func detectLanguage(audioData: Data) -> Locale {
        // 默认中文，用户可以在设置中配置
        // 未来可以用 NLLanguageRecognizer 做自动检测
        return Locale(identifier: "zh-Hans")
    }
}
```

### 3.3 性能要求

| 指标 | 要求 |
|------|------|
| 转写速度 | < 10s / 分钟录音 |
| 准确率 | > 90%（标准普通话/英文） |
| 最大录音时长 | 5 分钟 |

## 4. LinkMetadataExtractor

### 4.1 职责

从 URL 提取标题、描述、预览图。

### 4.2 实现

```swift
import LinkPresentation

final class LinkMetadataExtractor {

    struct Result {
        let title: String?
        let description: String?
        let imageData: Data?
        let siteName: String?
    }

    func extract(url: String) async -> Result? {
        guard let linkURL = URL(string: url) else { return nil }

        let provider = LPMetadataProvider()
        provider.timeout = 5

        guard let metadata = try? await provider.startFetchingMetadata(for: linkURL) else {
            return nil
        }

        let imageData = await loadImage(from: metadata.imageProvider)

        return Result(
            title: metadata.title,
            description: metadata.value(forKey: "summary") as? String,
            imageData: imageData,
            siteName: metadata.value(forKey: "siteName") as? String
        )
    }

    private func loadImage(from provider: NSItemProvider?) async -> Data? {
        guard let provider, provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                let data = (image as? UIImage)?.jpegData(compressionQuality: 0.7)
                continuation.resume(returning: data)
            }
        }
    }
}
```

### 4.3 性能要求

| 指标 | 要求 |
|------|------|
| 元数据提取 | < 5s（含网络） |
| 预览图大小 | < 200KB |
