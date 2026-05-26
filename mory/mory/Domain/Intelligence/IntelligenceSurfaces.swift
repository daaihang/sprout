import Foundation

enum HomeBoardSignalKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case clarificationQuestion
    case dailyQuestion
    case revisit
    case chapterCandidate
    case entityProfile
    case contextCluster

    var id: String { rawValue }
}

struct HomeBoardSignal: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: HomeBoardSignalKind
    var targetType: ClarificationTargetType
    var targetID: UUID
    var sourceRecordIDs: [UUID]
    var title: String
    var subtitle: String
    var priority: Double
    var reason: String
    var suggestedWidthColumns: Int
    var suggestedHeightUnits: Int
    var createdAt: Date
    var expiresAt: Date?

    init(
        id: UUID = UUID(),
        kind: HomeBoardSignalKind,
        targetType: ClarificationTargetType,
        targetID: UUID,
        sourceRecordIDs: [UUID] = [],
        title: String,
        subtitle: String,
        priority: Double = 0,
        reason: String,
        suggestedWidthColumns: Int = 2,
        suggestedHeightUnits: Int = 1,
        createdAt: Date = .now,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.targetType = targetType
        self.targetID = targetID
        self.sourceRecordIDs = sourceRecordIDs
        self.title = title
        self.subtitle = subtitle
        self.priority = priority
        self.reason = reason
        self.suggestedWidthColumns = max(1, suggestedWidthColumns)
        self.suggestedHeightUnits = max(1, suggestedHeightUnits)
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}
