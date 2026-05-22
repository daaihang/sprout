import Foundation

struct GraphDeltaApplicationResult: Sendable {
    let profile: EntityProfile?
    let entityNode: EntityNode?
}

struct GraphDeltaApplier: Sendable {
    func buildDelta(
        for question: ClarificationQuestion,
        answer: ClarificationAnswer
    ) -> GraphDelta? {
        switch question.kind {
        case .entityRelationship:
            return GraphDelta(
                source: .userAnswer,
                operations: [
                    GraphDeltaOperation(
                        kind: .setRelationship,
                        targetType: .entity,
                        targetID: question.targetID,
                        stringValue: answer.value,
                        metadata: ["questionID": question.id.uuidString]
                    )
                ],
                confidence: 1,
                requiresUserConfirmation: false
            )
        case .entityAlias:
            let alias = answer.freeformText?.trimmedOrNil ?? answer.value.trimmedOrNil
            guard let alias, alias != "no_alias" else { return nil }
            return GraphDelta(
                source: .userAnswer,
                operations: [
                    GraphDeltaOperation(
                        kind: .addAlias,
                        targetType: .entity,
                        targetID: question.targetID,
                        stringValue: alias,
                        metadata: ["questionID": question.id.uuidString]
                    )
                ],
                confidence: 1,
                requiresUserConfirmation: false
            )
        case .entityMerge:
            guard let relatedID = resolvedUUID(from: answer) else { return nil }
            return GraphDelta(
                source: .userAnswer,
                operations: [
                    GraphDeltaOperation(
                        kind: .mergeEntity,
                        targetType: .entity,
                        targetID: question.targetID,
                        relatedID: relatedID,
                        metadata: ["questionID": question.id.uuidString]
                    )
                ],
                confidence: 1,
                requiresUserConfirmation: false
            )
        default:
            return nil
        }
    }

    func apply(
        delta: GraphDelta,
        profile: EntityProfile?,
        entityNode: EntityNode?,
        appliedAt: Date = .now
    ) -> GraphDeltaApplicationResult {
        var updatedProfile = profile
        var updatedEntity = entityNode

        for operation in delta.operations {
            switch operation.kind {
            case .setRelationship:
                if var profileValue = updatedProfile {
                    profileValue.relationshipToUser = operation.stringValue.flatMap(EntityRelationshipToUser.init(rawValue:))
                    profileValue.confirmationState = .userConfirmed
                    profileValue.confidence = 1
                    profileValue.updatedAt = appliedAt
                    self.normalizeMentionWindow(for: &profileValue)
                    updatedProfile = profileValue
                }
            case .addAlias:
                guard let alias = operation.stringValue?.trimmedOrNil else { continue }
                if var profileValue = updatedProfile {
                    if !profileValue.aliases.contains(alias) {
                        profileValue.aliases.append(alias)
                    }
                    profileValue.confirmationState = .userConfirmed
                    profileValue.updatedAt = appliedAt
                    self.normalizeMentionWindow(for: &profileValue)
                    updatedProfile = profileValue
                }
                if var entityValue = updatedEntity {
                    if !entityValue.aliases.contains(alias) {
                        entityValue.aliases.append(alias)
                    }
                    entityValue.updatedAt = appliedAt
                    updatedEntity = entityValue
                }
            case .mergeEntity:
                // Repository-level mutation handles merge transactions and reference rewrites.
                continue
            default:
                continue
            }
        }

        return GraphDeltaApplicationResult(profile: updatedProfile, entityNode: updatedEntity)
    }

    private func normalizeMentionWindow(for profile: inout EntityProfile) {
        if profile.firstMentionedAt == nil {
            profile.firstMentionedAt = profile.updatedAt
        }
        if profile.lastMentionedAt == nil {
            profile.lastMentionedAt = profile.updatedAt
        }
    }

    private func resolvedUUID(from answer: ClarificationAnswer) -> UUID? {
        if let id = UUID(uuidString: answer.value) {
            return id
        }
        if let text = answer.freeformText?.trimmedOrNil, let id = UUID(uuidString: text) {
            return id
        }
        return nil
    }
}
