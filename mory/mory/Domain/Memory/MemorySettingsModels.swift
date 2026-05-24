import Foundation

enum UserSettingsAppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum UserSettingsContextSelection: String, CaseIterable, Identifiable, Codable, Sendable {
    case allAvailable
    case locationWeatherOnly
    case manual

    var id: String { rawValue }
}

enum UserSettingsInsightFrequency: String, CaseIterable, Identifiable, Codable, Sendable {
    case low
    case balanced
    case high

    var id: String { rawValue }
}

enum UserSettingsPromptTone: String, CaseIterable, Identifiable, Codable, Sendable {
    case concise
    case balanced
    case reflective

    var id: String { rawValue }
}

struct UserSettingsPreference: Identifiable, Codable, Hashable, Sendable {
    static let schemaVersion = 2
    static let defaultSyncKey = "user-settings-default"

    var id: UUID
    var syncKey: String
    var schemaVersion: Int
    var updatedAt: Date
    var appearanceMode: UserSettingsAppearanceMode
    var voiceLanguageIdentifier: String?
    var linkAutoDetectEnabled: Bool
    var defaultContextSelection: UserSettingsContextSelection
    var insightFrequency: UserSettingsInsightFrequency
    var promptTone: UserSettingsPromptTone
    var detailPresentationStrategy: MemoryDetailPresentationStrategy
    var fixedDetailPresentationMode: MemoryDetailPresentationMode

    init(
        id: UUID = UUID(),
        syncKey: String = UserSettingsPreference.defaultSyncKey,
        schemaVersion: Int = UserSettingsPreference.schemaVersion,
        updatedAt: Date = .now,
        appearanceMode: UserSettingsAppearanceMode = .system,
        voiceLanguageIdentifier: String? = nil,
        linkAutoDetectEnabled: Bool = true,
        defaultContextSelection: UserSettingsContextSelection = .allAvailable,
        insightFrequency: UserSettingsInsightFrequency = .balanced,
        promptTone: UserSettingsPromptTone = .balanced,
        detailPresentationStrategy: MemoryDetailPresentationStrategy = .ruleBased,
        fixedDetailPresentationMode: MemoryDetailPresentationMode = .story
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.appearanceMode = appearanceMode
        self.voiceLanguageIdentifier = voiceLanguageIdentifier
        self.linkAutoDetectEnabled = linkAutoDetectEnabled
        self.defaultContextSelection = defaultContextSelection
        self.insightFrequency = insightFrequency
        self.promptTone = promptTone
        self.detailPresentationStrategy = detailPresentationStrategy
        self.fixedDetailPresentationMode = fixedDetailPresentationMode
    }

    static var defaults: UserSettingsPreference {
        UserSettingsPreference()
    }
}
