import Foundation

@MainActor
extension UserSettingsPreferenceStore {
    convenience init(domainModel: UserSettingsPreference) {
        self.init(
            id: domainModel.id,
            syncKey: domainModel.syncKey,
            schemaVersion: domainModel.schemaVersion,
            updatedAt: domainModel.updatedAt,
            appearanceModeRawValue: domainModel.appearanceMode.rawValue,
            voiceLanguageIdentifier: domainModel.voiceLanguageIdentifier,
            linkAutoDetectEnabled: domainModel.linkAutoDetectEnabled,
            defaultContextSelectionRawValue: domainModel.defaultContextSelection.rawValue,
            insightFrequencyRawValue: domainModel.insightFrequency.rawValue,
            promptToneRawValue: domainModel.promptTone.rawValue,
            detailPresentationStrategyRawValue: domainModel.detailPresentationStrategy.rawValue,
            fixedDetailPresentationModeRawValue: domainModel.fixedDetailPresentationMode.rawValue
        )
    }

    var domainModel: UserSettingsPreference {
        UserSettingsPreference(
            id: id,
            syncKey: syncKey,
            schemaVersion: schemaVersion,
            updatedAt: updatedAt,
            appearanceMode: UserSettingsAppearanceMode(rawValue: appearanceModeRawValue) ?? .system,
            voiceLanguageIdentifier: voiceLanguageIdentifier,
            linkAutoDetectEnabled: linkAutoDetectEnabled,
            defaultContextSelection: UserSettingsContextSelection(rawValue: defaultContextSelectionRawValue) ?? .allAvailable,
            insightFrequency: UserSettingsInsightFrequency(rawValue: insightFrequencyRawValue) ?? .balanced,
            promptTone: UserSettingsPromptTone(rawValue: promptToneRawValue) ?? .balanced,
            detailPresentationStrategy: MemoryDetailPresentationStrategy(rawValue: detailPresentationStrategyRawValue ?? "") ?? .ruleBased,
            fixedDetailPresentationMode: MemoryDetailPresentationMode(rawValue: fixedDetailPresentationModeRawValue ?? "") ?? .story
        )
    }

    func apply(domainModel: UserSettingsPreference) {
        id = domainModel.id
        syncKey = domainModel.syncKey
        schemaVersion = domainModel.schemaVersion
        updatedAt = domainModel.updatedAt
        appearanceModeRawValue = domainModel.appearanceMode.rawValue
        voiceLanguageIdentifier = domainModel.voiceLanguageIdentifier
        linkAutoDetectEnabled = domainModel.linkAutoDetectEnabled
        defaultContextSelectionRawValue = domainModel.defaultContextSelection.rawValue
        insightFrequencyRawValue = domainModel.insightFrequency.rawValue
        promptToneRawValue = domainModel.promptTone.rawValue
        detailPresentationStrategyRawValue = domainModel.detailPresentationStrategy.rawValue
        fixedDetailPresentationModeRawValue = domainModel.fixedDetailPresentationMode.rawValue
    }
}

@MainActor
extension MemoryDetailPresentationPreferenceStore {
    convenience init(domainModel: MemoryDetailPresentationPreference) {
        self.init(
            id: domainModel.id,
            recordID: domainModel.recordID,
            schemaVersion: domainModel.schemaVersion,
            modeRawValue: domainModel.mode.rawValue,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: MemoryDetailPresentationPreference {
        MemoryDetailPresentationPreference(
            id: id,
            recordID: recordID,
            schemaVersion: schemaVersion,
            mode: MemoryDetailPresentationMode(rawValue: modeRawValue) ?? .story,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: MemoryDetailPresentationPreference) {
        id = domainModel.id
        recordID = domainModel.recordID
        schemaVersion = domainModel.schemaVersion
        modeRawValue = domainModel.mode.rawValue
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension HomeBoardPreferenceStore {
    convenience init(domainModel: HomeBoardItemPreference) {
        self.init(
            id: domainModel.id,
            schemaVersion: domainModel.schemaVersion,
            syncKey: domainModel.syncKey,
            boardKey: domainModel.boardKey,
            cardKey: domainModel.cardKey,
            cardKindRawValue: domainModel.cardKind.rawValue,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            isPinned: domainModel.isPinned,
            isHidden: domainModel.isHidden,
            dismissedAt: domainModel.dismissedAt,
            widthColumns: domainModel.widthColumns,
            heightUnits: domainModel.heightUnits,
            userSortIndex: domainModel.userSortIndex,
            acceptedAt: domainModel.acceptedAt,
            feedbackAdjustment: domainModel.feedbackAdjustment,
            feedbackUpdatedAt: domainModel.feedbackUpdatedAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: HomeBoardItemPreference {
        HomeBoardItemPreference(
            id: id,
            schemaVersion: schemaVersion,
            syncKey: syncKey,
            boardKey: boardKey,
            cardKey: cardKey,
            cardKind: HomeBoardCardKind(rawValue: cardKindRawValue) ?? .memory,
            targetType: CompositionTargetType(rawValue: targetTypeRawValue) ?? .record,
            targetID: targetID,
            isPinned: isPinned,
            isHidden: isHidden,
            dismissedAt: dismissedAt,
            widthColumns: widthColumns,
            heightUnits: heightUnits,
            userSortIndex: userSortIndex,
            acceptedAt: acceptedAt,
            feedbackAdjustment: feedbackAdjustment ?? 0,
            feedbackUpdatedAt: feedbackUpdatedAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: HomeBoardItemPreference) {
        id = domainModel.id
        schemaVersion = domainModel.schemaVersion
        syncKey = domainModel.syncKey
        boardKey = domainModel.boardKey
        cardKey = domainModel.cardKey
        cardKindRawValue = domainModel.cardKind.rawValue
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        isPinned = domainModel.isPinned
        isHidden = domainModel.isHidden
        dismissedAt = domainModel.dismissedAt
        widthColumns = domainModel.widthColumns
        heightUnits = domainModel.heightUnits
        userSortIndex = domainModel.userSortIndex
        acceptedAt = domainModel.acceptedAt
        feedbackAdjustment = domainModel.feedbackAdjustment
        feedbackUpdatedAt = domainModel.feedbackUpdatedAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension IntelligencePreferenceStore {
    convenience init(preferences: IntelligencePreferences, featureFlags: V6FeatureFlags) {
        self.init(
            id: preferences.id,
            syncKey: preferences.syncKey,
            schemaVersion: preferences.schemaVersion,
            preferencesData: PersistenceCoding.encode(preferences),
            featureFlagsData: PersistenceCoding.encode(featureFlags),
            updatedAt: max(preferences.updatedAt, featureFlags.updatedAt)
        )
    }

    var preferencesDomainModel: IntelligencePreferences {
        PersistenceCoding.decode(IntelligencePreferences.self, from: preferencesData) ?? .defaults
    }

    var featureFlagsDomainModel: V6FeatureFlags {
        PersistenceCoding.decode(V6FeatureFlags.self, from: featureFlagsData) ?? .defaults
    }

    func apply(preferences: IntelligencePreferences) {
        id = preferences.id
        syncKey = preferences.syncKey
        schemaVersion = preferences.schemaVersion
        preferencesData = PersistenceCoding.encode(preferences)
        updatedAt = preferences.updatedAt
    }

    func apply(featureFlags: V6FeatureFlags) {
        featureFlagsData = PersistenceCoding.encode(featureFlags)
        updatedAt = featureFlags.updatedAt
    }
}

