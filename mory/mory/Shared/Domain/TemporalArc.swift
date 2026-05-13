import Foundation

enum TemporalArcStatus: String, Codable, CaseIterable, Sendable {
    case candidate
    case accepted
    case archived
}

struct TemporalArc: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var summary: String
    var status: TemporalArcStatus
    var dominantTheme: String?
    var dominantEntityName: String?
    var themeLabels: [String]
    var entityNames: [String]
    var linkedReflectionID: UUID?
    var mergedFromArcIDs: [UUID]
    var mergedIntoArcID: UUID?
    var lastMergedAt: Date?
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var sourceEntityIDs: [UUID]
    var startDate: Date
    var endDate: Date
    var intensityScore: Double
    var clusterStrength: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        status: TemporalArcStatus,
        dominantTheme: String? = nil,
        dominantEntityName: String? = nil,
        themeLabels: [String],
        entityNames: [String],
        linkedReflectionID: UUID? = nil,
        mergedFromArcIDs: [UUID] = [],
        mergedIntoArcID: UUID? = nil,
        lastMergedAt: Date? = nil,
        sourceRecordIDs: [UUID],
        sourceArtifactIDs: [UUID],
        sourceEntityIDs: [UUID],
        startDate: Date,
        endDate: Date,
        intensityScore: Double,
        clusterStrength: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = status
        self.dominantTheme = dominantTheme
        self.dominantEntityName = dominantEntityName
        self.themeLabels = themeLabels
        self.entityNames = entityNames
        self.linkedReflectionID = linkedReflectionID
        self.mergedFromArcIDs = mergedFromArcIDs
        self.mergedIntoArcID = mergedIntoArcID
        self.lastMergedAt = lastMergedAt
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceEntityIDs = sourceEntityIDs
        self.startDate = startDate
        self.endDate = endDate
        self.intensityScore = intensityScore
        self.clusterStrength = clusterStrength
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
