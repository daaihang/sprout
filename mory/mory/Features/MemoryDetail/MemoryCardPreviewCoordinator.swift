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

    mutating func previewURLs(for drafts: [CaptureArtifactDraft]) throws -> [URL] {
        let urls = try drafts.compactMap { draft in
            try previewURL(for: draft)
        }
        if !urls.isEmpty {
            return urls
        }
        let fallback = drafts.map(\.content.captureSummary)
            .compactMap(\.trimmedOrNil)
            .joined(separator: "\n\n")
        guard !fallback.isEmpty else { return [] }
        return [try writePreviewData(Data(fallback.utf8), preferredFilename: "mory-card-draft.txt")]
    }

    mutating func previewURLs(forAffectDrafts drafts: [AffectSnapshotDraft]) throws -> [URL] {
        let text = drafts.map { draft in
            [
                draft.labels.map(\.rawValue).joined(separator: ", ").trimmedOrNil,
                draft.evidenceSummary?.trimmedOrNil,
                draft.rawInput?.trimmedOrNil,
                draft.valence.map { String(format: "valence %.2f", $0) },
                draft.sources.map(\.rawValue).joined(separator: ", ").trimmedOrNil,
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
        guard !text.isEmpty else { return [] }
        return [try writePreviewData(Data(text.utf8), preferredFilename: "mory-affect-draft.txt")]
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

    private mutating func previewURL(for draft: CaptureArtifactDraft) throws -> URL? {
        switch draft.content {
        case let .photo(content):
            guard let data = content.imageData ?? content.thumbnailData else { return nil }
            return try writePreviewData(data, preferredFilename: draft.previewFilename(defaultName: "photo", fallbackExtension: "jpg"))
        case let .video(content):
            if let data = content.videoData {
                return try writePreviewData(data, preferredFilename: draft.previewFilename(defaultName: "video", fallbackExtension: "mov"))
            }
            guard let data = content.thumbnailData else { return nil }
            return try writePreviewData(data, preferredFilename: draft.previewFilename(defaultName: "video", fallbackExtension: "jpg"))
        case let .livePhoto(content):
            if let data = content.stillImageData ?? content.thumbnailData {
                return try writePreviewData(data, preferredFilename: draft.previewFilename(defaultName: "live-photo", fallbackExtension: "jpg"))
            }
            guard let data = content.pairedVideoData else { return nil }
            return try writePreviewData(data, preferredFilename: draft.previewFilename(defaultName: "live-photo", fallbackExtension: "mov"))
        case let .audio(content):
            guard let data = content.audioData else { return nil }
            return try writePreviewData(data, preferredFilename: draft.previewFilename(defaultName: "audio", fallbackExtension: "m4a"))
        case .text, .location, .link, .todo, .promptAnswer, .personContext, .weather, .music:
            let text = draft.content.captureSummary
            guard let summary = text.trimmedOrNil else { return nil }
            return try writePreviewData(Data(summary.utf8), preferredFilename: draft.previewFilename(defaultName: draft.previewKindName, fallbackExtension: "txt"))
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

private extension CaptureArtifactDraft {
    var previewKindName: String {
        switch content {
        case .text:
            return "text"
        case .photo:
            return "photo"
        case .audio:
            return "audio"
        case .video:
            return "video"
        case .livePhoto:
            return "live-photo"
        case .location:
            return "location"
        case .link:
            return "link"
        case .todo:
            return "todo"
        case .promptAnswer:
            return "prompt"
        case .personContext:
            return "person"
        case .weather:
            return "weather"
        case .music:
            return "music"
        }
    }

    func previewFilename(defaultName: String, fallbackExtension: String) -> String {
        let base: String
        switch content {
        case let .photo(content):
            base = content.filename.trimmedOrNil ?? content.title?.trimmedOrNil ?? defaultName
        case let .video(content):
            base = content.filename.trimmedOrNil ?? content.title?.trimmedOrNil ?? defaultName
        case let .livePhoto(content):
            base = content.stillFilename.trimmedOrNil ?? content.title?.trimmedOrNil ?? defaultName
        case let .audio(content):
            base = content.filename.trimmedOrNil ?? content.title?.trimmedOrNil ?? defaultName
        case let .text(content):
            base = content.title?.trimmedOrNil ?? defaultName
        case let .location(content):
            base = content.title?.trimmedOrNil ?? defaultName
        case let .link(content):
            base = content.title?.trimmedOrNil ?? URL(string: content.url)?.host() ?? defaultName
        case let .todo(content):
            base = content.title.trimmedOrNil ?? defaultName
        case let .promptAnswer(content):
            base = content.prompt.trimmedOrNil ?? defaultName
        case let .personContext(content):
            base = content.name.trimmedOrNil ?? defaultName
        case let .weather(content):
            base = content.condition.trimmedOrNil ?? defaultName
        case let .music(content):
            base = content.trackName.trimmedOrNil ?? defaultName
        }
        if base.contains(".") {
            return base
        }
        return "\(base).\(fallbackExtension)"
    }
}
