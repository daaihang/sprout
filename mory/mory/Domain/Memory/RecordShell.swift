import Foundation

enum CaptureSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case composer
    case voice
    case photo
    case audio
    case importFile
    case manual

    var id: String { rawValue }
}

struct RecordShell: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var captureSource: CaptureSource
    var rawText: String
    var userMood: String?
    var userIntensity: Int?
    var inputContext: String?
    var artifactIDs: [UUID]
    var captureProvenance: CaptureProvenance?
    var debugFixtureSeededAt: Date?

    init(
        id: UUID = UUID(),
        title: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        captureSource: CaptureSource,
        rawText: String,
        userMood: String? = nil,
        userIntensity: Int? = nil,
        inputContext: String? = nil,
        artifactIDs: [UUID] = [],
        captureProvenance: CaptureProvenance? = nil,
        debugFixtureSeededAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.captureSource = captureSource
        self.rawText = rawText
        self.userMood = userMood
        self.userIntensity = userIntensity
        self.inputContext = inputContext
        self.artifactIDs = artifactIDs
        self.captureProvenance = captureProvenance
        self.debugFixtureSeededAt = debugFixtureSeededAt
    }
}
