import Foundation

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
extension PersonProfileStore {
    convenience init(domainModel: PersonProfile) {
        self.init(
            id: domainModel.id,
            entityID: domainModel.entityID,
            displayName: domainModel.displayName,
            canonicalName: domainModel.canonicalName,
            aliases: domainModel.aliases,
            roleLabels: domainModel.roleLabels,
            relationshipToUserRawValue: domainModel.relationshipToUser?.rawValue,
            relationshipHistoryData: PersistenceCoding.encode(domainModel.relationshipHistory),
            relationshipStrength: domainModel.relationshipStrength,
            importanceScore: domainModel.importanceScore,
            interactionFrequencyRawValue: domainModel.interactionFrequency.rawValue,
            commonPlaceIDs: domainModel.commonPlaceIDs,
            commonThemeIDs: domainModel.commonThemeIDs,
            commonDecisionIDs: domainModel.commonDecisionIDs,
            commonContextLabels: domainModel.commonContextLabels,
            emotionalPatternData: PersistenceCoding.encode(domainModel.emotionalPattern),
            recentChangeSummary: domainModel.recentChangeSummary,
            userNotes: domainModel.userNotes,
            aiPortraitData: PersistenceCoding.encode(domainModel.aiPortrait),
            fieldEvidenceData: PersistenceCoding.encode(domainModel.fieldEvidence),
            fieldConfidenceData: PersistenceCoding.encode(domainModel.fieldConfidence),
            sensitivityRawValue: domainModel.sensitivity.rawValue,
            automationPolicyRawValue: domainModel.automationPolicy.rawValue,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            lastReviewedAt: domainModel.lastReviewedAt,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: PersonProfile {
        PersonProfile(
            id: id,
            entityID: entityID,
            displayName: displayName,
            canonicalName: canonicalName,
            aliases: aliases,
            roleLabels: roleLabels,
            relationshipToUser: relationshipToUserRawValue.flatMap(EntityRelationshipToUser.init(rawValue:)),
            relationshipHistory: PersistenceCoding.decode([RelationshipChange].self, from: relationshipHistoryData) ?? [],
            relationshipStrength: relationshipStrength,
            importanceScore: importanceScore,
            interactionFrequency: InteractionFrequency(rawValue: interactionFrequencyRawValue) ?? .unknown,
            commonPlaceIDs: commonPlaceIDs,
            commonThemeIDs: commonThemeIDs,
            commonDecisionIDs: commonDecisionIDs,
            commonContextLabels: commonContextLabels,
            emotionalPattern: PersistenceCoding.decode(PersonAffectPattern.self, from: emotionalPatternData),
            recentChangeSummary: recentChangeSummary,
            userNotes: userNotes,
            aiPortrait: PersistenceCoding.decode(PersonPortrait.self, from: aiPortraitData),
            fieldEvidence: PersistenceCoding.decode([ProfileFieldEvidence].self, from: fieldEvidenceData) ?? [],
            fieldConfidence: PersistenceCoding.decode([String: Double].self, from: fieldConfidenceData) ?? [:],
            sensitivity: ProfileSensitivity(rawValue: sensitivityRawValue) ?? .normal,
            automationPolicy: PersonProfileAutomationPolicy(rawValue: automationPolicyRawValue) ?? .automatic,
            sourceRecordIDs: sourceRecordIDs,
            lastReviewedAt: lastReviewedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: PersonProfile) {
        id = domainModel.id
        entityID = domainModel.entityID
        displayName = domainModel.displayName
        canonicalName = domainModel.canonicalName
        aliases = domainModel.aliases
        roleLabels = domainModel.roleLabels
        relationshipToUserRawValue = domainModel.relationshipToUser?.rawValue
        relationshipHistoryData = PersistenceCoding.encode(domainModel.relationshipHistory)
        relationshipStrength = domainModel.relationshipStrength
        importanceScore = domainModel.importanceScore
        interactionFrequencyRawValue = domainModel.interactionFrequency.rawValue
        commonPlaceIDs = domainModel.commonPlaceIDs
        commonThemeIDs = domainModel.commonThemeIDs
        commonDecisionIDs = domainModel.commonDecisionIDs
        commonContextLabels = domainModel.commonContextLabels
        emotionalPatternData = PersistenceCoding.encode(domainModel.emotionalPattern)
        recentChangeSummary = domainModel.recentChangeSummary
        userNotes = domainModel.userNotes
        aiPortraitData = PersistenceCoding.encode(domainModel.aiPortrait)
        fieldEvidenceData = PersistenceCoding.encode(domainModel.fieldEvidence)
        fieldConfidenceData = PersistenceCoding.encode(domainModel.fieldConfidence)
        sensitivityRawValue = domainModel.sensitivity.rawValue
        automationPolicyRawValue = domainModel.automationPolicy.rawValue
        sourceRecordIDs = domainModel.sourceRecordIDs
        lastReviewedAt = domainModel.lastReviewedAt
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension AffectSnapshotStore {
    convenience init(domainModel: AffectSnapshot) {
        self.init(
            id: domainModel.id,
            recordID: domainModel.recordID,
            valence: domainModel.valence,
            arousal: domainModel.arousal,
            dominance: domainModel.dominance,
            intensity: domainModel.intensity,
            labelRawValues: domainModel.labels.map(\.rawValue),
            toneHintRawValues: domainModel.toneHints.map(\.rawValue),
            appraisalData: PersistenceCoding.encode(domainModel.appraisal),
            sourceRawValues: domainModel.sources.map(\.rawValue),
            confidence: domainModel.confidence,
            evidenceData: PersistenceCoding.encode(domainModel.evidence),
            userConfirmed: domainModel.userConfirmed,
            needsUserCheck: domainModel.needsUserCheck,
            rawInput: domainModel.rawInput,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: AffectSnapshot {
        AffectSnapshot(
            id: id,
            recordID: recordID,
            valence: valence,
            arousal: arousal,
            dominance: dominance,
            intensity: intensity,
            labels: labelRawValues.compactMap(AffectLabel.init(rawValue:)),
            toneHints: toneHintRawValues.compactMap(ToneHint.init(rawValue:)),
            appraisal: PersistenceCoding.decode(AffectAppraisal.self, from: appraisalData),
            sources: sourceRawValues.compactMap(AffectEvidenceSource.init(rawValue:)),
            confidence: confidence,
            evidence: PersistenceCoding.decode([AffectEvidence].self, from: evidenceData) ?? [],
            userConfirmed: userConfirmed,
            needsUserCheck: needsUserCheck,
            rawInput: rawInput,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: AffectSnapshot) {
        id = domainModel.id
        recordID = domainModel.recordID
        valence = domainModel.valence
        arousal = domainModel.arousal
        dominance = domainModel.dominance
        intensity = domainModel.intensity
        labelRawValues = domainModel.labels.map(\.rawValue)
        toneHintRawValues = domainModel.toneHints.map(\.rawValue)
        appraisalData = PersistenceCoding.encode(domainModel.appraisal)
        sourceRawValues = domainModel.sources.map(\.rawValue)
        confidence = domainModel.confidence
        evidenceData = PersistenceCoding.encode(domainModel.evidence)
        userConfirmed = domainModel.userConfirmed
        needsUserCheck = domainModel.needsUserCheck
        rawInput = domainModel.rawInput
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
