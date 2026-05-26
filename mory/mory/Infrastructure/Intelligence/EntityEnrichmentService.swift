import Foundation

struct EntityEnrichmentService: Sendable {
    func enrichPeople(
        record: RecordShell,
        analysis: RecordAnalysisSnapshot,
        people: [EntityNode],
        existingProfiles: [UUID: EntityProfile]
    ) -> [EntityProfile] {
        let themeLabels = Array(NSOrderedSet(array: analysis.themes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })) as? [String] ?? analysis.themes

        return people.map { person in
            var profile = existingProfiles[person.id] ?? EntityProfile(
                entityID: person.id,
                kind: person.kind,
                displayName: person.displayName,
                canonicalName: person.canonicalName,
                aliases: person.aliases,
                mentionCount: 0,
                firstMentionedAt: record.updatedAt,
                lastMentionedAt: record.updatedAt,
                commonContextLabels: themeLabels,
                sourceRecordIDs: [record.id],
                confirmationState: .inferred,
                confidence: person.confidence,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )

            profile.kind = person.kind
            profile.displayName = person.displayName
            profile.canonicalName = person.canonicalName
            profile.aliases = OrderedCollections.stableUnion(profile.aliases, person.aliases)
            profile.commonContextLabels = OrderedCollections.stableUnion(profile.commonContextLabels, themeLabels)
            profile.sourceRecordIDs = OrderedCollections.stableUnion(profile.sourceRecordIDs, person.provenanceRecordIDs + [record.id])
            profile.mentionCount = max(profile.mentionCount, profile.sourceRecordIDs.count)
            profile.firstMentionedAt = minDate(profile.firstMentionedAt, record.updatedAt)
            profile.lastMentionedAt = maxDate(profile.lastMentionedAt, record.updatedAt)
            profile.confidence = maxConfidence(profile.confidence, person.confidence)
            profile.updatedAt = record.updatedAt
            return profile
        }
    }

    private func minDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return min(lhs, rhs)
        case (nil, let rhs?):
            return rhs
        case (let lhs?, nil):
            return lhs
        case (nil, nil):
            return nil
        }
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case (nil, let rhs?):
            return rhs
        case (let lhs?, nil):
            return lhs
        case (nil, nil):
            return nil
        }
    }

    private func maxConfidence(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case (nil, let rhs?):
            return rhs
        case (let lhs?, nil):
            return lhs
        case (nil, nil):
            return nil
        }
    }
}
