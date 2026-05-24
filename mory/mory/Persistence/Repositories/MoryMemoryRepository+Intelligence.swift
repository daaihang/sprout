import Foundation
import SwiftData

extension MoryMemoryRepository {
    // MARK: - Intelligence: Clarification Questions

    func fetchClarificationQuestions(status: ClarificationQuestionStatus?, limit: Int?) throws -> [ClarificationQuestion] {
        let stores = try modelContext.fetch(
            FetchDescriptor<ClarificationQuestionStore>(
                sortBy: [
                    SortDescriptor(\.priority, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse),
                ]
            )
        )
        let questions = stores
            .map(\.domainModel)
            .filter { question in
                guard let status else { return true }
                return question.status == status
            }
        return applyLimit(limit, to: questions)
    }

    func upsertClarificationQuestion(_ question: ClarificationQuestion) throws {
        try upsert(clarificationQuestion: question)
        try save()
    }

    func answerClarificationQuestion(_ id: UUID, answer: ClarificationAnswer) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<ClarificationQuestionStore>(predicate: #Predicate { $0.id == id })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.status = .answered
        updated.answer = answer
        updated.answeredAt = answer.answeredAt
        updated.dismissedAt = nil
        existing.apply(domainModel: updated)

        if let delta = graphDeltaApplier.buildDelta(for: updated, answer: answer) {
            try upsert(graphDelta: delta)
            let profile = try fetchEntityProfile(entityID: updated.targetID)
            let entityNode = try fetchEntityNode(id: updated.targetID)
            let application = graphDeltaApplier.apply(
                delta: delta,
                profile: profile,
                entityNode: entityNode,
                appliedAt: answer.answeredAt
            )
            if let updatedProfile = application.profile {
                try upsert(entityProfile: updatedProfile)
            }
            if let updatedEntityNode = application.entityNode {
                try upsert(entityNode: updatedEntityNode)
            }
            for operation in delta.operations where operation.kind == .mergeEntity {
                guard operation.targetType == .entity else { continue }
                guard let relatedID = operation.relatedID else { continue }
                _ = try mergePersonEntities(
                    primaryID: operation.targetID,
                    mergingIDs: [relatedID],
                    displayName: nil
                )
            }
            if let existingDelta = try modelContext.fetch(
                FetchDescriptor<GraphDeltaStore>(predicate: #Predicate { $0.id == delta.id })
            ).first {
                var appliedDelta = existingDelta.domainModel
                appliedDelta.appliedAt = answer.answeredAt
                existingDelta.apply(domainModel: appliedDelta)
            }
        }

        try save()
    }

    func dismissClarificationQuestion(_ id: UUID) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<ClarificationQuestionStore>(predicate: #Predicate { $0.id == id })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.status = .dismissed
        updated.dismissedAt = Date.now
        existing.apply(domainModel: updated)
        try save()
    }

    // MARK: - Intelligence: Jobs & Graph Deltas

    func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob] {
        let stores = try modelContext.fetch(
            FetchDescriptor<IntelligenceJobStore>(
                sortBy: [
                    SortDescriptor(\.priority, order: .reverse),
                    SortDescriptor(\.scheduledAt, order: .forward),
                ]
            )
        )
        let jobs = stores
            .map(\.domainModel)
            .filter { job in
                guard let status else { return true }
                return job.status == status
            }
        return applyLimit(limit, to: jobs)
    }

    func upsertIntelligenceJob(_ job: IntelligenceJob) throws {
        try upsert(intelligenceJob: job)
        try save()
    }

    func fetchGraphDeltas(applied: Bool?, limit: Int?) throws -> [GraphDelta] {
        let stores = try modelContext.fetch(
            FetchDescriptor<GraphDeltaStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
        let deltas = stores
            .map(\.domainModel)
            .filter { delta in
                guard let applied else { return true }
                return (delta.appliedAt != nil) == applied
            }
        return applyLimit(limit, to: deltas)
    }

    func upsertGraphDelta(_ delta: GraphDelta) throws {
        try upsert(graphDelta: delta)
        try save()
    }

    func markGraphDeltaApplied(_ id: UUID, appliedAt: Date = .now) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<GraphDeltaStore>(predicate: #Predicate { $0.id == id })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.appliedAt = appliedAt
        existing.apply(domainModel: updated)
        try save()
    }

    func rejectGraphDelta(_ id: UUID, note: String? = nil) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<GraphDeltaStore>(predicate: #Predicate { $0.id == id })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let delta = existing.domainModel
        let targetEntityIDs = delta.operations.flatMap { operation -> [UUID] in
            [operation.targetID, operation.relatedID].compactMap { $0 }
        }
        let sourceRecordIDs = delta.operations.compactMap { $0.metadata["recordID"].flatMap(UUID.init(uuidString:)) }
        try upsert(correctionEvent: CorrectionEvent(
            kind: .graphDeltaRejected,
            actor: .user,
            targetEntityIDs: Array(Set(targetEntityIDs)),
            sourceRecordIDs: Array(Set(sourceRecordIDs)),
            note: note?.trimmedOrNil ?? "Rejected GraphDelta proposal.",
            metadata: [
                "graphDeltaID": id.uuidString,
                "source": delta.source.rawValue,
                "operations": delta.operations.map(\.kind.rawValue).joined(separator: ",")
            ],
            isReversible: true
        ))
        try save()
    }

    func applyGraphDelta(_ id: UUID) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<GraphDeltaStore>(predicate: #Predicate { $0.id == id })
        ).first else { throw CocoaError(.fileNoSuchFile) }
        let delta = existing.domainModel
        guard delta.appliedAt == nil else { return } // idempotent

        let primaryID = delta.operations.first?.targetID ?? UUID()
        let profile = try fetchEntityProfile(entityID: primaryID)
        let entityNode = try fetchEntityNode(id: primaryID)

        let result = graphDeltaApplier.apply(
            delta: delta,
            profile: profile,
            entityNode: entityNode,
            appliedAt: .now
        )
        if let updatedProfile = result.profile {
            try upsert(entityProfile: updatedProfile)
        }
        if let updatedEntity = result.entityNode {
            try upsert(entityNode: updatedEntity)
        }
        for op in delta.operations where op.kind == .mergeEntity {
            guard op.targetType == .entity, let relatedID = op.relatedID else { continue }
            _ = try mergePersonEntities(
                primaryID: op.targetID,
                mergingIDs: [relatedID],
                displayName: nil
            )
        }
        try markGraphDeltaApplied(id)
    }

}
