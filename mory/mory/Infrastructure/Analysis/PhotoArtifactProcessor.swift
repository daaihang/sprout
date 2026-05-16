import Vision
import UIKit
import ImageIO

nonisolated final class PhotoArtifactProcessor: Sendable {

    struct Result: Sendable {
        let title: String
        let summary: String
        let ocrText: String
        let thumbnailData: Data
        let metadata: [String: String]
    }

    func process(imageData: Data, filename: String) async -> Result {
        await Task.detached(priority: .userInitiated) {
            Self.processImageData(imageData: imageData, filename: filename)
        }.value
    }

    nonisolated private static func processImageData(imageData: Data, filename: String) -> Result {
        let image = UIImage(data: imageData)
        let cgImage = image?.cgImage

        let classLabels = classifyImage(cgImage)
        let ocr = recognizeText(cgImage)
        let metadata = extractEXIF(imageData)
        let thumbnail = generateThumbnail(image, maxDimension: 600)

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

    nonisolated private static func classifyImage(_ cgImage: CGImage?) -> [String] {
        guard let cgImage else { return [] }
        let request = VNClassifyImageRequest()
        do {
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
        } catch {
            return []
        }

        return (request.results ?? [])
            .filter { $0.confidence > 0.3 }
            .prefix(5)
            .map { $0.identifier }
    }

    nonisolated private static func recognizeText(_ cgImage: CGImage?) -> String {
        guard let cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = Self.recognitionLanguages()
        request.recognitionLevel = .accurate

        do {
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
        } catch {
            return ""
        }

        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    nonisolated private static func recognitionLanguages() -> [String] {
        var languages: [String] = []
        for localeId in Locale.preferredLanguages {
            let locale = Locale(identifier: localeId)
            if let code = locale.language.languageCode?.identifier {
                switch code {
                case "zh": languages.append(contentsOf: ["zh-Hans", "zh-Hant"])
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

    nonisolated private static func extractEXIF(_ data: Data) -> [String: String] {
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

    nonisolated private static func generateThumbnail(_ image: UIImage?, maxDimension: CGFloat) -> Data {
        guard let image else { return Data() }
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.7) { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    nonisolated private static func buildSummary(labels: [String], ocrText: String) -> String {
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
