import Foundation

struct RecordAnalysisSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var recordID: UUID
    var tags: [String]
    var emotionLabel: String
    var insight: String
    var followUpQuestion: String?
    var entities: [EntityReference]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        tags: [String],
        emotionLabel: String,
        insight: String,
        followUpQuestion: String? = nil,
        entities: [EntityReference] = [],
        createdAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.tags = tags
        self.emotionLabel = emotionLabel
        self.insight = insight
        self.followUpQuestion = followUpQuestion
        self.entities = entities
        self.createdAt = createdAt
    }
}
