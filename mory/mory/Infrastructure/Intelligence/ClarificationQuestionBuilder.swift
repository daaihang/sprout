import Foundation

struct ClarificationQuestionBuilder: Sendable {
    func buildQuestion(
        for profile: EntityProfile,
        record: RecordShell,
        artifactIDs: [UUID],
        existingQuestions: [ClarificationQuestion],
        latestSummary: String?
    ) -> ClarificationQuestion? {
        let entityQuestions = existingQuestions.filter { $0.targetID == profile.entityID }

        if profile.kind == .person,
           profile.relationshipToUser == nil,
           shouldAsk(kind: .entityRelationship, for: profile, existingQuestions: entityQuestions) {
            return ClarificationQuestion(
                kind: .entityRelationship,
                prompt: "Who is \(profile.displayName) to you?",
                targetType: .entity,
                targetID: profile.entityID,
                sourceRecordIDs: [record.id],
                sourceArtifactIDs: artifactIDs,
                candidateAnswers: relationshipAnswerOptions,
                priority: relationshipPriority(for: profile),
                reason: latestSummary?.trimmedOrNil ?? "\(profile.displayName) is showing up in your recent memories.",
                sensitivity: .personal
            )
        }

        if profile.kind == .person,
           profile.relationshipToUser != nil,
           profile.aliases.isEmpty,
           shouldAskAlias(for: profile),
           shouldAsk(kind: .entityAlias, for: profile, existingQuestions: entityQuestions) {
            return ClarificationQuestion(
                kind: .entityAlias,
                prompt: "Do you call \(profile.displayName) by another name or nickname?",
                targetType: .entity,
                targetID: profile.entityID,
                sourceRecordIDs: [record.id],
                sourceArtifactIDs: artifactIDs,
                candidateAnswers: [ClarificationAnswerOption(label: "No other name", value: "no_alias")],
                priority: min(0.52 + Double(profile.mentionCount) * 0.08, 0.82),
                reason: latestSummary?.trimmedOrNil ?? "A shorter name would help future recall.",
                sensitivity: .personal
            )
        }

        return nil
    }

    private var relationshipAnswerOptions: [ClarificationAnswerOption] {
        [
            ClarificationAnswerOption(label: "Friend", value: EntityRelationshipToUser.friend.rawValue),
            ClarificationAnswerOption(label: "Family", value: EntityRelationshipToUser.family.rawValue),
            ClarificationAnswerOption(label: "Partner", value: EntityRelationshipToUser.partner.rawValue),
            ClarificationAnswerOption(label: "Coworker", value: EntityRelationshipToUser.coworker.rawValue),
            ClarificationAnswerOption(label: "Manager", value: EntityRelationshipToUser.manager.rawValue),
            ClarificationAnswerOption(label: "Direct report", value: EntityRelationshipToUser.directReport.rawValue),
            ClarificationAnswerOption(label: "Classmate", value: EntityRelationshipToUser.classmate.rawValue),
            ClarificationAnswerOption(label: "Client", value: EntityRelationshipToUser.client.rawValue),
            ClarificationAnswerOption(label: "Other", value: EntityRelationshipToUser.other.rawValue),
        ]
    }

    private func shouldAsk(
        kind: ClarificationQuestionKind,
        for profile: EntityProfile,
        existingQuestions: [ClarificationQuestion]
    ) -> Bool {
        !existingQuestions.contains { question in
            question.kind == kind && question.status != .dismissed && question.status != .expired && question.status != .stale
        }
    }

    private func shouldAskAlias(for profile: EntityProfile) -> Bool {
        let parts = profile.displayName.split(separator: " ")
        return parts.count >= 2 || profile.displayName != profile.canonicalName
    }

    private func relationshipPriority(for profile: EntityProfile) -> Double {
        let confidence = profile.confidence ?? 0.5
        return min(0.6 + Double(profile.mentionCount) * 0.08 + confidence * 0.1, 0.94)
    }
}
