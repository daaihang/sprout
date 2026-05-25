import Foundation

enum CaptureArtifactOrigin: String, Codable, Hashable, Sendable, CaseIterable {
    case manual
    case context
    case imported
    case inferred
}

struct MusicArtworkPalette: Codable, Hashable, Sendable {
    let backgroundColorHex: String?
    let primaryTextColorHex: String?
    let secondaryTextColorHex: String?

    nonisolated init(
        backgroundColorHex: String? = nil,
        primaryTextColorHex: String? = nil,
        secondaryTextColorHex: String? = nil
    ) {
        self.backgroundColorHex = backgroundColorHex
        self.primaryTextColorHex = primaryTextColorHex
        self.secondaryTextColorHex = secondaryTextColorHex
    }

    nonisolated var isEmpty: Bool {
        backgroundColorHex == nil && primaryTextColorHex == nil && secondaryTextColorHex == nil
    }

    nonisolated var metadata: [String: String] {
        var metadata: [String: String] = [:]
        if let backgroundColorHex { metadata["artworkBackgroundColor"] = backgroundColorHex }
        if let primaryTextColorHex { metadata["artworkPrimaryTextColor"] = primaryTextColorHex }
        if let secondaryTextColorHex { metadata["artworkSecondaryTextColor"] = secondaryTextColorHex }
        return metadata
    }
}

struct ArtifactOriginRepairKindCount: Identifiable, Hashable, Sendable {
    let kind: ArtifactKind
    let count: Int

    var id: ArtifactKind { kind }
}

struct ArtifactOriginRepairPreview: Hashable, Sendable {
    let totalArtifactCount: Int
    let missingOriginCount: Int
    let kindCounts: [ArtifactOriginRepairKindCount]
    let generatedAt: Date
}

struct ArtifactOriginRepairResult: Hashable, Sendable {
    let repairedCount: Int
    let origin: CaptureArtifactOrigin
    let repairedArtifactIDs: [UUID]
    let generatedAt: Date
}

enum CaptureArtifactDraft: Hashable, Sendable, Identifiable {
    case text(title: String?, body: String, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case photo(title: String?, summary: String, filename: String, imageData: Data?, thumbnailData: Data?, ocrText: String = "", photoMetadata: [String: String] = [:], origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case audio(title: String?, summary: String, filename: String, audioData: Data?, transcriptionText: String = "", origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case video(title: String?, summary: String, filename: String, videoData: Data?, thumbnailData: Data? = nil, videoMetadata: [String: String] = [:], origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case location(title: String?, summary: String, latitude: Double?, longitude: Double?, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case link(title: String?, url: String, note: String?, summary: String? = nil, metadata: [String: String] = [:], thumbnailData: Data? = nil, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case todo(title: String, note: String?, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case promptAnswer(prompt: String, answer: String?, source: String, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case personContext(name: String, note: String?, photoData: Data? = nil, metadata: [String: String] = [:], origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case weather(condition: String, temperatureCelsius: Double, humidity: Double, windSpeedKmh: Double, uvIndex: Int, latitude: Double? = nil, longitude: Double? = nil, conditionCode: String? = nil, symbolName: String? = nil, isDaylight: Bool? = nil, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)
    case music(trackName: String, artistName: String, albumName: String, durationSeconds: Int, artworkURL: String?, artworkData: Data? = nil, artworkPalette: MusicArtworkPalette? = nil, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil)

    var id: String {
        switch self {
        case let .text(title, body, _, _):
            return "text-\(title ?? body)"
        case let .photo(title, summary, filename, _, _, _, _, _, _):
            return "photo-\(title ?? summary)-\(filename)"
        case let .audio(title, summary, filename, _, _, _, _):
            return "audio-\(title ?? summary)-\(filename)"
        case let .video(title, summary, filename, _, _, _, _, _):
            return "video-\(title ?? summary)-\(filename)"
        case let .location(title, summary, _, _, _, _):
            return "location-\(title ?? summary)"
        case let .link(title, url, _, _, _, _, _, _):
            return "link-\(title ?? url)"
        case let .todo(title, note, _, _):
            return "todo-\(title)-\(note ?? "")"
        case let .promptAnswer(prompt, answer, source, _, _):
            return "prompt-\(source)-\(prompt)-\(answer ?? "")"
        case let .personContext(name, note, _, _, _, _):
            return "person-\(name)-\(note ?? "")"
        case let .weather(condition, temp, _, _, _, _, _, _, _, _, _, _):
            return "weather-\(condition)-\(temp)"
        case let .music(trackName, artistName, _, _, _, _, _, _, _):
            return "music-\(trackName)-\(artistName)"
        }
    }

    var captureSummary: String {
        switch self {
        case let .text(title, body, _, _):
            return [title?.trimmedOrNil, body.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? body.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? "Untitled Memory"
        case let .photo(title, summary, filename, _, _, _, _, _, _):
            return [title?.trimmedOrNil, summary.trimmedOrNil, filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? filename
        case let .audio(title, summary, filename, _, _, _, _):
            return [title?.trimmedOrNil, summary.trimmedOrNil, filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? filename
        case let .video(title, summary, filename, _, _, _, _, _):
            return [title?.trimmedOrNil, summary.trimmedOrNil, filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? filename
        case let .location(title, summary, latitude, longitude, _, _):
            var components = [title?.trimmedOrNil, summary.trimmedOrNil].compactMap { $0 }
            if let latitude {
                components.append(String(latitude))
            }
            if let longitude {
                components.append(String(longitude))
            }
            return components.joined(separator: " • ").trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? "Location capture"
        case let .link(title, url, note, summary, _, _, _, _):
            return [title?.trimmedOrNil, summary?.trimmedOrNil, note?.trimmedOrNil, url.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary?.trimmedOrNil
                ?? note?.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? url
        case let .todo(title, note, _, _):
            return [title.trimmedOrNil, note?.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? note?.trimmedOrNil
                ?? title
        case let .promptAnswer(prompt, answer, source, _, _):
            return [source.trimmedOrNil, prompt.trimmedOrNil, answer?.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? prompt
        case let .personContext(name, note, _, _, _, _):
            return [name.trimmedOrNil, note?.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? name
        case let .weather(condition, temp, humidity, _, _, _, _, _, _, _, _, _):
            return "\(condition) \(String(format: "%.0f", temp))°C · Humidity \(String(format: "%.0f", humidity * 100))%"
        case let .music(trackName, artistName, albumName, _, _, _, _, _, _):
            return [trackName, artistName, albumName].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    var origin: CaptureArtifactOrigin {
        switch self {
        case let .text(_, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .photo(_, _, _, _, _, _, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .audio(_, _, _, _, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .video(_, _, _, _, _, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .location(_, _, _, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .link(_, _, _, _, _, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .todo(_, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .promptAnswer(_, _, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .personContext(_, _, _, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .weather(_, _, _, _, _, _, _, _, _, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        case let .music(_, _, _, _, _, _, _, origin, provenance):
            return provenance?.artifactOrigin ?? origin
        }
    }

    var provenance: CaptureProvenance? {
        switch self {
        case let .text(_, _, _, provenance),
             let .photo(_, _, _, _, _, _, _, _, provenance),
             let .audio(_, _, _, _, _, _, provenance),
             let .video(_, _, _, _, _, _, _, provenance),
             let .location(_, _, _, _, _, provenance),
             let .link(_, _, _, _, _, _, _, provenance),
             let .todo(_, _, _, provenance),
             let .promptAnswer(_, _, _, _, provenance),
             let .personContext(_, _, _, _, _, provenance),
             let .weather(_, _, _, _, _, _, _, _, _, _, _, provenance),
             let .music(_, _, _, _, _, _, _, _, provenance):
            return provenance
        }
    }

    func withOrigin(_ origin: CaptureArtifactOrigin) -> CaptureArtifactDraft {
        switch self {
        case let .text(title, body, _, provenance):
            return .text(title: title, body: body, origin: origin, provenance: provenance)
        case let .photo(title, summary, filename, imageData, thumbnailData, ocrText, photoMetadata, _, provenance):
            return .photo(
                title: title,
                summary: summary,
                filename: filename,
                imageData: imageData,
                thumbnailData: thumbnailData,
                ocrText: ocrText,
                photoMetadata: photoMetadata,
                origin: origin,
                provenance: provenance
            )
        case let .audio(title, summary, filename, audioData, transcriptionText, _, provenance):
            return .audio(
                title: title,
                summary: summary,
                filename: filename,
                audioData: audioData,
                transcriptionText: transcriptionText,
                origin: origin,
                provenance: provenance
            )
        case let .video(title, summary, filename, videoData, thumbnailData, videoMetadata, _, provenance):
            return .video(
                title: title,
                summary: summary,
                filename: filename,
                videoData: videoData,
                thumbnailData: thumbnailData,
                videoMetadata: videoMetadata,
                origin: origin,
                provenance: provenance
            )
        case let .location(title, summary, latitude, longitude, _, provenance):
            return .location(
                title: title,
                summary: summary,
                latitude: latitude,
                longitude: longitude,
                origin: origin,
                provenance: provenance
            )
        case let .link(title, url, note, summary, metadata, thumbnailData, _, provenance):
            return .link(
                title: title,
                url: url,
                note: note,
                summary: summary,
                metadata: metadata,
                thumbnailData: thumbnailData,
                origin: origin,
                provenance: provenance
            )
        case let .todo(title, note, _, provenance):
            return .todo(title: title, note: note, origin: origin, provenance: provenance)
        case let .promptAnswer(prompt, answer, source, _, provenance):
            return .promptAnswer(prompt: prompt, answer: answer, source: source, origin: origin, provenance: provenance)
        case let .personContext(name, note, photoData, metadata, _, provenance):
            return .personContext(name: name, note: note, photoData: photoData, metadata: metadata, origin: origin, provenance: provenance)
        case let .weather(condition, temperatureCelsius, humidity, windSpeedKmh, uvIndex, latitude, longitude, conditionCode, symbolName, isDaylight, _, provenance):
            return .weather(
                condition: condition,
                temperatureCelsius: temperatureCelsius,
                humidity: humidity,
                windSpeedKmh: windSpeedKmh,
                uvIndex: uvIndex,
                latitude: latitude,
                longitude: longitude,
                conditionCode: conditionCode,
                symbolName: symbolName,
                isDaylight: isDaylight,
                origin: origin,
                provenance: provenance
            )
        case let .music(trackName, artistName, albumName, durationSeconds, artworkURL, artworkData, artworkPalette, _, provenance):
            return .music(
                trackName: trackName,
                artistName: artistName,
                albumName: albumName,
                durationSeconds: durationSeconds,
                artworkURL: artworkURL,
                artworkData: artworkData,
                artworkPalette: artworkPalette,
                origin: origin,
                provenance: provenance
            )
        }
    }

    func withProvenance(_ provenance: CaptureProvenance?) -> CaptureArtifactDraft {
        switch self {
        case let .text(title, body, origin, _):
            return .text(title: title, body: body, origin: origin, provenance: provenance)
        case let .photo(title, summary, filename, imageData, thumbnailData, ocrText, photoMetadata, origin, _):
            return .photo(title: title, summary: summary, filename: filename, imageData: imageData, thumbnailData: thumbnailData, ocrText: ocrText, photoMetadata: photoMetadata, origin: origin, provenance: provenance)
        case let .audio(title, summary, filename, audioData, transcriptionText, origin, _):
            return .audio(title: title, summary: summary, filename: filename, audioData: audioData, transcriptionText: transcriptionText, origin: origin, provenance: provenance)
        case let .video(title, summary, filename, videoData, thumbnailData, videoMetadata, origin, _):
            return .video(title: title, summary: summary, filename: filename, videoData: videoData, thumbnailData: thumbnailData, videoMetadata: videoMetadata, origin: origin, provenance: provenance)
        case let .location(title, summary, latitude, longitude, origin, _):
            return .location(title: title, summary: summary, latitude: latitude, longitude: longitude, origin: origin, provenance: provenance)
        case let .link(title, url, note, summary, metadata, thumbnailData, origin, _):
            return .link(title: title, url: url, note: note, summary: summary, metadata: metadata, thumbnailData: thumbnailData, origin: origin, provenance: provenance)
        case let .todo(title, note, origin, _):
            return .todo(title: title, note: note, origin: origin, provenance: provenance)
        case let .promptAnswer(prompt, answer, source, origin, _):
            return .promptAnswer(prompt: prompt, answer: answer, source: source, origin: origin, provenance: provenance)
        case let .personContext(name, note, photoData, metadata, origin, _):
            return .personContext(name: name, note: note, photoData: photoData, metadata: metadata, origin: origin, provenance: provenance)
        case let .weather(condition, temperatureCelsius, humidity, windSpeedKmh, uvIndex, latitude, longitude, conditionCode, symbolName, isDaylight, origin, _):
            return .weather(condition: condition, temperatureCelsius: temperatureCelsius, humidity: humidity, windSpeedKmh: windSpeedKmh, uvIndex: uvIndex, latitude: latitude, longitude: longitude, conditionCode: conditionCode, symbolName: symbolName, isDaylight: isDaylight, origin: origin, provenance: provenance)
        case let .music(trackName, artistName, albumName, durationSeconds, artworkURL, artworkData, artworkPalette, origin, _):
            return .music(trackName: trackName, artistName: artistName, albumName: albumName, durationSeconds: durationSeconds, artworkURL: artworkURL, artworkData: artworkData, artworkPalette: artworkPalette, origin: origin, provenance: provenance)
        }
    }
}

struct MemoryCaptureDraft: Hashable, Sendable {
    var title: String?
    var rawText: String
    var mood: String?
    var inputContext: String?
    var captureSource: CaptureSource
    var provenance: CaptureProvenance
    var artifacts: [CaptureArtifactDraft]
    var affectSnapshots: [AffectSnapshotDraft]

    init(
        title: String? = nil,
        rawText: String,
        mood: String? = nil,
        inputContext: String? = nil,
        captureSource: CaptureSource = .composer,
        provenance: CaptureProvenance = .manualComposer,
        artifacts: [CaptureArtifactDraft] = [],
        affectSnapshots: [AffectSnapshotDraft] = []
    ) {
        self.title = title
        self.rawText = rawText
        self.mood = mood
        self.inputContext = inputContext
        self.captureSource = captureSource
        self.provenance = provenance
        self.artifacts = artifacts
        self.affectSnapshots = affectSnapshots
    }

    func withExternalInboxItemID(_ id: UUID?) -> MemoryCaptureDraft {
        var copy = self
        copy.provenance = provenance.withExternalInboxItemID(id)
        copy.artifacts = artifacts.map { artifact in
            guard let provenance = artifact.provenance else { return artifact }
            return artifact.withProvenance(provenance.withExternalInboxItemID(id))
        }
        copy.affectSnapshots = affectSnapshots.map { draft in
            var draft = draft
            if let provenance = draft.provenance {
                draft.provenance = provenance.withExternalInboxItemID(id)
            }
            return draft
        }
        return copy
    }
}
