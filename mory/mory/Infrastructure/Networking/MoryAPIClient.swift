import Foundation

struct MoryAuthResponse: Decodable, Sendable {
    struct User: Decodable, Sendable {
        let id: String
        let tier: String
    }

    let accessToken: String
    let refreshToken: String?
    let expiresAt: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
}

struct MoryAPIClient: Sendable {
    static let backgroundSessionID = "dev.mory.api.background"

    struct ReflectionPayload: Encodable, Sendable {
        var recordShell: AnalyzeRequestPayload.RecordShellPayload
        var artifacts: [AnalyzeRequestPayload.ArtifactPayload]
        var linkedArcID: String?
        var knownEntities: [AnalyzeRequestPayload.KnownEntityPayload]
        var prompt: String?
        var debugOptions: AnalyzeRequestPayload.DebugOptionsPayload? = AnalyzeRequestPayload.DebugOptionsPayload.current()

        enum CodingKeys: String, CodingKey {
            case recordShell = "record_shell"
            case artifacts
            case linkedArcID = "linked_arc_id"
            case knownEntities = "known_entities"
            case prompt
            case debugOptions = "debug_options"
        }
    }

    struct ReflectionResponse: Decodable, Sendable {
        let title: String
        let body: String
        let evidenceSummary: String
        let confidence: Double
        let sourceRecordIDs: [String]

        enum CodingKeys: String, CodingKey {
            case title
            case body
            case evidenceSummary = "evidence_summary"
            case confidence
            case sourceRecordIDs = "source_record_ids"
        }
    }

    struct CloudIntelligenceUsage: Codable, Sendable, Equatable {
        let inputTokens: Int?
        let outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    struct CloudIntelligenceMeta: Codable, Sendable, Equatable {
        let provider: String
        let model: String
        let usage: CloudIntelligenceUsage?
        let requestID: String?
        let promptVersion: String?

        enum CodingKeys: String, CodingKey {
            case provider
            case model
            case usage
            case requestID = "request_id"
            case promptVersion = "prompt_version"
        }
    }

    struct CloudIntelligenceEvalCase: Decodable, Sendable, Equatable {
        let operation: String
        let success: Bool
        let provider: String?
        let model: String?
        let error: String?
        let errorClass: String?
        let retryable: Bool?

        enum CodingKeys: String, CodingKey {
            case operation
            case success
            case provider
            case model
            case error
            case errorClass = "error_class"
            case retryable
        }
    }

    struct CloudIntelligenceEvalResponse: Decodable, Sendable, Equatable {
        let promptVersion: String
        let requestID: String?
        let cases: [CloudIntelligenceEvalCase]

        enum CodingKeys: String, CodingKey {
            case promptVersion = "prompt_version"
            case requestID = "request_id"
            case cases
        }
    }

    struct TranscriptRefinementPayload: Encodable, Sendable, Equatable {
        var schemaVersion: Int = 1
        var locale: String?
        var recordID: String?
        var audioArtifactID: String?
        var rawTranscript: String
        var style: String = "clean_spoken_memory"
        var allowTitle: Bool = true

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case locale
            case recordID = "record_id"
            case audioArtifactID = "audio_artifact_id"
            case rawTranscript = "raw_transcript"
            case style
            case allowTitle = "allow_title"
        }
    }

    struct TranscriptEdit: Decodable, Sendable, Equatable {
        let kind: String
        let summary: String
    }

    struct TranscriptRefinementResponse: Decodable, Sendable, Equatable {
        let schemaVersion: Int
        let refinedTranscript: String
        let suggestedTitle: String?
        let edits: [TranscriptEdit]
        let meta: CloudIntelligenceMeta?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case refinedTranscript = "refined_transcript"
            case suggestedTitle = "suggested_title"
            case edits
            case meta
        }
    }

    struct IntelligenceTargetPayload: Codable, Sendable, Equatable {
        var type: String
        var id: String
        var kind: String?
    }

    struct EvidenceSnippetPayload: Codable, Sendable, Equatable {
        var recordID: String?
        var artifactID: String?
        var snippet: String
        var createdAt: String?

        enum CodingKeys: String, CodingKey {
            case recordID = "record_id"
            case artifactID = "artifact_id"
            case snippet
            case createdAt = "created_at"
        }
    }

    struct KnownProfilePayload: Codable, Sendable, Equatable {
        var displayName: String?
        var aliases: [String]?
        var relationshipToUser: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case aliases
            case relationshipToUser = "relationship_to_user"
        }
    }

    struct QuestionSuggestionPreferencesPayload: Codable, Sendable, Equatable {
        var allowSensitiveQuestions: Bool = false
        var questionTone: String?

        enum CodingKeys: String, CodingKey {
            case allowSensitiveQuestions = "allow_sensitive_questions"
            case questionTone = "question_tone"
        }
    }

    struct QuestionSuggestionPayload: Encodable, Sendable, Equatable {
        var schemaVersion: Int = 1
        var locale: String?
        var target: IntelligenceTargetPayload
        var evidence: [EvidenceSnippetPayload]
        var knownProfile: KnownProfilePayload?
        var userPreferences: QuestionSuggestionPreferencesPayload?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case locale
            case target
            case evidence
            case knownProfile = "known_profile"
            case userPreferences = "user_preferences"
        }
    }

    struct QuestionCandidateResponse: Codable, Sendable, Equatable {
        var kind: String
        var prompt: String
        var reason: String
        var candidateAnswers: [String]
        var confidence: Double
        var sensitivity: String

        enum CodingKeys: String, CodingKey {
            case kind
            case prompt
            case reason
            case candidateAnswers = "candidate_answers"
            case confidence
            case sensitivity
        }
    }

    struct QuestionSuggestionResponse: Decodable, Sendable, Equatable {
        let schemaVersion: Int
        let questions: [QuestionCandidateResponse]
        let meta: CloudIntelligenceMeta?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case questions
            case meta
        }
    }

    struct TimeWindowPayload: Codable, Sendable, Equatable {
        var start: String
        var end: String
    }

    struct ChapterSignalPayload: Codable, Sendable, Equatable {
        var kind: String
        var label: String
        var recordCount: Int
        var salience: Double

        enum CodingKeys: String, CodingKey {
            case kind
            case label
            case recordCount = "record_count"
            case salience
        }
    }

    struct ChapterSuggestionPayload: Encodable, Sendable, Equatable {
        var schemaVersion: Int = 1
        var locale: String?
        var timeWindow: TimeWindowPayload
        var signals: [ChapterSignalPayload]
        var evidenceSnippets: [EvidenceSnippetPayload]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case locale
            case timeWindow = "time_window"
            case signals
            case evidenceSnippets = "evidence_snippets"
        }
    }

    struct ChapterCandidateResponse: Decodable, Sendable, Equatable {
        let title: String
        let summary: String
        let evidenceRecordIDs: [String]
        let confidence: Double
        let requiresConfirmation: Bool

        enum CodingKeys: String, CodingKey {
            case title
            case summary
            case evidenceRecordIDs = "evidence_record_ids"
            case confidence
            case requiresConfirmation = "requires_confirmation"
        }
    }

    struct ChapterSuggestionResponse: Decodable, Sendable, Equatable {
        let schemaVersion: Int
        let chapterCandidates: [ChapterCandidateResponse]
        let meta: CloudIntelligenceMeta?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case chapterCandidates = "chapter_candidates"
            case meta
        }
    }

    struct PhotoSemanticAnalysisPayload: Encodable, Sendable, Equatable {
        var schemaVersion: Int = 1
        var locale: String?
        var recordID: String?
        var photoArtifactID: String?
        var localLabels: [String]
        var ocrText: String?
        var captionHint: String?
        var metadata: [String: String]?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case locale
            case recordID = "record_id"
            case photoArtifactID = "photo_artifact_id"
            case localLabels = "local_labels"
            case ocrText = "ocr_text"
            case captionHint = "caption_hint"
            case metadata
        }
    }

    struct PhotoSemanticAnalysisResponse: Decodable, Sendable, Equatable {
        let schemaVersion: Int
        let semanticSummary: String
        let suggestedTitle: String?
        let tags: [String]
        let objects: [String]
        let textHighlights: [String]
        let safety: String
        let confidence: Double
        let meta: CloudIntelligenceMeta?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case semanticSummary = "semantic_summary"
            case suggestedTitle = "suggested_title"
            case tags
            case objects
            case textHighlights = "text_highlights"
            case safety
            case confidence
            case meta
        }
    }

    struct NotificationIntentPreferencesPayload: Codable, Sendable, Equatable {
        var maxPerDay: Int?
        var quietHoursStart: String?
        var quietHoursEnd: String?
        var richPreviewsEnabled: Bool

        enum CodingKeys: String, CodingKey {
            case maxPerDay = "max_per_day"
            case quietHoursStart = "quiet_hours_start"
            case quietHoursEnd = "quiet_hours_end"
            case richPreviewsEnabled = "rich_previews_enabled"
        }
    }

    struct NotificationIntentSuggestionPayload: Encodable, Sendable, Equatable {
        var schemaVersion: Int = 1
        var locale: String?
        var timeZone: String?
        var trigger: String
        var recentEvidence: [EvidenceSnippetPayload]
        var question: QuestionCandidateResponse?
        var preferences: NotificationIntentPreferencesPayload?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case locale
            case timeZone = "time_zone"
            case trigger
            case recentEvidence = "recent_evidence"
            case question
            case preferences
        }
    }

    struct NotificationIntentCandidateResponse: Decodable, Sendable, Equatable {
        let kind: String
        let privacyLevel: String
        let title: String
        let body: String
        let deepLink: String?
        let scheduledAt: String?

        enum CodingKeys: String, CodingKey {
            case kind
            case privacyLevel = "privacy_level"
            case title
            case body
            case deepLink = "deep_link"
            case scheduledAt = "scheduled_at"
        }
    }

    struct NotificationIntentSuggestionResponse: Decodable, Sendable, Equatable {
        let schemaVersion: Int
        let intent: NotificationIntentCandidateResponse
        let meta: CloudIntelligenceMeta?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case intent
            case meta
        }
    }

    struct PushRegisterPayload: Encodable, Sendable, Equatable {
        var deviceID: String
        var apnsToken: String
        var timezone: String
        var hasQuestionReady: Bool
        var notificationsEnabled: Bool
        var backgroundDoneEnabled: Bool
        var dailyQuestionEnabled: Bool
        var repeatedThemeEnabled: Bool
        var stageFormingEnabled: Bool
        var revisitEnabled: Bool
        var deliveryPace: String
        var maxPerDay: Int
        var minimumMinutesBetweenNotifications: Int
        var quietStart: String?
        var quietEnd: String?
        var richPreviewsEnabled: Bool
        var localIntelligenceEnabled: Bool
        var cloudIntelligenceEnabled: Bool
        var semanticSearchEnabled: Bool
        var homeSuggestionsEnabled: Bool

        enum CodingKeys: String, CodingKey {
            case deviceID = "device_id"
            case apnsToken = "apns_token"
            case timezone
            case hasQuestionReady = "has_question_ready"
            case notificationsEnabled = "notifications_enabled"
            case backgroundDoneEnabled = "background_done_enabled"
            case dailyQuestionEnabled = "daily_question_enabled"
            case repeatedThemeEnabled = "repeated_theme_enabled"
            case stageFormingEnabled = "stage_forming_enabled"
            case revisitEnabled = "revisit_enabled"
            case deliveryPace = "delivery_pace"
            case maxPerDay = "max_per_day"
            case minimumMinutesBetweenNotifications = "minimum_minutes_between_notifications"
            case quietStart = "quiet_start"
            case quietEnd = "quiet_end"
            case richPreviewsEnabled = "rich_previews_enabled"
            case localIntelligenceEnabled = "local_intelligence_enabled"
            case cloudIntelligenceEnabled = "cloud_intelligence_enabled"
            case semanticSearchEnabled = "semantic_search_enabled"
            case homeSuggestionsEnabled = "home_suggestions_enabled"
        }
    }

    struct PushRegisterResponse: Decodable, Sendable, Equatable {
        let registered: Bool
        let userID: String

        enum CodingKeys: String, CodingKey {
            case registered
            case userID = "user_id"
        }
    }

    struct PushDeliveryTargetPayload: Codable, Sendable, Equatable {
        var type: String
        var id: String
        var parentRecordID: String?
        var artifactKind: String?
        var entityKind: String?
        var label: String?
        var sourceRecordIDs: [String]

        enum CodingKeys: String, CodingKey {
            case type
            case id
            case parentRecordID = "parent_record_id"
            case artifactKind = "artifact_kind"
            case entityKind = "entity_kind"
            case label
            case sourceRecordIDs = "source_record_ids"
        }
    }

    struct PushDeliveryPayloadEnvelope: Codable, Sendable, Equatable {
        var schemaVersion: Int = 1
        var intentID: String
        var kind: String
        var title: String
        var body: String
        var privacyLevel: String
        var deepLink: String?
        var deliveryChannel: String = "remote"
        var target: PushDeliveryTargetPayload
        var scheduledAt: String

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case intentID = "intent_id"
            case kind
            case title
            case body
            case privacyLevel = "privacy_level"
            case deepLink = "deep_link"
            case deliveryChannel = "delivery_channel"
            case target
            case scheduledAt = "scheduled_at"
        }
    }

    struct PushEnqueuePayload: Encodable, Sendable, Equatable {
        var intentID: String
        var kind: String
        var title: String
        var body: String
        var targetType: String
        var targetID: String
        var privacyLevel: String
        var deepLink: String?
        var target: PushDeliveryTargetPayload
        var payload: PushDeliveryPayloadEnvelope
        var scheduledAt: String

        enum CodingKeys: String, CodingKey {
            case intentID = "intent_id"
            case kind
            case title
            case body
            case targetType = "target_type"
            case targetID = "target_id"
            case privacyLevel = "privacy_level"
            case deepLink = "deep_link"
            case target
            case payload
            case scheduledAt = "scheduled_at"
        }
    }

    struct PushEnqueueResponse: Decodable, Sendable, Equatable {
        let accepted: Bool
        let userID: String
        let queuedCount: Int
        let skippedCount: Int
        let sentCount: Int
        let failedCount: Int
        let retriedCount: Int?
        let permanentFailedCount: Int?

        enum CodingKeys: String, CodingKey {
            case accepted
            case userID = "user_id"
            case queuedCount = "queued_count"
            case skippedCount = "skipped_count"
            case sentCount = "sent_count"
            case failedCount = "failed_count"
            case retriedCount = "retried_count"
            case permanentFailedCount = "permanent_failed_count"
        }
    }

    struct PushDeliveryWritebackPayload: Codable, Sendable, Equatable {
        var deviceID: String
        var intentID: String
        var action: String
        var kind: String
        var targetType: String
        var targetID: String
        var occurredAt: String

        enum CodingKeys: String, CodingKey {
            case deviceID = "device_id"
            case intentID = "intent_id"
            case action
            case kind
            case targetType = "target_type"
            case targetID = "target_id"
            case occurredAt = "occurred_at"
        }
    }

    struct PushDeliveryWritebackResponse: Decodable, Sendable, Equatable {
        let accepted: Bool
        let userID: String

        enum CodingKeys: String, CodingKey {
            case accepted
            case userID = "user_id"
        }
    }

    enum APIError: LocalizedError {
        case invalidResponse
        case unauthorized
        case server(statusCode: Int, message: String, body: String?)
        case network(String)
        case decoding(String, body: String?)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid server response."
            case .unauthorized:
                return "Analysis authorization failed."
            case let .server(statusCode, message, _):
                return "Server error \(statusCode): \(message)"
            case let .network(message):
                return "Network error: \(message)"
            case let .decoding(message, _):
                return "Response decoding failed: \(message)"
            }
        }
    }

    struct DebugErrorSnapshot: Sendable {
        let requestID: String?
        let statusCode: Int?
        let responseBody: String?
        let rawErrorBody: String?
        let failedStage: String?
        let errorDescription: String
    }

    struct ErrorEnvelope: Decodable {
        let error: String?
    }

    private actor DebugTraceStore {
        var latest: DebugErrorSnapshot?
        var latestRequestID: String?

        func update(_ snapshot: DebugErrorSnapshot?) {
            latest = snapshot
            latestRequestID = snapshot?.requestID
        }

        func current() -> DebugErrorSnapshot? {
            latest
        }

        func setRequestID(_ requestID: String?) {
            latestRequestID = requestID
        }

        func currentRequestID() -> String? {
            latestRequestID
        }
    }

    private let configuration: MoryAPIConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let debugTraceBox = DebugTraceStore()

    init(
        configuration: MoryAPIConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    var baseURL: URL {
        configuration.baseURL
    }

    func authenticate(identityToken: String) async throws -> MoryAuthResponse {
        struct Payload: Encodable {
            let identityToken: String

            enum CodingKeys: String, CodingKey {
                case identityToken = "identity_token"
            }
        }

        var request = URLRequest(url: configuration.url(for: configuration.authPath))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(Payload(identityToken: identityToken))

        do {
            let (data, response) = try await session.data(for: request)
            return try decodeResponse(data: data, response: response, as: MoryAuthResponse.self, failedStage: "auth_apple")
        } catch {
            throw normalize(error: error, failedStage: "auth_apple")
        }
    }

    func analyzeRecords(
        payload: AnalyzeRequestPayload,
        bearerToken: String
    ) async throws -> AnalyzeResponseEnvelope {
        var request = URLRequest(url: configuration.url(for: configuration.analysisPath))
        let requestID = makeDebugRequestID(prefix: "analysis")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: AnalyzeResponseEnvelope.self, failedStage: "analysis", requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: "analysis")
        }
    }

    func analyzeRecordsV7(
        payload: AnalyzeV7RequestPayload,
        bearerToken: String
    ) async throws -> AnalyzeV7ResponseEnvelope {
        var request = URLRequest(url: configuration.url(for: "/api/analyze/v7"))
        let requestID = makeDebugRequestID(prefix: "analysis-v7")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: AnalyzeV7ResponseEnvelope.self, failedStage: "analysis_v7", requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: "analysis_v7")
        }
    }

    func generateReflection(
        payload: ReflectionPayload,
        bearerToken: String
    ) async throws -> ReflectionResponse {
        var request = URLRequest(url: configuration.url(for: "/api/reflections/generate"))
        let requestID = makeDebugRequestID(prefix: "reflection-generate")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: ReflectionResponse.self, failedStage: "reflection_generate", requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: "reflection_generate")
        }
    }

    func replayReflection(
        payload: ReflectionPayload,
        bearerToken: String
    ) async throws -> ReflectionResponse {
        var request = URLRequest(url: configuration.url(for: "/api/reflections/replay"))
        let requestID = makeDebugRequestID(prefix: "reflection-replay")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: ReflectionResponse.self, failedStage: "reflection_replay", requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: "reflection_replay")
        }
    }

    func refineTranscript(
        payload: TranscriptRefinementPayload,
        bearerToken: String
    ) async throws -> TranscriptRefinementResponse {
        try await postAuthenticated(
            path: "/api/intelligence/refine-transcript",
            payload: payload,
            bearerToken: bearerToken,
            requestIDPrefix: "v6-refine-transcript",
            failedStage: "v6_refine_transcript",
            responseType: TranscriptRefinementResponse.self
        )
    }

    func suggestQuestions(
        payload: QuestionSuggestionPayload,
        bearerToken: String
    ) async throws -> QuestionSuggestionResponse {
        try await postAuthenticated(
            path: "/api/intelligence/suggest-questions",
            payload: payload,
            bearerToken: bearerToken,
            requestIDPrefix: "v6-suggest-questions",
            failedStage: "v6_suggest_questions",
            responseType: QuestionSuggestionResponse.self
        )
    }

    func suggestChapters(
        payload: ChapterSuggestionPayload,
        bearerToken: String
    ) async throws -> ChapterSuggestionResponse {
        try await postAuthenticated(
            path: "/api/intelligence/suggest-chapters",
            payload: payload,
            bearerToken: bearerToken,
            requestIDPrefix: "v6-suggest-chapters",
            failedStage: "v6_suggest_chapters",
            responseType: ChapterSuggestionResponse.self
        )
    }

    func analyzePhotoSemantics(
        payload: PhotoSemanticAnalysisPayload,
        bearerToken: String
    ) async throws -> PhotoSemanticAnalysisResponse {
        try await postAuthenticated(
            path: "/api/intelligence/analyze-photo",
            payload: payload,
            bearerToken: bearerToken,
            requestIDPrefix: "v6-analyze-photo",
            failedStage: "v6_analyze_photo",
            responseType: PhotoSemanticAnalysisResponse.self
        )
    }

    func suggestNotificationIntent(
        payload: NotificationIntentSuggestionPayload,
        bearerToken: String
    ) async throws -> NotificationIntentSuggestionResponse {
        try await postAuthenticated(
            path: "/api/intelligence/suggest-notification-intent",
            payload: payload,
            bearerToken: bearerToken,
            requestIDPrefix: "v6-suggest-notification",
            failedStage: "v6_suggest_notification",
            responseType: NotificationIntentSuggestionResponse.self
        )
    }

    func runCloudIntelligenceEval(
        bearerToken: String
    ) async throws -> CloudIntelligenceEvalResponse {
        struct EmptyPayload: Encodable {}
        return try await postAuthenticated(
            path: "/api/intelligence/eval",
            payload: EmptyPayload(),
            bearerToken: bearerToken,
            requestIDPrefix: "v6-provider-eval",
            failedStage: "v6_provider_eval",
            responseType: CloudIntelligenceEvalResponse.self
        )
    }

    func registerPushToken(
        payload: PushRegisterPayload,
        bearerToken: String
    ) async throws -> PushRegisterResponse {
        try await postAuthenticated(
            path: "/api/push/register",
            payload: payload,
            bearerToken: bearerToken,
            requestIDPrefix: "push-register",
            failedStage: "push_register",
            responseType: PushRegisterResponse.self
        )
    }

    func enqueuePush(
        payload: PushEnqueuePayload,
        bearerToken: String
    ) async throws -> PushEnqueueResponse {
        try await postAuthenticated(
            path: "/api/push/enqueue",
            payload: payload,
            bearerToken: bearerToken,
            requestIDPrefix: "push-enqueue",
            failedStage: "push_enqueue",
            responseType: PushEnqueueResponse.self
        )
    }

    func writeBackPushDelivery(
        payload: PushDeliveryWritebackPayload,
        bearerToken: String
    ) async throws -> PushDeliveryWritebackResponse {
        try await postAuthenticated(
            path: "/api/push/delivery-writeback",
            payload: payload,
            bearerToken: bearerToken,
            requestIDPrefix: "push-delivery-writeback",
            failedStage: "push_delivery_writeback",
            responseType: PushDeliveryWritebackResponse.self
        )
    }

    func fetchServerMetricsText() async throws -> String {
        var request = URLRequest(url: configuration.url(for: "/metrics"))
        let requestID = makeDebugRequestID(prefix: "server-metrics")
        request.httpMethod = "GET"
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                throw APIError.server(statusCode: httpResponse.statusCode, message: body ?? "metrics request failed", body: body)
            }
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            throw normalize(error: error, failedStage: "server_metrics")
        }
    }

    func latestDebugError() async -> DebugErrorSnapshot? {
        await debugTraceBox.current()
    }

    func latestDebugRequestID() async -> String? {
        await debugTraceBox.currentRequestID()
    }

    func refreshToken(refreshToken: String) async throws -> MoryAuthResponse {
        var request = URLRequest(url: configuration.url(for: "/api/auth/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            return try decodeResponse(data: data, response: response, as: MoryAuthResponse.self, failedStage: "auth_refresh")
        } catch {
            throw normalize(error: error, failedStage: "auth_refresh")
        }
    }

    private func postAuthenticated<Payload: Encodable, Response: Decodable>(
        path: String,
        payload: Payload,
        bearerToken: String,
        requestIDPrefix: String,
        failedStage: String,
        responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: configuration.url(for: path))
        let requestID = makeDebugRequestID(prefix: requestIDPrefix)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: responseType, failedStage: failedStage, requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: failedStage)
        }
    }

    private func decodeResponse<T: Decodable>(
        data: Data,
        response: URLResponse,
        as type: T.Type,
        failedStage: String = "analysis",
        requestID: String? = nil
    ) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                let body = String(data: data, encoding: .utf8)
                let apiError = APIError.decoding(error.localizedDescription, body: body)
                setDebugError(requestID: responseRequestID(response) ?? requestID, statusCode: httpResponse.statusCode, responseBody: body, rawErrorBody: body, failedStage: failedStage, errorDescription: error.localizedDescription)
                throw apiError
            }
        case 401:
            let body = String(data: data, encoding: .utf8)
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data).error) ?? "unauthorized"
            setDebugError(requestID: responseRequestID(response) ?? requestID, statusCode: 401, responseBody: body, rawErrorBody: body, failedStage: failedStage, errorDescription: message)
            throw APIError.unauthorized
        default:
            let body = String(data: data, encoding: .utf8)
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data).error) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            setDebugError(requestID: responseRequestID(response) ?? requestID, statusCode: httpResponse.statusCode, responseBody: body, rawErrorBody: body, failedStage: failedStage, errorDescription: message)
            throw APIError.server(statusCode: httpResponse.statusCode, message: message, body: body)
        }
    }

    private func normalize(error: Error, failedStage: String) -> Error {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidResponse:
                setDebugError(requestID: nil, statusCode: nil, responseBody: nil, rawErrorBody: nil, failedStage: failedStage, errorDescription: apiError.localizedDescription)
            case .unauthorized:
                break
            case .server:
                break
            case let .network(message):
                setDebugError(requestID: nil, statusCode: nil, responseBody: nil, rawErrorBody: nil, failedStage: failedStage, errorDescription: message)
            case .decoding:
                break
            }
            return apiError
        }

        setDebugError(
            requestID: nil,
            statusCode: nil,
            responseBody: nil,
            rawErrorBody: nil,
            failedStage: failedStage,
            errorDescription: error.localizedDescription
        )
        return APIError.network(error.localizedDescription)
    }

    private func setDebugError(
        requestID: String?,
        statusCode: Int?,
        responseBody: String?,
        rawErrorBody: String?,
        failedStage: String,
        errorDescription: String
    ) {
        let snapshot = DebugErrorSnapshot(
            requestID: requestID,
            statusCode: statusCode,
            responseBody: responseBody,
            rawErrorBody: rawErrorBody,
            failedStage: failedStage,
            errorDescription: errorDescription
        )
        Task { await debugTraceBox.update(snapshot) }
    }

    private func makeDebugRequestID(prefix: String) -> String {
        "mory-\(prefix)-\(UUID().uuidString)"
    }

    private func responseRequestID(_ response: URLResponse) -> String? {
        (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Request-ID")
    }
}
