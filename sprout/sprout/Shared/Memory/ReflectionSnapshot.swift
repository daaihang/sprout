import Foundation

enum ReflectionType: String, Codable, CaseIterable, Sendable {
    case pattern
    case relationship
    case phase
    case record
}

struct ReflectionSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var type: ReflectionType
    var title: String
    var body: String
    var linkedTemporalArcID: UUID?
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var sourceEntityIDs: [UUID]
    var createdAt: Date
}
