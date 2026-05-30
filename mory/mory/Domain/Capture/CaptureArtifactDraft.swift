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

// MARK: - Content structs

struct TextArtifactContent: Hashable, Sendable {
    var title: String?
    var body: String
}

struct PhotoArtifactContent: Hashable, Sendable {
    var title: String?
    var summary: String
    var filename: String
    var imageData: Data?
    var thumbnailData: Data?
    var ocrText: String = ""
    var photoMetadata: [String: String] = [:]
}

struct AudioArtifactContent: Hashable, Sendable {
    var title: String?
    var summary: String
    var filename: String
    var audioData: Data?
    var transcriptionText: String = ""
    var languageCode: String?
    var transcriptionConfidence: Double?
    var durationSeconds: Double?
}

struct VideoArtifactContent: Hashable, Sendable {
    var title: String?
    var summary: String
    var filename: String
    var videoData: Data?
    var thumbnailData: Data?
    var videoMetadata: [String: String] = [:]
}

struct LivePhotoArtifactContent: Hashable, Sendable {
    var title: String?
    var summary: String
    var stillFilename: String
    var videoFilename: String
    var stillImageData: Data?
    var pairedVideoData: Data?
    var thumbnailData: Data?
    var metadata: [String: String] = [:]
}

struct LocationArtifactContent: Hashable, Sendable {
    var title: String?
    var summary: String
    var latitude: Double?
    var longitude: Double?
}

struct LinkArtifactContent: Hashable, Sendable {
    var title: String?
    var url: String
    var note: String?
    var summary: String?
    var metadata: [String: String] = [:]
    var thumbnailData: Data?
}

struct TodoArtifactContent: Hashable, Sendable {
    var title: String
    var note: String?
}

struct PromptAnswerArtifactContent: Hashable, Sendable {
    var prompt: String
    var answer: String?
    var source: String
}

struct PersonContextArtifactContent: Hashable, Sendable {
    var name: String
    var note: String?
    var photoData: Data?
    var metadata: [String: String] = [:]
}

struct WeatherArtifactContent: Hashable, Sendable {
    var condition: String
    var temperatureCelsius: Double
    var humidity: Double
    var windSpeedKmh: Double
    var uvIndex: Int
    var latitude: Double?
    var longitude: Double?
    var conditionCode: String?
    var symbolName: String?
    var isDaylight: Bool?
}

struct MusicArtifactContent: Hashable, Sendable {
    var trackName: String
    var artistName: String
    var albumName: String
    var durationSeconds: Int
    var artworkURL: String?
    var artworkData: Data?
    var artworkPalette: MusicArtworkPalette?
}

// MARK: - CaptureArtifactContent

enum CaptureArtifactContent: Hashable, Sendable {
    case text(TextArtifactContent)
    case photo(PhotoArtifactContent)
    case audio(AudioArtifactContent)
    case video(VideoArtifactContent)
    case livePhoto(LivePhotoArtifactContent)
    case location(LocationArtifactContent)
    case link(LinkArtifactContent)
    case todo(TodoArtifactContent)
    case promptAnswer(PromptAnswerArtifactContent)
    case personContext(PersonContextArtifactContent)
    case weather(WeatherArtifactContent)
    case music(MusicArtifactContent)

    var stableID: String {
        switch self {
        case let .text(c):
            return "text-\(c.title ?? c.body)"
        case let .photo(c):
            return "photo-\(c.title ?? c.summary)-\(c.filename)"
        case let .audio(c):
            return "audio-\(c.title ?? c.summary)-\(c.filename)"
        case let .video(c):
            return "video-\(c.title ?? c.summary)-\(c.filename)"
        case let .livePhoto(c):
            return "live-photo-\(c.title ?? c.summary)-\(c.stillFilename)-\(c.videoFilename)"
        case let .location(c):
            return "location-\(c.title ?? c.summary)"
        case let .link(c):
            return "link-\(c.title ?? c.url)"
        case let .todo(c):
            return "todo-\(c.title)-\(c.note ?? "")"
        case let .promptAnswer(c):
            return "prompt-\(c.source)-\(c.prompt)-\(c.answer ?? "")"
        case let .personContext(c):
            return "person-\(c.name)-\(c.note ?? "")"
        case let .weather(c):
            return "weather-\(c.condition)-\(c.temperatureCelsius)"
        case let .music(c):
            return "music-\(c.trackName)-\(c.artistName)"
        }
    }

    var captureSummary: String {
        switch self {
        case let .text(c):
            return [c.title?.trimmedOrNil, c.body.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? c.body.trimmedOrNil
                ?? c.title?.trimmedOrNil
                ?? "Untitled Memory"
        case let .photo(c):
            return [c.title?.trimmedOrNil, c.summary.trimmedOrNil, c.filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? c.summary.trimmedOrNil
                ?? c.title?.trimmedOrNil
                ?? c.filename
        case let .audio(c):
            return [c.title?.trimmedOrNil, c.summary.trimmedOrNil, c.filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? c.summary.trimmedOrNil
                ?? c.title?.trimmedOrNil
                ?? c.filename
        case let .video(c):
            return [c.title?.trimmedOrNil, c.summary.trimmedOrNil, c.filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? c.summary.trimmedOrNil
                ?? c.title?.trimmedOrNil
                ?? c.filename
        case let .livePhoto(c):
            return [c.title?.trimmedOrNil, c.summary.trimmedOrNil, c.stillFilename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? c.summary.trimmedOrNil
                ?? c.title?.trimmedOrNil
                ?? c.stillFilename
        case let .location(c):
            var components = [c.title?.trimmedOrNil, c.summary.trimmedOrNil].compactMap { $0 }
            if let latitude = c.latitude {
                components.append(String(latitude))
            }
            if let longitude = c.longitude {
                components.append(String(longitude))
            }
            return components.joined(separator: " • ").trimmedOrNil
                ?? c.summary.trimmedOrNil
                ?? c.title?.trimmedOrNil
                ?? "Location capture"
        case let .link(c):
            return [c.title?.trimmedOrNil, c.summary?.trimmedOrNil, c.note?.trimmedOrNil, c.url.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? c.summary?.trimmedOrNil
                ?? c.note?.trimmedOrNil
                ?? c.title?.trimmedOrNil
                ?? c.url
        case let .todo(c):
            return [c.title.trimmedOrNil, c.note?.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? c.note?.trimmedOrNil
                ?? c.title
        case let .promptAnswer(c):
            return [c.source.trimmedOrNil, c.prompt.trimmedOrNil, c.answer?.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? c.prompt
        case let .personContext(c):
            return [c.name.trimmedOrNil, c.note?.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? c.name
        case let .weather(c):
            return "\(c.condition) \(String(format: "%.0f", c.temperatureCelsius))°C · Humidity \(String(format: "%.0f", c.humidity * 100))%"
        case let .music(c):
            return [c.trackName, c.artistName, c.albumName].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }
}

// MARK: - CaptureArtifactDraft

struct CaptureArtifactDraft: Hashable, Sendable, Identifiable {
    var draftID: UUID
    var origin: CaptureArtifactOrigin
    var provenance: CaptureProvenance?
    var content: CaptureArtifactContent

    init(
        draftID: UUID = UUID(),
        origin: CaptureArtifactOrigin,
        provenance: CaptureProvenance? = nil,
        content: CaptureArtifactContent
    ) {
        self.draftID = draftID
        self.origin = origin
        self.provenance = provenance
        self.content = content
    }

    var id: String { draftID.uuidString }
    var contentStableID: String { content.stableID }
    var captureSummary: String { content.captureSummary }

    func withOrigin(_ origin: CaptureArtifactOrigin) -> CaptureArtifactDraft {
        var copy = self; copy.origin = origin; return copy
    }

    func withProvenance(_ provenance: CaptureProvenance?) -> CaptureArtifactDraft {
        var copy = self; copy.provenance = provenance; return copy
    }
}

// MARK: - Static factories (call-site compatibility)

extension CaptureArtifactDraft {
    static func text(title: String? = nil, body: String, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .text(TextArtifactContent(title: title, body: body)))
    }

    static func photo(title: String? = nil, summary: String, filename: String, imageData: Data? = nil, thumbnailData: Data? = nil, ocrText: String = "", photoMetadata: [String: String] = [:], origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .photo(PhotoArtifactContent(title: title, summary: summary, filename: filename, imageData: imageData, thumbnailData: thumbnailData, ocrText: ocrText, photoMetadata: photoMetadata)))
    }

    static func audio(
        title: String? = nil,
        summary: String,
        filename: String,
        audioData: Data? = nil,
        transcriptionText: String = "",
        languageCode: String? = nil,
        transcriptionConfidence: Double? = nil,
        durationSeconds: Double? = nil,
        origin: CaptureArtifactOrigin = .manual,
        provenance: CaptureProvenance? = nil
    ) -> CaptureArtifactDraft {
        CaptureArtifactDraft(
            origin: origin,
            provenance: provenance,
            content: .audio(
                AudioArtifactContent(
                    title: title,
                    summary: summary,
                    filename: filename,
                    audioData: audioData,
                    transcriptionText: transcriptionText,
                    languageCode: languageCode,
                    transcriptionConfidence: transcriptionConfidence,
                    durationSeconds: durationSeconds
                )
            )
        )
    }

    static func video(title: String? = nil, summary: String, filename: String, videoData: Data? = nil, thumbnailData: Data? = nil, videoMetadata: [String: String] = [:], origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .video(VideoArtifactContent(title: title, summary: summary, filename: filename, videoData: videoData, thumbnailData: thumbnailData, videoMetadata: videoMetadata)))
    }

    static func livePhoto(title: String? = nil, summary: String, stillFilename: String, videoFilename: String, stillImageData: Data? = nil, pairedVideoData: Data? = nil, thumbnailData: Data? = nil, metadata: [String: String] = [:], origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .livePhoto(LivePhotoArtifactContent(title: title, summary: summary, stillFilename: stillFilename, videoFilename: videoFilename, stillImageData: stillImageData, pairedVideoData: pairedVideoData, thumbnailData: thumbnailData, metadata: metadata)))
    }

    static func location(title: String? = nil, summary: String, latitude: Double? = nil, longitude: Double? = nil, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .location(LocationArtifactContent(title: title, summary: summary, latitude: latitude, longitude: longitude)))
    }

    static func link(title: String? = nil, url: String, note: String? = nil, summary: String? = nil, metadata: [String: String] = [:], thumbnailData: Data? = nil, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .link(LinkArtifactContent(title: title, url: url, note: note, summary: summary, metadata: metadata, thumbnailData: thumbnailData)))
    }

    static func todo(title: String, note: String? = nil, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .todo(TodoArtifactContent(title: title, note: note)))
    }

    static func promptAnswer(prompt: String, answer: String? = nil, source: String, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .promptAnswer(PromptAnswerArtifactContent(prompt: prompt, answer: answer, source: source)))
    }

    static func personContext(name: String, note: String? = nil, photoData: Data? = nil, metadata: [String: String] = [:], origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .personContext(PersonContextArtifactContent(name: name, note: note, photoData: photoData, metadata: metadata)))
    }

    static func weather(condition: String, temperatureCelsius: Double, humidity: Double, windSpeedKmh: Double, uvIndex: Int, latitude: Double? = nil, longitude: Double? = nil, conditionCode: String? = nil, symbolName: String? = nil, isDaylight: Bool? = nil, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .weather(WeatherArtifactContent(condition: condition, temperatureCelsius: temperatureCelsius, humidity: humidity, windSpeedKmh: windSpeedKmh, uvIndex: uvIndex, latitude: latitude, longitude: longitude, conditionCode: conditionCode, symbolName: symbolName, isDaylight: isDaylight)))
    }

    static func music(trackName: String, artistName: String, albumName: String, durationSeconds: Int, artworkURL: String? = nil, artworkData: Data? = nil, artworkPalette: MusicArtworkPalette? = nil, origin: CaptureArtifactOrigin = .manual, provenance: CaptureProvenance? = nil) -> CaptureArtifactDraft {
        CaptureArtifactDraft(origin: origin, provenance: provenance, content: .music(MusicArtifactContent(trackName: trackName, artistName: artistName, albumName: albumName, durationSeconds: durationSeconds, artworkURL: artworkURL, artworkData: artworkData, artworkPalette: artworkPalette)))
    }
}
