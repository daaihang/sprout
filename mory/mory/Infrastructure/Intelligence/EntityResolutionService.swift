import Foundation

protocol EntityResolutionService: Sendable {
    func resolve(
        mentions: [EntityMention],
        context: EntityResolutionContext
    ) async throws -> EntityResolutionResult
}

struct DefaultEntityResolutionService: EntityResolutionService {
    func resolve(
        mentions: [EntityMention],
        context: EntityResolutionContext
    ) async throws -> EntityResolutionResult {
        var links: [EntityResolutionLink] = []
        var buckets: [AmbiguousEntityBucket] = []
        var mergeProposals: [EntityMergeProposal] = []
        var splitProposals: [EntitySplitProposal] = []
        var emittedMergePairs = Set<EntityPairKey>()

        let personProfiles = context.existingProfiles.filter { $0.kind == .person }
        let blockedPairs = blockedEntityPairs(from: context.correctionEvents)
        let roleLabels = roleLabelSet(from: context.selfProfile)

        for mention in mentions where mention.kind == .person {
            let normalizedValue = normalize(mention.value)
            guard !normalizedValue.isEmpty else { continue }

            if isSelfMention(normalizedValue, selfProfile: context.selfProfile) {
                links.append(
                    EntityResolutionLink(
                        mentionID: mention.id,
                        mentionValue: mention.value,
                        resolvedEntityID: context.selfProfile.selfEntityID,
                        kind: .resolvedEntity,
                        confidence: 1,
                        reason: "Mention matches SelfProfile alias."
                    )
                )
                continue
            }

            if roleLabels.contains(normalizedValue) {
                let candidateIDs = Array(personProfiles.prefix(4)).map(\.entityID)
                buckets.append(
                    AmbiguousEntityBucket(
                        label: mention.value,
                        candidateEntityIDs: candidateIDs,
                        reason: "Role label requires user disambiguation."
                    )
                )
                links.append(
                    EntityResolutionLink(
                        mentionID: mention.id,
                        mentionValue: mention.value,
                        resolvedEntityID: nil,
                        kind: .ambiguousEntityBucket,
                        confidence: 0.42,
                        reason: "Role label mapped to ambiguous bucket."
                    )
                )
                if candidateIDs.count > 1 {
                    splitProposals.append(
                        EntitySplitProposal(
                            entityID: candidateIDs[0],
                            confidence: 0.44,
                            reason: "Role label '\(mention.value)' maps to multiple people."
                        )
                    )
                }
                continue
            }

            let scored = personProfiles
                .map { profile in (profile: profile, score: score(profile: profile, mention: normalizedValue)) }
                .filter { $0.score >= 0.55 }
                .sorted { lhs, rhs in
                    if lhs.score != rhs.score { return lhs.score > rhs.score }
                    return lhs.profile.mentionCount > rhs.profile.mentionCount
                }

            guard let top = scored.first else {
                continue
            }

            if let hintedEntityID = mention.hintedEntityID {
                let pair = EntityPairKey(hintedEntityID, top.profile.entityID)
                if blockedPairs.contains(pair) {
                    links.append(
                        EntityResolutionLink(
                            mentionID: mention.id,
                            mentionValue: mention.value,
                            resolvedEntityID: hintedEntityID,
                            kind: .notSameDecision,
                            confidence: 0.95,
                            reason: "Blocked by not-same correction evidence."
                        )
                    )
                    continue
                }
                if hintedEntityID != top.profile.entityID, top.score >= 0.82 {
                    if !emittedMergePairs.contains(pair) {
                        let primaryID = preferredPrimaryID(
                            lhs: hintedEntityID,
                            rhs: top.profile.entityID,
                            profiles: personProfiles
                        )
                        let mergingID = primaryID == hintedEntityID ? top.profile.entityID : hintedEntityID
                        mergeProposals.append(
                            EntityMergeProposal(
                                primaryEntityID: primaryID,
                                mergingEntityID: mergingID,
                                confidence: top.score,
                                reason: "Hinted entity and matched profile likely refer to the same person."
                            )
                        )
                        links.append(
                            EntityResolutionLink(
                                mentionID: mention.id,
                                mentionValue: mention.value,
                                resolvedEntityID: primaryID,
                                kind: .samePersonCandidate,
                                confidence: top.score,
                                reason: "High-confidence same-person candidate."
                            )
                        )
                        emittedMergePairs.insert(pair)
                    }
                    continue
                }
            }

            let blockedConflicts = scored.dropFirst().filter {
                blockedPairs.contains(EntityPairKey(top.profile.entityID, $0.profile.entityID))
            }
            if !blockedConflicts.isEmpty {
                let candidateIDs = ([top] + blockedConflicts).prefix(3).map { $0.profile.entityID }
                buckets.append(
                    AmbiguousEntityBucket(
                        label: mention.value,
                        candidateEntityIDs: candidateIDs,
                        reason: "Blocked not-same correction evidence requires user disambiguation."
                    )
                )
                links.append(
                    EntityResolutionLink(
                        mentionID: mention.id,
                        mentionValue: mention.value,
                        resolvedEntityID: nil,
                        kind: .notSameDecision,
                        confidence: min(0.95, top.score),
                        reason: "Blocked by not-same correction evidence."
                    )
                )
                continue
            }

            if scored.count > 1 && (scored[0].score - scored[1].score) < 0.14 {
                buckets.append(
                    AmbiguousEntityBucket(
                        label: mention.value,
                        candidateEntityIDs: scored.prefix(3).map { $0.profile.entityID },
                        reason: "Top candidates are too close in confidence."
                    )
                )
                links.append(
                    EntityResolutionLink(
                        mentionID: mention.id,
                        mentionValue: mention.value,
                        resolvedEntityID: nil,
                        kind: .ambiguousEntityBucket,
                        confidence: min(0.7, top.score),
                        reason: "Needs user disambiguation."
                    )
                )
                continue
            }

            links.append(
                EntityResolutionLink(
                    mentionID: mention.id,
                    mentionValue: mention.value,
                    resolvedEntityID: top.profile.entityID,
                    kind: .resolvedEntity,
                    confidence: min(0.98, top.score),
                    reason: "Matched person profile by alias/name similarity."
                )
            )
        }

        return EntityResolutionResult(
            links: links,
            ambiguousBuckets: buckets,
            mergeProposals: mergeProposals,
            splitProposals: splitProposals
        )
    }

    private func blockedEntityPairs(from events: [CorrectionEvent]) -> Set<EntityPairKey> {
        let pairs = events
            .filter { $0.kind == .notSameEntity && $0.targetEntityIDs.count >= 2 }
            .map { EntityPairKey($0.targetEntityIDs[0], $0.targetEntityIDs[1]) }
        return Set(pairs)
    }

    private func roleLabelSet(from selfProfile: SelfProfile) -> Set<String> {
        var labels = Set([
            "roommate", "manager", "boss", "mentor", "teammate", "coworker", "partner",
            "family", "friend", "舍友", "室友", "老板", "导师", "同事", "朋友", "家人", "我妈", "我爸", "妈妈", "爸爸",
        ].map(normalize))
        for role in selfProfile.lifeRoles {
            labels.insert(normalize(role.label))
        }
        return labels
    }

    private func isSelfMention(_ normalizedValue: String, selfProfile: SelfProfile) -> Bool {
        let aliases = Set(selfProfile.aliases.map(normalize))
        if aliases.contains(normalizedValue) {
            return true
        }
        guard let displayName = selfProfile.displayName else {
            return false
        }
        return normalize(displayName) == normalizedValue
    }

    private func score(profile: EntityProfile, mention: String) -> Double {
        let nameCandidates = [profile.displayName, profile.canonicalName] + profile.aliases
        var best = 0.0
        for candidate in nameCandidates {
            let normalizedCandidate = normalize(candidate)
            guard !normalizedCandidate.isEmpty else { continue }
            if normalizedCandidate == mention {
                best = max(best, 1)
                continue
            }
            if mention.count >= 3, normalizedCandidate.contains(mention) || mention.contains(normalizedCandidate) {
                best = max(best, 0.86)
                continue
            }
            let overlap = tokenOverlap(lhs: normalizedCandidate, rhs: mention)
            best = max(best, overlap)
        }
        if profile.confirmationState == .userConfirmed {
            best += 0.04
        }
        if profile.mentionCount >= 3 {
            best += 0.03
        }
        return min(best, 1)
    }

    private func preferredPrimaryID(lhs: UUID, rhs: UUID, profiles: [EntityProfile]) -> UUID {
        let lhsScore = profiles.first(where: { $0.entityID == lhs })?.mentionCount ?? 0
        let rhsScore = profiles.first(where: { $0.entityID == rhs })?.mentionCount ?? 0
        return lhsScore >= rhsScore ? lhs : rhs
    }

    private func tokenOverlap(lhs: String, rhs: String) -> Double {
        let lhsTokens = Set(tokens(lhs))
        let rhsTokens = Set(tokens(rhs))
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }
        let intersection = lhsTokens.intersection(rhsTokens).count
        return Double(2 * intersection) / Double(lhsTokens.count + rhsTokens.count)
    }

    private func tokens(_ value: String) -> [String] {
        value
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func normalize(_ value: String) -> String {
        tokens(
            value
            .lowercased()
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        )
        .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct EntityPairKey: Hashable {
    let lhs: UUID
    let rhs: UUID

    init(_ a: UUID, _ b: UUID) {
        if a.uuidString <= b.uuidString {
            self.lhs = a
            self.rhs = b
        } else {
            self.lhs = b
            self.rhs = a
        }
    }
}
