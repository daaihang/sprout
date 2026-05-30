import Foundation
import SwiftData

extension MoryMemoryRepository {
// MARK: - Private: Intelligence Job Helpers

    func enqueueEntityMutationRecomputeJobs(
        affectedRecordIDs: Set<UUID>,
        affectedEntityIDs: Set<UUID>
    ) throws {
        let now = Date.now
        for entityID in affectedEntityIDs {
            try upsert(intelligenceJob: IntelligenceJob(
                kind: .entityEnrichment,
                targetType: .entity,
                targetID: entityID,
                status: .pending,
                priority: 0.76,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ))
            try upsert(intelligenceJob: IntelligenceJob(
                kind: .personProfileRefresh,
                targetType: .entity,
                targetID: entityID,
                status: .pending,
                priority: 0.73,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ))
        }
        for recordID in affectedRecordIDs {
            try upsert(intelligenceJob: IntelligenceJob(
                kind: .chapterCandidate,
                targetType: .record,
                targetID: recordID,
                status: .pending,
                priority: 0.42,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ))
        }
    }

    func purgeEntityProvenance(
        removing recordIDs: Set<UUID>,
        remainingLinkedEntityIDs: Set<UUID>
    ) throws {
        let entityStores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        for store in entityStores {
            var entity = store.domainModel
            let originalProvenance = entity.provenanceRecordIDs
            entity.provenanceRecordIDs.removeAll { recordIDs.contains($0) }

            if entity.provenanceRecordIDs.isEmpty && !remainingLinkedEntityIDs.contains(entity.id) {
                try markEntityDeletedForTombstones(entityID: entity.id, kind: entity.kind, now: Date.now)
                modelContext.delete(store)
            } else if entity.provenanceRecordIDs != originalProvenance {
                entity.updatedAt = Date.now
                store.apply(domainModel: entity)
            }
        }
    }

    // MARK: - Private: Affect Helpers

    func makeAffectSnapshots(
        from draft: MemoryCaptureDraft,
        recordID: UUID,
        createdAt: Date
    ) -> [AffectSnapshot] {
        var snapshots = draft.affectSnapshots.map {
            affectSnapshotMapper.snapshot(recordID: recordID, draft: $0, now: createdAt)
        }
        if snapshots.isEmpty,
           let snapshot = affectSnapshotMapper.snapshot(
                recordID: recordID,
                rawMood: draft.mood,
                userIntensity: nil,
                source: .userFreeform,
                now: createdAt
           ) {
            snapshots.append(snapshot)
        }
        return snapshots
    }

    func replaceUserAffectSnapshot(recordID: UUID, rawMood: String?, now: Date) throws {
        let stores = try modelContext.fetch(
            FetchDescriptor<AffectSnapshotStore>(predicate: #Predicate { $0.recordID == recordID })
        )
        for store in stores {
            let snapshot = store.domainModel
            let onlyUserFreeform = snapshot.sources.allSatisfy { $0 == .userFreeform || $0 == .userSelected }
            if onlyUserFreeform {
                modelContext.delete(store)
            }
        }

        if let snapshot = affectSnapshotMapper.snapshot(
            recordID: recordID,
            rawMood: rawMood,
            userIntensity: nil,
            source: .userFreeform,
            now: now
        ) {
            try upsert(affectSnapshot: snapshot)
        }
    }

    func updateSelfExpressionPattern(from correction: AffectCorrection, snapshot: AffectSnapshot, now: Date) throws {
        let phrase = correction.note?.trimmedOrNil
            ?? snapshot.rawInput?.trimmedOrNil
            ?? snapshot.evidence.reversed().compactMap { $0.summary.trimmedOrNil }.first
            ?? (snapshot.labels + correction.labels).map(\.rawValue).joined(separator: ", ").trimmedOrNil
        guard let phrase else { return }
        var profile = try ensureSelfProfile()
        let interpretation = (correction.toneHints + correction.labels.map { label in
            switch label {
            case .irritated, .stressed, .tense, .overwhelmed:
                return ToneHint.serious
            case .playful, .amused, .mockFrustrated:
                return ToneHint.playful
            default:
                return ToneHint.uncertain
            }
        })
        .map(\.rawValue)
        .joined(separator: ", ")
        let pattern = ExpressionPattern(
            phrase: phrase,
            interpretation: interpretation.isEmpty ? "affect correction" : interpretation,
            confidence: 1
        )
        profile.expressionPatterns.removeAll {
            $0.phrase.caseInsensitiveCompare(pattern.phrase) == .orderedSame
        }
        profile.expressionPatterns.insert(pattern, at: 0)
        profile.expressionPatterns = Array(profile.expressionPatterns.prefix(20))
        profile.updatedAt = now
        try upsertSelfProfile(profile)
    }

    func orderedUniqueAffectLabels(_ labels: [AffectLabel]) -> [AffectLabel] {
        OrderedCollections.unique(labels)
    }

    func orderedUniqueToneHints(_ hints: [ToneHint]) -> [ToneHint] {
        OrderedCollections.unique(hints)
    }


}
