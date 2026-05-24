import Foundation
import SwiftData

@Model
final class UserSettingsPreferenceStore {
    @Attribute(.unique) var syncKey: String
    var id: UUID
    var schemaVersion: Int
    var updatedAt: Date
    var appearanceModeRawValue: String
    var voiceLanguageIdentifier: String?
    var linkAutoDetectEnabled: Bool
    var defaultContextSelectionRawValue: String
    var insightFrequencyRawValue: String
    var promptToneRawValue: String
    var detailPresentationStrategyRawValue: String?
    var fixedDetailPresentationModeRawValue: String?

    init(
        id: UUID = UUID(),
        syncKey: String = UserSettingsPreference.defaultSyncKey,
        schemaVersion: Int = UserSettingsPreference.schemaVersion,
        updatedAt: Date,
        appearanceModeRawValue: String,
        voiceLanguageIdentifier: String?,
        linkAutoDetectEnabled: Bool,
        defaultContextSelectionRawValue: String,
        insightFrequencyRawValue: String,
        promptToneRawValue: String,
        detailPresentationStrategyRawValue: String? = nil,
        fixedDetailPresentationModeRawValue: String? = nil
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.appearanceModeRawValue = appearanceModeRawValue
        self.voiceLanguageIdentifier = voiceLanguageIdentifier
        self.linkAutoDetectEnabled = linkAutoDetectEnabled
        self.defaultContextSelectionRawValue = defaultContextSelectionRawValue
        self.insightFrequencyRawValue = insightFrequencyRawValue
        self.promptToneRawValue = promptToneRawValue
        self.detailPresentationStrategyRawValue = detailPresentationStrategyRawValue
        self.fixedDetailPresentationModeRawValue = fixedDetailPresentationModeRawValue
    }
}

@Model
final class MemoryDetailPresentationPreferenceStore {
    @Attribute(.unique) var recordID: UUID
    var id: UUID
    var schemaVersion: Int
    var modeRawValue: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        schemaVersion: Int = MemoryDetailPresentationPreference.schemaVersion,
        modeRawValue: String,
        updatedAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.schemaVersion = schemaVersion
        self.modeRawValue = modeRawValue
        self.updatedAt = updatedAt
    }
}

@Model
final class QualityTuningPreferenceStore {
    @Attribute(.unique) var syncKey: String
    var id: UUID
    var schemaVersion: Int
    var promptProfileRawValue: String
    var thresholdsData: Data?
    var notes: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        syncKey: String = QualityTuningPreference.defaultSyncKey,
        promptProfileRawValue: String,
        thresholdsData: Data?,
        notes: String,
        updatedAt: Date
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.syncKey = syncKey
        self.promptProfileRawValue = promptProfileRawValue
        self.thresholdsData = thresholdsData
        self.notes = notes
        self.updatedAt = updatedAt
    }
}

@Model
final class HomeBoardPreferenceStore {
    @Attribute(.unique) var syncKey: String
    var id: UUID
    var schemaVersion: Int
    var boardKey: String
    var cardKey: String
    var cardKindRawValue: String
    var targetTypeRawValue: String
    var targetID: UUID
    var isPinned: Bool
    var isHidden: Bool
    var dismissedAt: Date?
    var widthColumns: Int?
    var heightUnits: Int?
    var userSortIndex: Double?
    var acceptedAt: Date?
    var feedbackAdjustment: Double?
    var feedbackUpdatedAt: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = HomeBoardItemPreference.schemaVersion,
        syncKey: String,
        boardKey: String,
        cardKey: String,
        cardKindRawValue: String,
        targetTypeRawValue: String,
        targetID: UUID,
        isPinned: Bool,
        isHidden: Bool,
        dismissedAt: Date?,
        widthColumns: Int? = nil,
        heightUnits: Int? = nil,
        userSortIndex: Double? = nil,
        acceptedAt: Date? = nil,
        feedbackAdjustment: Double? = nil,
        feedbackUpdatedAt: Date? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.syncKey = syncKey
        self.boardKey = boardKey
        self.cardKey = cardKey
        self.cardKindRawValue = cardKindRawValue
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.isPinned = isPinned
        self.isHidden = isHidden
        self.dismissedAt = dismissedAt
        self.widthColumns = widthColumns
        self.heightUnits = heightUnits
        self.userSortIndex = userSortIndex
        self.acceptedAt = acceptedAt
        self.feedbackAdjustment = feedbackAdjustment
        self.feedbackUpdatedAt = feedbackUpdatedAt
        self.updatedAt = updatedAt
    }
}

@Model
final class IntelligencePreferenceStore {
    @Attribute(.unique) var syncKey: String
    var id: UUID
    var schemaVersion: Int
    var preferencesData: Data?
    var featureFlagsData: Data?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        syncKey: String = IntelligencePreferences.defaultSyncKey,
        schemaVersion: Int = IntelligencePreferences.schemaVersion,
        preferencesData: Data?,
        featureFlagsData: Data?,
        updatedAt: Date
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.preferencesData = preferencesData
        self.featureFlagsData = featureFlagsData
        self.updatedAt = updatedAt
    }
}
