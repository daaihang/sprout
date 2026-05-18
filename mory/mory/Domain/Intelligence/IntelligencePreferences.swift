import Foundation

enum DailyQuestionTone: String, Codable, CaseIterable, Identifiable, Sendable {
    case journalPrompt
    case memoryRevisit
    case lifeOrganization
    case evidenceBased
    case reflective

    var id: String { rawValue }
}

enum SensitiveTopicPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case allow
    case homeOnly
    case askBeforeShowing
    case suppress

    var id: String { rawValue }
}

struct NotificationPreferences: Codable, Hashable, Sendable {
    var enabled: Bool
    var backgroundDoneEnabled: Bool
    var dailyQuestionEnabled: Bool
    var repeatedThemeEnabled: Bool
    var stageFormingEnabled: Bool
    var revisitEnabled: Bool
    var maxPerDay: Int
    var quietHoursStartHour: Int?
    var quietHoursEndHour: Int?
    var richPreviewsEnabled: Bool

    init(
        enabled: Bool = false,
        backgroundDoneEnabled: Bool = true,
        dailyQuestionEnabled: Bool = false,
        repeatedThemeEnabled: Bool = true,
        stageFormingEnabled: Bool = true,
        revisitEnabled: Bool = true,
        maxPerDay: Int = 2,
        quietHoursStartHour: Int? = 22,
        quietHoursEndHour: Int? = 8,
        richPreviewsEnabled: Bool = false
    ) {
        self.enabled = enabled
        self.backgroundDoneEnabled = backgroundDoneEnabled
        self.dailyQuestionEnabled = dailyQuestionEnabled
        self.repeatedThemeEnabled = repeatedThemeEnabled
        self.stageFormingEnabled = stageFormingEnabled
        self.revisitEnabled = revisitEnabled
        self.maxPerDay = max(0, maxPerDay)
        self.quietHoursStartHour = quietHoursStartHour
        self.quietHoursEndHour = quietHoursEndHour
        self.richPreviewsEnabled = richPreviewsEnabled
    }
}

struct IntelligencePreferences: Identifiable, Codable, Hashable, Sendable {
    static let schemaVersion = 1
    static let defaultSyncKey = "intelligence-preferences-default"

    var id: UUID
    var syncKey: String
    var schemaVersion: Int
    var localIntelligenceEnabled: Bool
    var cloudIntelligenceEnabled: Bool
    var voiceRefinementEnabled: Bool
    var semanticSearchEnabled: Bool
    var homeSuggestionsEnabled: Bool
    var dailyQuestionsEnabled: Bool
    var notificationPreferences: NotificationPreferences
    var questionTone: DailyQuestionTone
    var sensitiveTopicPolicy: SensitiveTopicPolicy
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        syncKey: String = IntelligencePreferences.defaultSyncKey,
        schemaVersion: Int = IntelligencePreferences.schemaVersion,
        localIntelligenceEnabled: Bool = true,
        cloudIntelligenceEnabled: Bool = true,
        voiceRefinementEnabled: Bool = false,
        semanticSearchEnabled: Bool = true,
        homeSuggestionsEnabled: Bool = true,
        dailyQuestionsEnabled: Bool = false,
        notificationPreferences: NotificationPreferences = NotificationPreferences(),
        questionTone: DailyQuestionTone = .evidenceBased,
        sensitiveTopicPolicy: SensitiveTopicPolicy = .askBeforeShowing,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.localIntelligenceEnabled = localIntelligenceEnabled
        self.cloudIntelligenceEnabled = cloudIntelligenceEnabled
        self.voiceRefinementEnabled = voiceRefinementEnabled
        self.semanticSearchEnabled = semanticSearchEnabled
        self.homeSuggestionsEnabled = homeSuggestionsEnabled
        self.dailyQuestionsEnabled = dailyQuestionsEnabled
        self.notificationPreferences = notificationPreferences
        self.questionTone = questionTone
        self.sensitiveTopicPolicy = sensitiveTopicPolicy
        self.updatedAt = updatedAt
    }

    static var defaults: IntelligencePreferences {
        IntelligencePreferences()
    }
}

struct V6FeatureFlags: Identifiable, Codable, Hashable, Sendable {
    static let schemaVersion = 1
    static let defaultSyncKey = "v6-feature-flags-default"

    var id: UUID
    var syncKey: String
    var schemaVersion: Int
    var intelligenceJobs: Bool
    var entityProfiles: Bool
    var clarificationQuestions: Bool
    var homeGrid: Bool
    var semanticSearch: Bool
    var dailyQuestions: Bool
    var localNotifications: Bool
    var cloudQuestionSuggestions: Bool
    var cloudChapterSuggestions: Bool
    var multimediaViews: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        syncKey: String = V6FeatureFlags.defaultSyncKey,
        schemaVersion: Int = V6FeatureFlags.schemaVersion,
        intelligenceJobs: Bool = false,
        entityProfiles: Bool = false,
        clarificationQuestions: Bool = false,
        homeGrid: Bool = false,
        semanticSearch: Bool = false,
        dailyQuestions: Bool = false,
        localNotifications: Bool = false,
        cloudQuestionSuggestions: Bool = false,
        cloudChapterSuggestions: Bool = false,
        multimediaViews: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.intelligenceJobs = intelligenceJobs
        self.entityProfiles = entityProfiles
        self.clarificationQuestions = clarificationQuestions
        self.homeGrid = homeGrid
        self.semanticSearch = semanticSearch
        self.dailyQuestions = dailyQuestions
        self.localNotifications = localNotifications
        self.cloudQuestionSuggestions = cloudQuestionSuggestions
        self.cloudChapterSuggestions = cloudChapterSuggestions
        self.multimediaViews = multimediaViews
        self.updatedAt = updatedAt
    }

    static var defaults: V6FeatureFlags {
        V6FeatureFlags()
    }
}
