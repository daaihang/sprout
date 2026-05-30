import Foundation

enum ArtifactKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case photo
    case audio
    case video
    case livePhoto
    case music
    case link
    case location
    case weather
    case todo
    case document

    var id: String { rawValue }
}

enum ArtifactPayload: Codable, Hashable, Sendable {
    case text(String)
    case media(ArtifactMediaRef)
    case metadata([String: String])
}

struct ArtifactMediaRef: Codable, Hashable, Sendable {
    var filename: String
    var mimeType: String
    var byteCount: Int?
    var localIdentifier: String?

    init(
        filename: String,
        mimeType: String,
        byteCount: Int? = nil,
        localIdentifier: String? = nil
    ) {
        self.filename = filename
        self.mimeType = mimeType
        self.byteCount = byteCount
        self.localIdentifier = localIdentifier
    }
}

struct Artifact: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var recordID: UUID
    var kind: ArtifactKind
    var title: String
    var summary: String
    var textContent: String
    var payload: ArtifactPayload?
    var mediaRef: ArtifactMediaRef?
    var metadata: [String: String]
    var binaryPayload: Data?
    var previewPayload: Data?
    var captureProvenance: CaptureProvenance?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        kind: ArtifactKind,
        title: String,
        summary: String,
        textContent: String = "",
        payload: ArtifactPayload? = nil,
        mediaRef: ArtifactMediaRef? = nil,
        metadata: [String: String] = [:],
        binaryPayload: Data? = nil,
        previewPayload: Data? = nil,
        captureProvenance: CaptureProvenance? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.kind = kind
        self.title = title
        self.summary = summary
        self.textContent = textContent
        self.payload = payload
        self.mediaRef = mediaRef
        self.metadata = metadata
        self.binaryPayload = binaryPayload
        self.previewPayload = previewPayload
        self.captureProvenance = captureProvenance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
