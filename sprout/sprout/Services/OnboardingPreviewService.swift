import Foundation
import Observation

@Observable
@MainActor
final class OnboardingPreviewService {
    struct PreviewResult: Decodable {
        let tags: [String]
        let emotion: Emotion
        let entities: [Entity]
        let candidateEdges: [CandidateEdge]
        let insight: String
        let summary: String?
        let followUp: FollowUp?
        let mode: String

        struct Emotion: Decodable {
            let label: String
            let intensity: Int?
            let confidence: Double?
        }

        struct Entity: Decodable {
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

        struct CandidateEdge: Decodable {
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

        struct FollowUp: Decodable {
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
            case mode
        }
    }

    var isLoading = false
    var previewText = ""
    var previewResult: PreviewResult? = nil
    var latestAnalysisSnapshot: RecordAnalysisSnapshot? = nil
    var errorMessage: String? = nil

    private let aggregateBuilder = SproutMemoryAggregateBuilder()
    private let memoryRepository: SproutMemoryRepository
    private let dateFormatter = ISO8601DateFormatter()

    init(memoryRepository: SproutMemoryRepository = SproutMemoryRepository()) {
        self.memoryRepository = memoryRepository
    }

    func runPreview() async {
        let content = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            errorMessage = "Write a short memory to preview the AI reflection."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let aggregate = aggregateBuilder.buildPreviewAggregate(from: content)
        let payload = PreviewAnalyzeRequest(
            schemaVersion: "record_aggregate.v1",
            clientVersion: "sprout.ios",
            analysisReason: "preview",
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

        do {
            var request = URLRequest(url: try endpoint("/api/onboarding/analyze-preview"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
            let result = try JSONDecoder().decode(PreviewResult.self, from: data)
            previewResult = result

            let analysis = mapToAnalysisSnapshot(result: result, recordID: aggregate.recordShell.id)
            latestAnalysisSnapshot = analysis
            memoryRepository.setAnalysis(analysis, aggregate: aggregate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mapToAnalysisSnapshot(result: PreviewResult, recordID: UUID) -> RecordAnalysisSnapshot {
        let entities = result.entities.compactMap { entity -> EntityReference? in
            guard let kind = EntityKind(rawValue: entity.kind.lowercased()) else { return nil }
            return EntityReference(
                kind: kind,
                name: entity.name,
                confidence: entity.confidence
            )
        }
        let mergedTags = Array(NSOrderedSet(array: result.tags + entities.filter { $0.kind == .theme }.map(\.name))) as? [String] ?? result.tags
        return RecordAnalysisSnapshot(
            recordID: recordID,
            tags: mergedTags,
            emotionLabel: result.emotion.label,
            insight: result.summary?.isEmpty == false ? (result.summary ?? result.insight) : result.insight,
            followUpQuestion: result.followUp?.question,
            entities: entities,
            createdAt: .now
        )
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
            let message = (try? JSONDecoder().decode(ServerErrorResponse.self, from: data).error) ?? "Preview request failed (\(httpResponse.statusCode))"
            throw OnboardingPreviewError.server(message)
        }
    }
}

private struct PreviewAnalyzeRequest: Codable, Sendable {
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

enum OnboardingPreviewError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "MORY_API_BASE_URL is not configured."
        case .invalidResponse:
            return "Invalid server response."
        case let .server(message):
            return message
        }
    }
}
