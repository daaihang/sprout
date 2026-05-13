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

struct SproutAnalyzeService {
    private let dateFormatter = ISO8601DateFormatter()

    func analyzePreview(aggregate: SproutMemoryAggregate) async throws -> SproutAnalyzeResponse {
        try await request(path: "/api/onboarding/analyze-preview", aggregate: aggregate, bearerToken: nil, analysisReason: "preview")
    }

    func analyzeRecord(
        aggregate: SproutMemoryAggregate,
        session: AuthSessionManager.Session
    ) async throws -> SproutAnalyzeResponse {
        try await request(
            path: "/api/records/analyze",
            aggregate: aggregate,
            bearerToken: session.accessToken,
            analysisReason: "create"
        )
    }

    func mapToAnalysisSnapshot(
        response: SproutAnalyzeResponse,
        recordID: UUID,
        createdAt: Date = .now
    ) -> RecordAnalysisSnapshot {
        let entities = response.entities.compactMap { entity -> EntityReference? in
            guard let kind = EntityKind(rawValue: entity.kind.lowercased()) else { return nil }
            return EntityReference(
                kind: kind,
                name: entity.name,
                confidence: entity.confidence
            )
        }
        let mergedTags = Array(NSOrderedSet(array: response.tags + entities.filter { $0.kind == .theme }.map(\.name))) as? [String] ?? response.tags
        return RecordAnalysisSnapshot(
            recordID: recordID,
            tags: mergedTags,
            emotionLabel: response.emotion.label,
            insight: response.summary?.isEmpty == false ? (response.summary ?? response.insight) : response.insight,
            followUpQuestion: response.followUp?.question,
            entities: entities,
            createdAt: createdAt
        )
    }

    private func request(
        path: String,
        aggregate: SproutMemoryAggregate,
        bearerToken: String?,
        analysisReason: String
    ) async throws -> SproutAnalyzeResponse {
        var request = URLRequest(url: try endpoint(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(
            AnalyzeRequestPayload(
                schemaVersion: "record_aggregate.v1",
                clientVersion: "sprout.ios",
                analysisReason: analysisReason,
                recordShell: .init(
                    id: aggregate.recordShell.id.uuidString,
                    createdAt: dateFormatter.string(from: aggregate.recordShell.createdAt),
                    updatedAt: dateFormatter.string(from: aggregate.recordShell.updatedAt),
                    rawText: aggregate.recordShell.rawText,
                    captureSource: aggregate.recordShell.captureSource.rawValue,
                    userMood: aggregate.recordShell.userMood,
                    userIntensity: aggregate.recordShell.userIntensity
                ),
                artifacts: aggregate.artifacts.map {
                    .init(
                        id: $0.id.uuidString,
                        kind: $0.kind.rawValue,
                        title: $0.title,
                        summary: $0.summary,
                        textContent: $0.textContent,
                        metadata: $0.metadata
                    )
                },
                knownEntities: aggregate.knownEntities.map {
                    .init(
                        id: $0.id.uuidString,
                        kind: $0.kind.rawValue,
                        name: $0.name,
                        aliases: [],
                        confidence: $0.confidence
                    )
                }
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SproutAnalyzeResponse.self, from: data)
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: MoryConfig.apiBaseURL + path) else {
            throw OnboardingPreviewError.invalidBaseURL
        }
        return url
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnboardingPreviewError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ServerErrorResponse.self, from: data).error) ?? "Analyze request failed (\(httpResponse.statusCode))"
            throw OnboardingPreviewError.server(message)
        }
    }
}

private struct AnalyzeRequestPayload: Codable, Sendable {
    struct RecordShellPayload: Codable, Sendable {
        var id: String
        var createdAt: String
        var updatedAt: String
        var rawText: String
        var captureSource: String
        var userMood: String?
        var userIntensity: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case rawText = "raw_text"
            case captureSource = "capture_source"
            case userMood = "user_mood"
            case userIntensity = "user_intensity"
        }
    }

    struct ArtifactPayload: Codable, Sendable {
        var id: String
        var kind: String
        var title: String
        var summary: String
        var textContent: String
        var metadata: [String: String]

        enum CodingKeys: String, CodingKey {
            case id
            case kind
            case title
            case summary
            case textContent = "text_content"
            case metadata
        }
    }

    struct KnownEntityPayload: Codable, Sendable {
        var id: String
        var kind: String
        var name: String
        var aliases: [String]
        var confidence: Double?
    }

    var schemaVersion: String
    var clientVersion: String
    var analysisReason: String
    var recordShell: RecordShellPayload
    var artifacts: [ArtifactPayload]
    var knownEntities: [KnownEntityPayload]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case clientVersion = "client_version"
        case analysisReason = "analysis_reason"
        case recordShell = "record_shell"
        case artifacts
        case knownEntities = "known_entities"
    }
}
