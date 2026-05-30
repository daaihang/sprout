import Foundation

extension MoryAPIClient {
    struct PushRegisterPayload: Encodable, Sendable, Equatable {
        var deviceID: String
        var apnsToken: String
        var timezone: String
        var hasQuestionReady: Bool
        var notificationsEnabled: Bool
        var analysisReadyEnabled: Bool
        var dailyQuestionEnabled: Bool
        var reflectionReadyEnabled: Bool
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
            case analysisReadyEnabled = "analysis_ready_enabled"
            case dailyQuestionEnabled = "daily_question_enabled"
            case reflectionReadyEnabled = "reflection_ready_enabled"
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

    static func pushRegisterPayload(
        deviceID: String,
        apnsToken: String,
        timezone: String,
        hasQuestionReady: Bool,
        notificationPreferences: NotificationPreferences,
        intelligencePreferences: IntelligencePreferences,
        semanticSearchEnabled: Bool,
        quietStart: String?,
        quietEnd: String?
    ) -> PushRegisterPayload {
        PushRegisterPayload(
            deviceID: deviceID,
            apnsToken: apnsToken,
            timezone: timezone,
            hasQuestionReady: hasQuestionReady,
            notificationsEnabled: notificationPreferences.enabled,
            analysisReadyEnabled: notificationPreferences.analysisReadyEnabled,
            dailyQuestionEnabled: notificationPreferences.dailyQuestionEnabled,
            reflectionReadyEnabled: notificationPreferences.reflectionReadyEnabled,
            deliveryPace: notificationPreferences.resolvedFrequencyStrategy.rawValue,
            maxPerDay: notificationPreferences.maxPerDay,
            minimumMinutesBetweenNotifications: notificationPreferences.resolvedMinimumMinutesBetweenNotifications,
            quietStart: quietStart,
            quietEnd: quietEnd,
            richPreviewsEnabled: notificationPreferences.richPreviewsEnabled,
            localIntelligenceEnabled: intelligencePreferences.localIntelligenceEnabled,
            cloudIntelligenceEnabled: intelligencePreferences.cloudIntelligenceEnabled,
            semanticSearchEnabled: semanticSearchEnabled,
            homeSuggestionsEnabled: intelligencePreferences.homeSuggestionsEnabled
        )
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

        enum CodingKeys: String, CodingKey {
            case accepted
            case userID = "user_id"
            case queuedCount = "queued_count"
            case skippedCount = "skipped_count"
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

}

extension MoryAPIClient.PushRegisterPayload {
    var registrationDigestComponents: [String] {
        [
            deviceID,
            apnsToken,
            timezone,
            String(hasQuestionReady),
            String(notificationsEnabled),
            String(analysisReadyEnabled),
            String(dailyQuestionEnabled),
            String(reflectionReadyEnabled),
            deliveryPace,
            String(maxPerDay),
            String(minimumMinutesBetweenNotifications),
            quietStart ?? "",
            quietEnd ?? "",
            String(richPreviewsEnabled),
            String(localIntelligenceEnabled),
            String(cloudIntelligenceEnabled),
            String(semanticSearchEnabled),
            String(homeSuggestionsEnabled),
        ]
    }
}
