import Foundation

enum TemporalArcStatus: String, Codable, CaseIterable, Sendable {
    case candidate
    case accepted
    case archived
}

struct TemporalArc: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
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
}
