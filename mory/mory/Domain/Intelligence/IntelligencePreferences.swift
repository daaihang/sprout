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

enum NotificationFrequencyStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case quiet
    case balanced
    case active
    case custom

    var id: String { rawValue }

    var defaultMaxPerDay: Int {
        switch self {
        case .quiet:
            return 1
        case .balanced:
            return 2
        case .active:
            return 4
        case .custom:
            return 2
        }
    }

    var defaultMinimumMinutesBetweenNotifications: Int {
        switch self {
        case .quiet:
            return 8 * 60
        case .balanced:
            return 4 * 60
        case .active:
            return 90
        case .custom:
            return 4 * 60
        }
    }
}

struct NotificationPreferences: Codable, Hashable, Sendable {
    var enabled: Bool
    var analysisReadyEnabled: Bool
    var dailyQuestionEnabled: Bool
    var reflectionReadyEnabled: Bool
    var frequencyStrategy: NotificationFrequencyStrategy?
    var maxPerDay: Int
    var minimumMinutesBetweenNotifications: Int?
    var quietHoursStartHour: Int?
    var quietHoursStartMinute: Int?
    var quietHoursEndHour: Int?
    var quietHoursEndMinute: Int?
    var richPreviewsEnabled: Bool

    init(
        enabled: Bool = false,
        analysisReadyEnabled: Bool = true,
        dailyQuestionEnabled: Bool = false,
        reflectionReadyEnabled: Bool = true,
        frequencyStrategy: NotificationFrequencyStrategy? = .balanced,
        maxPerDay: Int = 2,
        minimumMinutesBetweenNotifications: Int? = nil,
        quietHoursStartHour: Int? = 22,
        quietHoursStartMinute: Int? = 0,
        quietHoursEndHour: Int? = 8,
        quietHoursEndMinute: Int? = 0,
        richPreviewsEnabled: Bool = false
    ) {
        self.enabled = enabled
        self.analysisReadyEnabled = analysisReadyEnabled
        self.dailyQuestionEnabled = dailyQuestionEnabled
        self.reflectionReadyEnabled = reflectionReadyEnabled
        self.frequencyStrategy = frequencyStrategy
        self.maxPerDay = max(0, maxPerDay)
        self.minimumMinutesBetweenNotifications = minimumMinutesBetweenNotifications.map { max(0, $0) }
        self.quietHoursStartHour = quietHoursStartHour
        self.quietHoursStartMinute = quietHoursStartMinute.map { max(0, min(59, $0)) }
        self.quietHoursEndHour = quietHoursEndHour
        self.quietHoursEndMinute = quietHoursEndMinute.map { max(0, min(59, $0)) }
        self.richPreviewsEnabled = richPreviewsEnabled
    }

    var resolvedFrequencyStrategy: NotificationFrequencyStrategy {
        frequencyStrategy ?? .balanced
    }

    var resolvedMinimumMinutesBetweenNotifications: Int {
        max(
            0,
            minimumMinutesBetweenNotifications
                ?? resolvedFrequencyStrategy.defaultMinimumMinutesBetweenNotifications
        )
    }

    mutating func setReflectionReadyEnabled(_ enabled: Bool) {
        reflectionReadyEnabled = enabled
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
        voiceRefinementEnabled: Bool = true,
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
    var homeBoard: Bool
    var semanticSearch: Bool
    var dailyQuestions: Bool
    var localNotifications: Bool
    var cloudQuestionSuggestions: Bool
    var cloudChapterSuggestions: Bool
    var multimediaViews: Bool
    var analyzeMemoryDualRun: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        syncKey: String = V6FeatureFlags.defaultSyncKey,
        schemaVersion: Int = V6FeatureFlags.schemaVersion,
        intelligenceJobs: Bool = true,
        entityProfiles: Bool = true,
        clarificationQuestions: Bool = true,
        homeBoard: Bool = true,
        semanticSearch: Bool = true,
        dailyQuestions: Bool = true,
        localNotifications: Bool = true,
        cloudQuestionSuggestions: Bool = true,
        cloudChapterSuggestions: Bool = true,
        multimediaViews: Bool = true,
        analyzeMemoryDualRun: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.intelligenceJobs = intelligenceJobs
        self.entityProfiles = entityProfiles
        self.clarificationQuestions = clarificationQuestions
        self.homeBoard = homeBoard
        self.semanticSearch = semanticSearch
        self.dailyQuestions = dailyQuestions
        self.localNotifications = localNotifications
        self.cloudQuestionSuggestions = cloudQuestionSuggestions
        self.cloudChapterSuggestions = cloudChapterSuggestions
        self.multimediaViews = multimediaViews
        self.analyzeMemoryDualRun = analyzeMemoryDualRun
        self.updatedAt = updatedAt
    }

    static var defaults: V6FeatureFlags {
        V6FeatureFlags()
    }
}
