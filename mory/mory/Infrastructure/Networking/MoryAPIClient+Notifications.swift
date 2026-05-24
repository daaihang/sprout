import Foundation

extension MoryAPIClient {
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

}
