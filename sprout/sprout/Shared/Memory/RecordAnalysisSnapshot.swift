import Foundation

struct RecordAnalysisSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var recordID: UUID
    var tags: [String]
    var emotionLabel: String
    var insight: String
    var followUpQuestion: String?
    var entities: [EntityReference]
    var salienceScore: Double?
    var retrievalTerms: [String]
    var reflectionHint: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        tags: [String],
        emotionLabel: String,
        insight: String,
        followUpQuestion: String? = nil,
        entities: [EntityReference] = [],
        salienceScore: Double? = nil,
        retrievalTerms: [String] = [],
        reflectionHint: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.tags = tags
        self.emotionLabel = emotionLabel
        self.insight = insight
        self.followUpQuestion = followUpQuestion
        self.entities = entities
        self.salienceScore = salienceScore
        self.retrievalTerms = retrievalTerms
        self.reflectionHint = reflectionHint
        self.createdAt = createdAt
    }
}
