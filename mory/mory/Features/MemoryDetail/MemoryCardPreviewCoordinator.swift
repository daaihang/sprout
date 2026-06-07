import Foundation
@MainActor
struct MemoryCardPreviewCoordinator {
    private var managedURLs: Set<URL> = []

    mutating func previewURLs(for record: RecordShell) throws -> [URL] {
        let text = [record.displayTitle, "", record.rawText].joined(separator: "\n")
        return [try writePreviewData(Data(text.utf8), preferredFilename: "\(record.displayTitle).txt")]
    }

    mutating func previewURLs(for artifacts: [Artifact]) throws -> [URL] {
        let urls = try artifacts.compactMap { artifact in
            try previewURL(for: artifact)
        }
        if !urls.isEmpty {
            return urls
        }
        let fallback = artifacts.map { artifact in
            [artifact.title, artifact.summary, artifact.textContent]
                .compactMap(\.trimmedOrNil)
                .joined(separator: "\n")
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
        guard !fallback.isEmpty else { return [] }
        return [try writePreviewData(Data(fallback.utf8), preferredFilename: "mory-card.txt")]
    }

    mutating func clearTemporaryFiles() {
        for url in managedURLs {
            try? FileManager.default.removeItem(at: url)
        }
        managedURLs.removeAll()
    }

    private mutating func previewURL(for artifact: Artifact) throws -> URL? {
        switch artifact.kind {
        case .photo:
            guard let data = artifact.binaryPayload ?? artifact.previewPayload else { return nil }
            return try writePreviewData(data, preferredFilename: artifact.previewFilename(defaultName: "photo", fallbackExtension: "jpg"))
        case .video:
            guard let data = artifact.binaryPayload else { return nil }
            return try writePreviewData(data, preferredFilename: artifact.previewFilename(defaultName: "video", fallbackExtension: "mov"))
        case .livePhoto:
            if let stillData = artifact.previewPayload {
                return try writePreviewData(stillData, preferredFilename: artifact.previewFilename(defaultName: "live-photo", fallbackExtension: "jpg"))
            }
            guard let data = artifact.binaryPayload else { return nil }
            return try writePreviewData(data, preferredFilename: artifact.previewFilename(defaultName: "live-photo", fallbackExtension: "mov"))
        case .audio:
            guard let data = artifact.binaryPayload else { return nil }
            return try writePreviewData(data, preferredFilename: artifact.previewFilename(defaultName: "audio", fallbackExtension: "m4a"))
        case .text, .document, .todo, .location, .weather, .music, .link:
            let text = [artifact.title, artifact.summary, artifact.textContent]
                .compactMap(\.trimmedOrNil)
                .joined(separator: "\n")
            guard !text.isEmpty else { return nil }
            return try writePreviewData(Data(text.utf8), preferredFilename: artifact.previewFilename(defaultName: artifact.kind.rawValue, fallbackExtension: "txt"))
        }
    }

    private mutating func writePreviewData(_ data: Data, preferredFilename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mory-card-preview", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = Self.sanitizedFilename(preferredFilename)
        let url = directory.appendingPathComponent("\(UUID().uuidString)-\(filename)")
        try data.write(to: url, options: [.atomic])
        managedURLs.insert(url)
        return url
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let trimmed = filename.trimmedOrNil ?? "preview"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
        let sanitizedScalars = trimmed.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(sanitizedScalars).trimmedOrNil ?? "preview"
        return sanitized.contains(".") ? sanitized : "\(sanitized).txt"
    }
}

private extension Artifact {
    func previewFilename(defaultName: String, fallbackExtension: String) -> String {
        if let filename = mediaRef?.filename.trimmedOrNil {
            return filename
        }
        if let filename = metadata["filename"]?.trimmedOrNil {
            return filename
        }
        let base = title.trimmedOrNil ?? defaultName
        if base.contains(".") {
            return base
        }
        return "\(base).\(fallbackExtension)"
    }
}
