import Foundation

enum ReflectionType: String, Codable, CaseIterable, Sendable {
    case pattern
    case relationship
    case phase
    case record
}

enum ReflectionStatus: String, Codable, CaseIterable, Sendable {
    case active
    case saved
    case dismissed
}

struct ReflectionSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var type: ReflectionType
    var title: String
    var body: String
    var evidenceSummary: String?
    var confidence: Double?
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
        evidenceSummary: String? = nil,
        confidence: Double? = nil,
        status: ReflectionStatus = .active,
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

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case evidenceSummary
        case confidence
        case status
        case linkedTemporalArcID
        case sourceRecordIDs
        case sourceArtifactIDs
        case sourceEntityIDs
        case createdAt
        case savedAt
        case dismissedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ReflectionType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        evidenceSummary = try container.decodeIfPresent(String.self, forKey: .evidenceSummary)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        status = try container.decodeIfPresent(ReflectionStatus.self, forKey: .status) ?? .active
        linkedTemporalArcID = try container.decodeIfPresent(UUID.self, forKey: .linkedTemporalArcID)
        sourceRecordIDs = try container.decodeIfPresent([UUID].self, forKey: .sourceRecordIDs) ?? []
        sourceArtifactIDs = try container.decodeIfPresent([UUID].self, forKey: .sourceArtifactIDs) ?? []
        sourceEntityIDs = try container.decodeIfPresent([UUID].self, forKey: .sourceEntityIDs) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt)
        dismissedAt = try container.decodeIfPresent(Date.self, forKey: .dismissedAt)
    }
}
