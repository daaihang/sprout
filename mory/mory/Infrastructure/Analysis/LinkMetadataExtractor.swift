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
    func extract(urlString: String) async -> LinkMetadataResult? {
        guard let url = normalizedURL(from: urlString) else { return nil }

        do {
            let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)
            let imageData = await loadImageData(from: metadata)
            let siteName = siteName(from: metadata, fallbackURL: url)
            return LinkMetadataResult(
                url: url.absoluteString,
                title: metadata.title?.trimmedOrNil,
                summary: siteName,
                siteName: siteName,
                imageURL: nil,
                imageData: imageData
            )
        } catch {
            return LinkMetadataResult(
                url: url.absoluteString,
                title: nil,
                summary: nil,
                siteName: url.host(percentEncoded: false),
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
