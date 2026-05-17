import Foundation
import LinkPresentation
import UniformTypeIdentifiers

struct LinkMetadataResult: Hashable, Sendable {
    let url: String
    let title: String?
    let summary: String?
    let siteName: String?
    let imageURL: String?
    let imageData: Data?

    var metadata: [String: String] {
        var values: [String: String] = ["url": url]
        if let siteName { values["siteName"] = siteName }
        if let imageURL { values["ogImage"] = imageURL }
        return values
    }
}

final class LinkMetadataExtractor: Sendable {
    static func firstURLCandidate(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector?
            .matches(in: text, options: [], range: range)
            .compactMap { match -> String? in
                guard let url = match.url else { return nil }
                return url.absoluteString
            }
            .first
    }

    func extract(urlString: String) async -> LinkMetadataResult? {
        guard let url = normalizedURL(from: urlString) else { return nil }
        let resolvedURL = await resolveRedirectURL(from: url) ?? url

        do {
            let metadata = try await LPMetadataProvider().startFetchingMetadata(for: resolvedURL)
            let imageData = await loadImageData(from: metadata)
            let metadataURL = metadata.url ?? metadata.originalURL ?? resolvedURL
            let siteName = siteName(from: metadata, fallbackURL: metadataURL)
            return LinkMetadataResult(
                url: metadataURL.absoluteString,
                title: metadata.title?.trimmedOrNil,
                summary: siteName,
                siteName: siteName,
                imageURL: nil,
                imageData: imageData
            )
        } catch {
            return LinkMetadataResult(
                url: resolvedURL.absoluteString,
                title: nil,
                summary: nil,
                siteName: resolvedURL.host(percentEncoded: false),
                imageURL: nil,
                imageData: nil
            )
        }
    }

    private func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private func resolveRedirectURL(from url: URL) async -> URL? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 4
        request.setValue("Mory/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.url
        } catch {
            var fallbackRequest = URLRequest(url: url)
            fallbackRequest.httpMethod = "GET"
            fallbackRequest.timeoutInterval = 4
            fallbackRequest.setValue("bytes=0-0", forHTTPHeaderField: "Range")
            fallbackRequest.setValue("Mory/1.0", forHTTPHeaderField: "User-Agent")
            guard let (_, response) = try? await URLSession.shared.data(for: fallbackRequest) else { return nil }
            return (response as? HTTPURLResponse)?.url
        }
    }

    private func siteName(from metadata: LPLinkMetadata, fallbackURL: URL) -> String? {
        metadata.originalURL?.host(percentEncoded: false)
            ?? metadata.url?.host(percentEncoded: false)
            ?? fallbackURL.host(percentEncoded: false)
    }

    private func loadImageData(from metadata: LPLinkMetadata) async -> Data? {
        guard let provider = metadata.imageProvider else { return nil }
        let imageTypes = [UTType.image.identifier, UTType.jpeg.identifier, UTType.png.identifier]

        for type in imageTypes where provider.hasItemConformingToTypeIdentifier(type) {
            if let data = await loadData(from: provider, typeIdentifier: type) {
                return data
            }
        }
        return nil
    }

    private func loadData(from provider: NSItemProvider, typeIdentifier: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
