import Foundation

@MainActor
private enum PersistenceCoding {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T?) -> Data? {
        guard let value else { return nil }
        return try? encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? decoder.decode(type, from: data)
    }
}

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
extension RecordShellStore {
    convenience init(domainModel: RecordShell) {
        self.init(
            id: domainModel.id,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt,
            captureSourceRawValue: domainModel.captureSource.rawValue,
            rawText: domainModel.rawText,
            userMood: domainModel.userMood,
            userIntensity: domainModel.userIntensity,
            inputContext: domainModel.inputContext,
            artifactIDs: domainModel.artifactIDs,
            debugFixtureSeededAt: domainModel.debugFixtureSeededAt
        )
    }

    var domainModel: RecordShell {
        RecordShell(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            captureSource: CaptureSource(rawValue: captureSourceRawValue) ?? .manual,
            rawText: rawText,
            userMood: userMood,
            userIntensity: userIntensity,
            inputContext: inputContext,
            artifactIDs: artifactIDs,
            debugFixtureSeededAt: debugFixtureSeededAt
        )
    }

    func apply(domainModel: RecordShell) {
        id = domainModel.id
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
        captureSourceRawValue = domainModel.captureSource.rawValue
        rawText = domainModel.rawText
        userMood = domainModel.userMood
        userIntensity = domainModel.userIntensity
        inputContext = domainModel.inputContext
        artifactIDs = domainModel.artifactIDs
        debugFixtureSeededAt = domainModel.debugFixtureSeededAt
    }
}

@MainActor
extension ArtifactStore {
    convenience init(domainModel: Artifact) {
        self.init(
            id: domainModel.id,
            recordID: domainModel.recordID,
            kindRawValue: domainModel.kind.rawValue,
            title: domainModel.title,
            summary: domainModel.summary,
            textContent: domainModel.textContent,
            payloadData: PersistenceCoding.encode(domainModel.payload),
            mediaRefData: PersistenceCoding.encode(domainModel.mediaRef),
            metadataData: PersistenceCoding.encode(domainModel.metadata),
            binaryPayload: domainModel.binaryPayload,
            previewPayload: domainModel.previewPayload,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: Artifact {
        Artifact(
            id: id,
            recordID: recordID,
            kind: ArtifactKind(rawValue: kindRawValue) ?? .text,
            title: title,
            summary: summary,
            textContent: textContent,
            payload: PersistenceCoding.decode(ArtifactPayload.self, from: payloadData),
            mediaRef: PersistenceCoding.decode(ArtifactMediaRef.self, from: mediaRefData),
            metadata: PersistenceCoding.decode([String: String].self, from: metadataData) ?? [:],
            binaryPayload: binaryPayload,
            previewPayload: previewPayload,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: Artifact) {
        id = domainModel.id
        recordID = domainModel.recordID
        kindRawValue = domainModel.kind.rawValue
        title = domainModel.title
        summary = domainModel.summary
        textContent = domainModel.textContent
        payloadData = PersistenceCoding.encode(domainModel.payload)
        mediaRefData = PersistenceCoding.encode(domainModel.mediaRef)
        metadataData = PersistenceCoding.encode(domainModel.metadata)
        binaryPayload = domainModel.binaryPayload
        previewPayload = domainModel.previewPayload
        createdAt = domainModel.createdAt
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

@MainActor
extension SelfProfileStore {
    convenience init(domainModel: SelfProfile) {
        self.init(
            id: domainModel.id,
            syncKey: domainModel.syncKey,
            schemaVersion: domainModel.schemaVersion,
            selfEntityID: domainModel.selfEntityID,
            displayName: domainModel.displayName,
            aliases: domainModel.aliases,
            pronouns: domainModel.pronouns,
            lifeRolesData: PersistenceCoding.encode(domainModel.lifeRoles),
            longTermGoalsData: PersistenceCoding.encode(domainModel.longTermGoals),
            preferencesData: PersistenceCoding.encode(domainModel.preferences),
            sensitiveBoundariesData: PersistenceCoding.encode(domainModel.sensitiveBoundaries),
            importantRelationshipIDs: domainModel.importantRelationshipIDs,
            commonPlaceIDs: domainModel.commonPlaceIDs,
            commonThemeIDs: domainModel.commonThemeIDs,
            expressionPatternsData: PersistenceCoding.encode(domainModel.expressionPatterns),
            privacyModeRawValue: domainModel.privacyMode.rawValue,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: SelfProfile {
        SelfProfile(
            id: id,
            syncKey: syncKey,
            schemaVersion: schemaVersion,
            selfEntityID: selfEntityID,
            displayName: displayName,
            aliases: aliases,
            pronouns: pronouns,
            lifeRoles: PersistenceCoding.decode([SelfRole].self, from: lifeRolesData) ?? [],
            longTermGoals: PersistenceCoding.decode([SelfGoal].self, from: longTermGoalsData) ?? [],
            preferences: PersistenceCoding.decode([SelfPreference].self, from: preferencesData) ?? [],
            sensitiveBoundaries: PersistenceCoding.decode([SensitiveBoundary].self, from: sensitiveBoundariesData) ?? [],
            importantRelationshipIDs: importantRelationshipIDs,
            commonPlaceIDs: commonPlaceIDs,
            commonThemeIDs: commonThemeIDs,
            expressionPatterns: PersistenceCoding.decode([ExpressionPattern].self, from: expressionPatternsData) ?? [],
            privacyMode: SelfProfilePrivacyMode(rawValue: privacyModeRawValue) ?? .localFirst,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: SelfProfile) {
        id = domainModel.id
        syncKey = domainModel.syncKey
        schemaVersion = domainModel.schemaVersion
        selfEntityID = domainModel.selfEntityID
        displayName = domainModel.displayName
        aliases = domainModel.aliases
        pronouns = domainModel.pronouns
        lifeRolesData = PersistenceCoding.encode(domainModel.lifeRoles)
        longTermGoalsData = PersistenceCoding.encode(domainModel.longTermGoals)
        preferencesData = PersistenceCoding.encode(domainModel.preferences)
        sensitiveBoundariesData = PersistenceCoding.encode(domainModel.sensitiveBoundaries)
        importantRelationshipIDs = domainModel.importantRelationshipIDs
        commonPlaceIDs = domainModel.commonPlaceIDs
        commonThemeIDs = domainModel.commonThemeIDs
        expressionPatternsData = PersistenceCoding.encode(domainModel.expressionPatterns)
        privacyModeRawValue = domainModel.privacyMode.rawValue
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension EntityProfileStore {
    convenience init(domainModel: EntityProfile) {
        self.init(
            id: domainModel.id,
            entityID: domainModel.entityID,
            kindRawValue: domainModel.kind.rawValue,
            displayName: domainModel.displayName,
            canonicalName: domainModel.canonicalName,
            aliases: domainModel.aliases,
            relationshipToUserRawValue: domainModel.relationshipToUser?.rawValue,
            userDescription: domainModel.userDescription,
            mentionCount: domainModel.mentionCount,
            firstMentionedAt: domainModel.firstMentionedAt,
            lastMentionedAt: domainModel.lastMentionedAt,
            commonContextLabels: domainModel.commonContextLabels,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            confirmationStateRawValue: domainModel.confirmationState.rawValue,
            confidence: domainModel.confidence,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: EntityProfile {
        EntityProfile(
            id: id,
            entityID: entityID,
            kind: EntityKind(rawValue: kindRawValue) ?? .object,
            displayName: displayName,
            canonicalName: canonicalName,
            aliases: aliases,
            relationshipToUser: relationshipToUserRawValue.flatMap(EntityRelationshipToUser.init(rawValue:)),
            userDescription: userDescription,
            mentionCount: mentionCount,
            firstMentionedAt: firstMentionedAt,
            lastMentionedAt: lastMentionedAt,
            commonContextLabels: commonContextLabels,
            sourceRecordIDs: sourceRecordIDs,
            confirmationState: IntelligenceConfirmationState(rawValue: confirmationStateRawValue) ?? .inferred,
            confidence: confidence,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: EntityProfile) {
        id = domainModel.id
        entityID = domainModel.entityID
        kindRawValue = domainModel.kind.rawValue
        displayName = domainModel.displayName
        canonicalName = domainModel.canonicalName
        aliases = domainModel.aliases
        relationshipToUserRawValue = domainModel.relationshipToUser?.rawValue
        userDescription = domainModel.userDescription
        mentionCount = domainModel.mentionCount
        firstMentionedAt = domainModel.firstMentionedAt
        lastMentionedAt = domainModel.lastMentionedAt
        commonContextLabels = domainModel.commonContextLabels
        sourceRecordIDs = domainModel.sourceRecordIDs
        confirmationStateRawValue = domainModel.confirmationState.rawValue
        confidence = domainModel.confidence
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension PlaceProfileStore {
    convenience init(domainModel: PlaceProfile) {
        self.init(
            id: domainModel.id,
            entityID: domainModel.entityID,
            displayName: domainModel.displayName,
            canonicalName: domainModel.canonicalName,
            aliases: domainModel.aliases,
            centroidLatitude: domainModel.centroidLatitude,
            centroidLongitude: domainModel.centroidLongitude,
            radiusMeters: domainModel.radiusMeters,
            mentionCount: domainModel.mentionCount,
            sourceArtifactIDs: domainModel.sourceArtifactIDs,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            confirmationStateRawValue: domainModel.confirmationState.rawValue,
            confidence: domainModel.confidence,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: PlaceProfile {
        PlaceProfile(
            id: id,
            entityID: entityID,
            displayName: displayName,
            canonicalName: canonicalName,
            aliases: aliases,
            centroidLatitude: centroidLatitude,
            centroidLongitude: centroidLongitude,
            radiusMeters: radiusMeters,
            mentionCount: mentionCount,
            sourceArtifactIDs: sourceArtifactIDs,
            sourceRecordIDs: sourceRecordIDs,
            confirmationState: IntelligenceConfirmationState(rawValue: confirmationStateRawValue) ?? .inferred,
            confidence: confidence,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: PlaceProfile) {
        id = domainModel.id
        entityID = domainModel.entityID
        displayName = domainModel.displayName
        canonicalName = domainModel.canonicalName
        aliases = domainModel.aliases
        centroidLatitude = domainModel.centroidLatitude
        centroidLongitude = domainModel.centroidLongitude
        radiusMeters = domainModel.radiusMeters
        mentionCount = domainModel.mentionCount
        sourceArtifactIDs = domainModel.sourceArtifactIDs
        sourceRecordIDs = domainModel.sourceRecordIDs
        confirmationStateRawValue = domainModel.confirmationState.rawValue
        confidence = domainModel.confidence
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension ClarificationQuestionStore {
    convenience init(domainModel: ClarificationQuestion) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            prompt: domainModel.prompt,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            sourceArtifactIDs: domainModel.sourceArtifactIDs,
            candidateAnswersData: PersistenceCoding.encode(domainModel.candidateAnswers),
            priority: domainModel.priority,
            reason: domainModel.reason,
            sensitivityRawValue: domainModel.sensitivity.rawValue,
            statusRawValue: domainModel.status.rawValue,
            answerData: PersistenceCoding.encode(domainModel.answer),
            createdAt: domainModel.createdAt,
            expiresAt: domainModel.expiresAt,
            answeredAt: domainModel.answeredAt,
            dismissedAt: domainModel.dismissedAt,
            askCount: domainModel.askCount
        )
    }

    var domainModel: ClarificationQuestion {
        ClarificationQuestion(
            id: id,
            kind: ClarificationQuestionKind(rawValue: kindRawValue) ?? .dailyReflection,
            prompt: prompt,
            targetType: ClarificationTargetType(rawValue: targetTypeRawValue) ?? .record,
            targetID: targetID,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            candidateAnswers: PersistenceCoding.decode([ClarificationAnswerOption].self, from: candidateAnswersData) ?? [],
            priority: priority,
            reason: reason,
            sensitivity: QuestionSensitivity(rawValue: sensitivityRawValue) ?? .normal,
            status: ClarificationQuestionStatus(rawValue: statusRawValue) ?? .pending,
            answer: PersistenceCoding.decode(ClarificationAnswer.self, from: answerData),
            createdAt: createdAt,
            expiresAt: expiresAt,
            answeredAt: answeredAt,
            dismissedAt: dismissedAt,
            askCount: askCount
        )
    }

    func apply(domainModel: ClarificationQuestion) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        prompt = domainModel.prompt
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        sourceRecordIDs = domainModel.sourceRecordIDs
        sourceArtifactIDs = domainModel.sourceArtifactIDs
        candidateAnswersData = PersistenceCoding.encode(domainModel.candidateAnswers)
        priority = domainModel.priority
        reason = domainModel.reason
        sensitivityRawValue = domainModel.sensitivity.rawValue
        statusRawValue = domainModel.status.rawValue
        answerData = PersistenceCoding.encode(domainModel.answer)
        createdAt = domainModel.createdAt
        expiresAt = domainModel.expiresAt
        answeredAt = domainModel.answeredAt
        dismissedAt = domainModel.dismissedAt
        askCount = domainModel.askCount
    }
}

@MainActor
extension IntelligenceJobStore {
    convenience init(domainModel: IntelligenceJob) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            statusRawValue: domainModel.status.rawValue,
            priority: domainModel.priority,
            attemptCount: domainModel.attemptCount,
            lastError: domainModel.lastError,
            scheduledAt: domainModel.scheduledAt,
            startedAt: domainModel.startedAt,
            completedAt: domainModel.completedAt,
            updatedAt: domainModel.updatedAt,
            dedupeKey: domainModel.dedupeKey,
            requiresCloudAI: domainModel.requiresCloudAI
        )
    }

    var domainModel: IntelligenceJob {
        IntelligenceJob(
            id: id,
            kind: IntelligenceJobKind(rawValue: kindRawValue) ?? .postAnalysis,
            targetType: IntelligenceTargetType(rawValue: targetTypeRawValue) ?? .record,
            targetID: targetID,
            status: IntelligenceJobStatus(rawValue: statusRawValue) ?? .pending,
            priority: priority,
            attemptCount: attemptCount,
            lastError: lastError,
            scheduledAt: scheduledAt,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
            dedupeKey: dedupeKey,
            requiresCloudAI: requiresCloudAI
        )
    }

    func apply(domainModel: IntelligenceJob) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        statusRawValue = domainModel.status.rawValue
        priority = domainModel.priority
        attemptCount = domainModel.attemptCount
        lastError = domainModel.lastError
        scheduledAt = domainModel.scheduledAt
        startedAt = domainModel.startedAt
        completedAt = domainModel.completedAt
        updatedAt = domainModel.updatedAt
        dedupeKey = domainModel.dedupeKey
        requiresCloudAI = domainModel.requiresCloudAI
    }
}

@MainActor
extension GraphDeltaStore {
    convenience init(domainModel: GraphDelta) {
        self.init(
            id: domainModel.id,
            sourceRawValue: domainModel.source.rawValue,
            operationsData: PersistenceCoding.encode(domainModel.operations),
            confidence: domainModel.confidence,
            requiresUserConfirmation: domainModel.requiresUserConfirmation,
            appliedAt: domainModel.appliedAt,
            createdAt: domainModel.createdAt
        )
    }

    var domainModel: GraphDelta {
        GraphDelta(
            id: id,
            source: GraphDeltaSource(rawValue: sourceRawValue) ?? .localRule,
            operations: PersistenceCoding.decode([GraphDeltaOperation].self, from: operationsData) ?? [],
            confidence: confidence,
            requiresUserConfirmation: requiresUserConfirmation,
            appliedAt: appliedAt,
            createdAt: createdAt
        )
    }

    func apply(domainModel: GraphDelta) {
        id = domainModel.id
        sourceRawValue = domainModel.source.rawValue
        operationsData = PersistenceCoding.encode(domainModel.operations)
        confidence = domainModel.confidence
        requiresUserConfirmation = domainModel.requiresUserConfirmation
        appliedAt = domainModel.appliedAt
        createdAt = domainModel.createdAt
    }
}

@MainActor
extension HomeBoardSignalStore {
    convenience init(domainModel: HomeBoardSignal) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            title: domainModel.title,
            subtitle: domainModel.subtitle,
            priority: domainModel.priority,
            reason: domainModel.reason,
            suggestedWidthColumns: domainModel.suggestedWidthColumns,
            suggestedHeightUnits: domainModel.suggestedHeightUnits,
            createdAt: domainModel.createdAt,
            expiresAt: domainModel.expiresAt
        )
    }

    var domainModel: HomeBoardSignal {
        HomeBoardSignal(
            id: id,
            kind: HomeBoardSignalKind(rawValue: kindRawValue) ?? .clarificationQuestion,
            targetType: ClarificationTargetType(rawValue: targetTypeRawValue) ?? .record,
            targetID: targetID,
            sourceRecordIDs: sourceRecordIDs,
            title: title,
            subtitle: subtitle,
            priority: priority,
            reason: reason,
            suggestedWidthColumns: suggestedWidthColumns,
            suggestedHeightUnits: suggestedHeightUnits,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }

    func apply(domainModel: HomeBoardSignal) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        sourceRecordIDs = domainModel.sourceRecordIDs
        title = domainModel.title
        subtitle = domainModel.subtitle
        priority = domainModel.priority
        reason = domainModel.reason
        suggestedWidthColumns = domainModel.suggestedWidthColumns
        suggestedHeightUnits = domainModel.suggestedHeightUnits
        createdAt = domainModel.createdAt
        expiresAt = domainModel.expiresAt
    }
}

@MainActor
extension NotificationIntentStore {
    convenience init(domainModel: NotificationIntent) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            title: domainModel.title,
            body: domainModel.body,
            privacyLevelRawValue: domainModel.privacyLevel.rawValue,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            scheduledAt: domainModel.scheduledAt,
            statusRawValue: domainModel.status.rawValue,
            deliveryChannelRawValue: domainModel.deliveryChannel.rawValue,
            createdAt: domainModel.createdAt,
            deliveredAt: domainModel.deliveredAt,
            dismissedAt: domainModel.dismissedAt
        )
    }

    var domainModel: NotificationIntent {
        NotificationIntent(
            id: id,
            kind: NotificationIntentKind(rawValue: kindRawValue) ?? .dailyQuestion,
            title: title,
            body: body,
            privacyLevel: NotificationPrivacyLevel(rawValue: privacyLevelRawValue) ?? .generic,
            targetType: ClarificationTargetType(rawValue: targetTypeRawValue) ?? .record,
            targetID: targetID,
            scheduledAt: scheduledAt,
            status: NotificationIntentStatus(rawValue: statusRawValue) ?? .pending,
            deliveryChannel: NotificationDeliveryChannel(rawValue: deliveryChannelRawValue) ?? .local,
            createdAt: createdAt,
            deliveredAt: deliveredAt,
            dismissedAt: dismissedAt
        )
    }

    func apply(domainModel: NotificationIntent) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        title = domainModel.title
        body = domainModel.body
        privacyLevelRawValue = domainModel.privacyLevel.rawValue
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        scheduledAt = domainModel.scheduledAt
        statusRawValue = domainModel.status.rawValue
        deliveryChannelRawValue = domainModel.deliveryChannel.rawValue
        createdAt = domainModel.createdAt
        deliveredAt = domainModel.deliveredAt
        dismissedAt = domainModel.dismissedAt
    }
}

@MainActor
extension BoardStore {
    convenience init(domainModel: Board) {
        self.init(
            id: domainModel.id,
            boardKey: domainModel.boardKey,
            kindRawValue: domainModel.kind.rawValue,
            title: domainModel.title,
            subtitle: domainModel.subtitle,
            boardDate: domainModel.boardDate,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: Board {
        Board(
            id: id,
            boardKey: boardKey,
            kind: BoardKind(rawValue: kindRawValue) ?? .homeDay,
            title: title,
            subtitle: subtitle,
            boardDate: boardDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: Board) {
        id = domainModel.id
        boardKey = domainModel.boardKey
        kindRawValue = domainModel.kind.rawValue
        title = domainModel.title
        subtitle = domainModel.subtitle
        boardDate = domainModel.boardDate
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension CompositionStore {
    convenience init(domainModel: Composition) {
        self.init(
            id: domainModel.id,
            boardID: domainModel.boardID,
            compositionKey: domainModel.compositionKey,
            title: domainModel.title,
            sortOrder: domainModel.sortOrder,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: Composition {
        Composition(
            id: id,
            boardID: boardID,
            compositionKey: compositionKey,
            title: title,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: Composition) {
        id = domainModel.id
        boardID = domainModel.boardID
        compositionKey = domainModel.compositionKey
        title = domainModel.title
        sortOrder = domainModel.sortOrder
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension CompositionItemStore {
    convenience init(domainModel: CompositionItem) {
        self.init(
            id: domainModel.id,
            boardID: domainModel.boardID,
            boardKey: domainModel.boardKey,
            compositionID: domainModel.compositionID,
            compositionKey: domainModel.compositionKey,
            itemKey: domainModel.itemKey,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            widthColumns: domainModel.widthColumns,
            heightUnits: domainModel.heightUnits,
            zIndex: domainModel.zIndex,
            rotationDegrees: domainModel.rotationDegrees,
            scale: domainModel.scale,
            isHidden: domainModel.isHidden,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: CompositionItem {
        CompositionItem(
            id: id,
            boardID: boardID,
            boardKey: boardKey,
            compositionID: compositionID,
            compositionKey: compositionKey,
            itemKey: itemKey,
            targetType: CompositionTargetType(rawValue: targetTypeRawValue) ?? .artifact,
            targetID: targetID,
            widthColumns: widthColumns,
            heightUnits: heightUnits,
            zIndex: zIndex,
            rotationDegrees: rotationDegrees,
            scale: scale,
            isHidden: isHidden,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: CompositionItem) {
        id = domainModel.id
        boardID = domainModel.boardID
        boardKey = domainModel.boardKey
        compositionID = domainModel.compositionID
        compositionKey = domainModel.compositionKey
        itemKey = domainModel.itemKey
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        widthColumns = domainModel.widthColumns
        heightUnits = domainModel.heightUnits
        zIndex = domainModel.zIndex
        rotationDegrees = domainModel.rotationDegrees
        scale = domainModel.scale
        isHidden = domainModel.isHidden
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension EntityNodeStore {
    convenience init(domainModel: EntityNode) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            displayName: domainModel.displayName,
            canonicalName: domainModel.canonicalName,
            aliases: domainModel.aliases,
            summary: domainModel.summary,
            provenanceRecordIDs: domainModel.provenanceRecordIDs,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt,
            confidence: domainModel.confidence
        )
    }

    var domainModel: EntityNode {
        EntityNode(
            id: id,
            kind: EntityKind(rawValue: kindRawValue) ?? .object,
            displayName: displayName,
            canonicalName: canonicalName,
            aliases: aliases,
            summary: summary,
            provenanceRecordIDs: provenanceRecordIDs,
            createdAt: createdAt,
            updatedAt: updatedAt,
            confidence: confidence
        )
    }

    func apply(domainModel: EntityNode) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        displayName = domainModel.displayName
        canonicalName = domainModel.canonicalName
        aliases = domainModel.aliases
        summary = domainModel.summary
        provenanceRecordIDs = domainModel.provenanceRecordIDs
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
        confidence = domainModel.confidence
    }
}

@MainActor
extension EntityEdgeStore {
    convenience init(domainModel: EntityEdge) {
        self.init(
            id: domainModel.id,
            fromEntityID: domainModel.fromEntityID,
            toEntityID: domainModel.toEntityID,
            relationKindRawValue: domainModel.relationKind.rawValue,
            weight: domainModel.weight,
            firstSeenAt: domainModel.firstSeenAt,
            lastSeenAt: domainModel.lastSeenAt,
            evidenceCount: domainModel.evidenceCount,
            sourceArtifactIDs: domainModel.sourceArtifactIDs,
            sourceRecordIDs: domainModel.sourceRecordIDs
        )
    }

    var domainModel: EntityEdge {
        EntityEdge(
            id: id,
            fromEntityID: fromEntityID,
            toEntityID: toEntityID,
            relationKind: EntityRelationKind(rawValue: relationKindRawValue) ?? .relatedTo,
            weight: weight,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt,
            evidenceCount: evidenceCount,
            sourceArtifactIDs: sourceArtifactIDs,
            sourceRecordIDs: sourceRecordIDs
        )
    }

    func apply(domainModel: EntityEdge) {
        id = domainModel.id
        fromEntityID = domainModel.fromEntityID
        toEntityID = domainModel.toEntityID
        relationKindRawValue = domainModel.relationKind.rawValue
        weight = domainModel.weight
        firstSeenAt = domainModel.firstSeenAt
        lastSeenAt = domainModel.lastSeenAt
        evidenceCount = domainModel.evidenceCount
        sourceArtifactIDs = domainModel.sourceArtifactIDs
        sourceRecordIDs = domainModel.sourceRecordIDs
    }
}

@MainActor
extension ArtifactEntityLinkStore {
    convenience init(domainModel: ArtifactEntityLink) {
        self.init(
            id: domainModel.id,
            artifactID: domainModel.artifactID,
            entityID: domainModel.entityID,
            confidence: domainModel.confidence,
            source: domainModel.source,
            sourceRecordID: domainModel.sourceRecordID,
            sourceAnalysisRecordID: domainModel.sourceAnalysisRecordID,
            evidenceSummary: domainModel.evidenceSummary,
            createdAt: domainModel.createdAt
        )
    }

    var domainModel: ArtifactEntityLink {
        ArtifactEntityLink(
            id: id,
            artifactID: artifactID,
            entityID: entityID,
            confidence: confidence,
            source: source,
            sourceRecordID: sourceRecordID,
            sourceAnalysisRecordID: sourceAnalysisRecordID,
            evidenceSummary: evidenceSummary,
            createdAt: createdAt
        )
    }

    func apply(domainModel: ArtifactEntityLink) {
        id = domainModel.id
        artifactID = domainModel.artifactID
        entityID = domainModel.entityID
        confidence = domainModel.confidence
        source = domainModel.source
        sourceRecordID = domainModel.sourceRecordID
        sourceAnalysisRecordID = domainModel.sourceAnalysisRecordID
        evidenceSummary = domainModel.evidenceSummary
        createdAt = domainModel.createdAt
    }
}

@MainActor
extension RecordAnalysisSnapshotStore {
    convenience init(domainModel: RecordAnalysisSnapshot) {
        self.init(
            id: domainModel.id,
            recordID: domainModel.recordID,
            summary: domainModel.summary,
            themes: domainModel.themes,
            emotionInterpretation: domainModel.emotionInterpretation,
            salienceScore: domainModel.salienceScore ?? 0,
            retrievalTerms: domainModel.retrievalTerms,
            entityMentionsData: PersistenceCoding.encode(domainModel.entityMentions),
            candidateEdgesData: PersistenceCoding.encode(domainModel.candidateEdges),
            followUpCandidatesData: PersistenceCoding.encode(domainModel.followUpCandidates),
            reflectionHint: domainModel.reflectionHint,
            createdAt: domainModel.createdAt
        )
    }

    var domainModel: RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            id: id,
            recordID: recordID,
            summary: summary,
            themes: themes,
            emotionInterpretation: emotionInterpretation,
            salienceScore: salienceScore,
            retrievalTerms: retrievalTerms,
            entityMentions: PersistenceCoding.decode([EntityReference].self, from: entityMentionsData) ?? [],
            candidateEdges: PersistenceCoding.decode([CandidateEntityEdge].self, from: candidateEdgesData) ?? [],
            followUpCandidates: PersistenceCoding.decode([FollowUpCandidate].self, from: followUpCandidatesData) ?? [],
            reflectionHint: reflectionHint,
            createdAt: createdAt
        )
    }

    func apply(domainModel: RecordAnalysisSnapshot) {
        id = domainModel.id
        recordID = domainModel.recordID
        summary = domainModel.summary
        themes = domainModel.themes
        emotionInterpretation = domainModel.emotionInterpretation
        salienceScore = domainModel.salienceScore ?? 0
        retrievalTerms = domainModel.retrievalTerms
        entityMentionsData = PersistenceCoding.encode(domainModel.entityMentions)
        candidateEdgesData = PersistenceCoding.encode(domainModel.candidateEdges)
        followUpCandidatesData = PersistenceCoding.encode(domainModel.followUpCandidates)
        reflectionHint = domainModel.reflectionHint
        createdAt = domainModel.createdAt
    }
}

@MainActor
extension MemoryPipelineStatusStore {
    convenience init(domainModel: MemoryPipelineStatusSnapshot) {
        self.init(
            recordID: domainModel.recordID,
            stageRawValue: domainModel.stage.rawValue,
            requestID: domainModel.requestID,
            lastError: domainModel.lastError,
            requestBody: domainModel.requestBody,
            responseBody: domainModel.responseBody,
            rawErrorBody: domainModel.rawErrorBody,
            lastHTTPStatusCode: domainModel.lastHTTPStatusCode,
            failedStage: domainModel.failedStage,
            lastAttemptAt: domainModel.lastAttemptAt,
            completedAt: domainModel.completedAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: MemoryPipelineStatusSnapshot {
        MemoryPipelineStatusSnapshot(
            recordID: recordID,
            stage: MemoryPipelineStage(rawValue: stageRawValue) ?? .pending,
            requestID: requestID,
            lastError: lastError,
            requestBody: requestBody,
            responseBody: responseBody,
            rawErrorBody: rawErrorBody,
            lastHTTPStatusCode: lastHTTPStatusCode,
            failedStage: failedStage,
            lastAttemptAt: lastAttemptAt,
            completedAt: completedAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: MemoryPipelineStatusSnapshot) {
        recordID = domainModel.recordID
        stageRawValue = domainModel.stage.rawValue
        requestID = domainModel.requestID
        lastError = domainModel.lastError
        requestBody = domainModel.requestBody
        responseBody = domainModel.responseBody
        rawErrorBody = domainModel.rawErrorBody
        lastHTTPStatusCode = domainModel.lastHTTPStatusCode
        failedStage = domainModel.failedStage
        lastAttemptAt = domainModel.lastAttemptAt
        completedAt = domainModel.completedAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension ReflectionSnapshotStore {
    convenience init(domainModel: ReflectionSnapshot) {
        self.init(
            id: domainModel.id,
            typeRawValue: domainModel.type.rawValue,
            title: domainModel.title,
            body: domainModel.body,
            evidenceSummary: domainModel.evidenceSummary,
            confidence: domainModel.confidence,
            statusRawValue: domainModel.status.rawValue,
            linkedTemporalArcID: domainModel.linkedTemporalArcID,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            sourceArtifactIDs: domainModel.sourceArtifactIDs,
            sourceEntityIDs: domainModel.sourceEntityIDs,
            createdAt: domainModel.createdAt,
            savedAt: domainModel.savedAt,
            dismissedAt: domainModel.dismissedAt
        )
    }

    var domainModel: ReflectionSnapshot {
        ReflectionSnapshot(
            id: id,
            type: ReflectionType(rawValue: typeRawValue) ?? .record,
            title: title,
            body: body,
            evidenceSummary: evidenceSummary,
            confidence: confidence,
            status: ReflectionStatus(rawValue: statusRawValue) ?? .suggested,
            linkedTemporalArcID: linkedTemporalArcID,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            sourceEntityIDs: sourceEntityIDs,
            createdAt: createdAt,
            savedAt: savedAt,
            dismissedAt: dismissedAt
        )
    }

    func apply(domainModel: ReflectionSnapshot) {
        id = domainModel.id
        typeRawValue = domainModel.type.rawValue
        title = domainModel.title
        body = domainModel.body
        evidenceSummary = domainModel.evidenceSummary
        confidence = domainModel.confidence
        statusRawValue = domainModel.status.rawValue
        linkedTemporalArcID = domainModel.linkedTemporalArcID
        sourceRecordIDs = domainModel.sourceRecordIDs
        sourceArtifactIDs = domainModel.sourceArtifactIDs
        sourceEntityIDs = domainModel.sourceEntityIDs
        createdAt = domainModel.createdAt
        savedAt = domainModel.savedAt
        dismissedAt = domainModel.dismissedAt
    }
}

@MainActor
extension TemporalArcStore {
    convenience init(domainModel: TemporalArc) {
        self.init(
            id: domainModel.id,
            title: domainModel.title,
            summary: domainModel.summary,
            statusRawValue: domainModel.status.rawValue,
            dominantTheme: domainModel.dominantTheme,
            dominantEntityName: domainModel.dominantEntityName,
            themeLabels: domainModel.themeLabels,
            entityNames: domainModel.entityNames,
            linkedReflectionID: domainModel.linkedReflectionID,
            mergedFromArcIDs: domainModel.mergedFromArcIDs,
            mergedIntoArcID: domainModel.mergedIntoArcID,
            lastMergedAt: domainModel.lastMergedAt,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            sourceArtifactIDs: domainModel.sourceArtifactIDs,
            sourceEntityIDs: domainModel.sourceEntityIDs,
            startDate: domainModel.startDate,
            endDate: domainModel.endDate,
            intensityScore: domainModel.intensityScore,
            clusterStrength: domainModel.clusterStrength,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: TemporalArc {
        TemporalArc(
            id: id,
            title: title,
            summary: summary,
            status: TemporalArcStatus(rawValue: statusRawValue) ?? .candidate,
            dominantTheme: dominantTheme,
            dominantEntityName: dominantEntityName,
            themeLabels: themeLabels,
            entityNames: entityNames,
            linkedReflectionID: linkedReflectionID,
            mergedFromArcIDs: mergedFromArcIDs,
            mergedIntoArcID: mergedIntoArcID,
            lastMergedAt: lastMergedAt,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            sourceEntityIDs: sourceEntityIDs,
            startDate: startDate,
            endDate: endDate,
            intensityScore: intensityScore,
            clusterStrength: clusterStrength,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: TemporalArc) {
        id = domainModel.id
        title = domainModel.title
        summary = domainModel.summary
        statusRawValue = domainModel.status.rawValue
        dominantTheme = domainModel.dominantTheme
        dominantEntityName = domainModel.dominantEntityName
        themeLabels = domainModel.themeLabels
        entityNames = domainModel.entityNames
        linkedReflectionID = domainModel.linkedReflectionID
        mergedFromArcIDs = domainModel.mergedFromArcIDs
        mergedIntoArcID = domainModel.mergedIntoArcID
        lastMergedAt = domainModel.lastMergedAt
        sourceRecordIDs = domainModel.sourceRecordIDs
        sourceArtifactIDs = domainModel.sourceArtifactIDs
        sourceEntityIDs = domainModel.sourceEntityIDs
        startDate = domainModel.startDate
        endDate = domainModel.endDate
        intensityScore = domainModel.intensityScore
        clusterStrength = domainModel.clusterStrength
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}
