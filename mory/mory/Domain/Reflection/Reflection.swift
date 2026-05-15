import Foundation

enum ReflectionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case pattern
    case relationship
    case phase
    case record

    var id: String { rawValue }
}

enum ReflectionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case suggested
    case saved
    case archived
    case dismissed

    var id: String { rawValue }
}

extension ReflectionStatus {
    var label: String {
        switch self {
        case .suggested:
            return String(localized: "reflection.status.suggested")
        case .saved:
            return String(localized: "reflection.status.saved")
        case .archived:
            return String(localized: "reflection.status.archived")
        case .dismissed:
            return String(localized: "reflection.status.dismissed")
        }
    }
}

struct ReflectionSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var type: ReflectionType
    var title: String
    var body: String
    var evidenceSummary: String
    var confidence: Double
    var status: ReflectionStatus
    var linkedTemporalArcID: UUID?
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var sourceEntityIDs: [UUID]
    var createdAt: Date
    var savedAt: Date?
    var dismissedAt: Date?

    init(
        id: UUID = UUID(),
        type: ReflectionType,
        title: String,
        body: String,
        evidenceSummary: String,
        confidence: Double,
        status: ReflectionStatus,
        linkedTemporalArcID: UUID? = nil,
        sourceRecordIDs: [UUID],
        sourceArtifactIDs: [UUID],
        sourceEntityIDs: [UUID] = [],
        createdAt: Date,
        savedAt: Date? = nil,
        dismissedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.evidenceSummary = evidenceSummary
        self.confidence = confidence
        self.status = status
        self.linkedTemporalArcID = linkedTemporalArcID
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceEntityIDs = sourceEntityIDs
        self.createdAt = createdAt
        self.savedAt = savedAt
        self.dismissedAt = dismissedAt
    }
}

extension ReflectionSnapshot {
    var statusLabel: String { status.label }
}
