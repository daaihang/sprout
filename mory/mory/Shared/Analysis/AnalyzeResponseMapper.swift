import Foundation

struct AnalyzeResponseMapper {
    func map(recordID: UUID, response: AnalyzeResponseEnvelope, createdAt: Date = .now) -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: recordID,
            tags: response.tags,
            emotionLabel: response.emotion.label,
            insight: response.insight,
            followUpQuestion: response.followUp?.question,
            entities: inferEntities(from: response),
            createdAt: createdAt
        )
    }

    private func inferEntities(from response: AnalyzeResponseEnvelope) -> [EntityReference] {
        let tagEntities = response.tags.map {
            EntityReference(kind: .theme, name: $0, confidence: nil)
        }
        return Array(tagEntities.prefix(4))
    }
}

struct AnalyzeResponseEnvelope: Codable, Sendable {
    struct Emotion: Codable, Sendable {
        var label: String
        var intensity: Int?
        var confidence: Double?
    }

    struct FollowUp: Codable, Sendable {
        var question: String
        var expiresAt: String?

        enum CodingKeys: String, CodingKey {
            case question
            case expiresAt = "expires_at"
        }
    }

    var tags: [String]
    var emotion: Emotion
    var insight: String
    var followUp: FollowUp?
}
