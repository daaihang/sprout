import Foundation

enum ArtifactSemanticDigestSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case localCapture
    case localVision
    case localMedia
    case userProvided
    case imported

    var id: String { rawValue }
}

struct ArtifactMediaDimensions: Codable, Hashable, Sendable {
    var width: Int?
    var height: Int?

    var isEmpty: Bool {
        width == nil && height == nil
    }
}

struct ArtifactSemanticDigest: Identifiable, Codable, Hashable, Sendable {
    static let schemaVersion = 1

    let id: UUID
    var recordID: UUID
    var artifactID: UUID
    var artifactKind: ArtifactKind
    var schemaVersion: Int
    var source: ArtifactSemanticDigestSource
    var summary: String?
    var caption: String?
    var ocrText: String?
    var visualLabels: [String]
    var transcript: String?
    var languageCode: String?
    var durationSeconds: Double?
    var dimensions: ArtifactMediaDimensions?
    var captureDate: String?
    var localIdentifier: String?
    var technicalNotes: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        artifactID: UUID,
        artifactKind: ArtifactKind,
        schemaVersion: Int = ArtifactSemanticDigest.schemaVersion,
        source: ArtifactSemanticDigestSource,
        summary: String? = nil,
        caption: String? = nil,
        ocrText: String? = nil,
        visualLabels: [String] = [],
        transcript: String? = nil,
        languageCode: String? = nil,
        durationSeconds: Double? = nil,
        dimensions: ArtifactMediaDimensions? = nil,
        captureDate: String? = nil,
        localIdentifier: String? = nil,
        technicalNotes: [String] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.artifactID = artifactID
        self.artifactKind = artifactKind
        self.schemaVersion = schemaVersion
        self.source = source
        self.summary = summary
        self.caption = caption
        self.ocrText = ocrText
        self.visualLabels = visualLabels
        self.transcript = transcript
        self.languageCode = languageCode
        self.durationSeconds = durationSeconds
        self.dimensions = dimensions
        self.captureDate = captureDate
        self.localIdentifier = localIdentifier
        self.technicalNotes = technicalNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
