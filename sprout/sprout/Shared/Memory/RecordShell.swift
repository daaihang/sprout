import Foundation

enum CaptureSource: String, Codable, CaseIterable, Sendable {
    case composer
    case voice
    case importFile
    case photo
    case manual
}

struct RecordShell: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var rawText: String
    var captureSource: CaptureSource
    var artifactIDs: [UUID]
    var userMood: String?
    var userIntensity: Int?
    var inputContext: String?

    init(
        id: UUID = UUID(),
        createdAt: Date,
        updatedAt: Date,
        rawText: String,
        captureSource: CaptureSource,
        artifactIDs: [UUID],
        userMood: String? = nil,
        userIntensity: Int? = nil,
        inputContext: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rawText = rawText
        self.captureSource = captureSource
        self.artifactIDs = artifactIDs
        self.userMood = userMood
        self.userIntensity = userIntensity
        self.inputContext = inputContext
    }
}
