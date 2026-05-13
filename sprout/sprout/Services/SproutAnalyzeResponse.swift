import Foundation

struct SproutAnalyzeResponse: Decodable, Sendable {
    let tags: [String]
    let emotion: Emotion
    let entities: [Entity]
    let candidateEdges: [CandidateEdge]
    let insight: String
    let summary: String?
    let followUp: FollowUp?

    struct Emotion: Decodable, Sendable {
        let label: String
        let intensity: Int?
        let confidence: Double?
    }

    struct Entity: Decodable, Sendable {
        let kind: String
        let name: String
        let canonicalName: String?
        let confidence: Double?

        enum CodingKeys: String, CodingKey {
            case kind
            case name
            case canonicalName = "canonical_name"
            case confidence
        }
    }

    struct CandidateEdge: Decodable, Sendable {
        let fromName: String
        let fromKind: String
        let toName: String
        let toKind: String
        let relation: String

        enum CodingKeys: String, CodingKey {
            case fromName = "from_name"
            case fromKind = "from_kind"
            case toName = "to_name"
            case toKind = "to_kind"
            case relation
        }
    }

    struct FollowUp: Decodable, Sendable {
        let question: String
    }

    enum CodingKeys: String, CodingKey {
        case tags
        case emotion
        case entities
        case candidateEdges = "candidate_edges"
        case insight
        case summary
        case followUp = "follow_up"
    }
}
